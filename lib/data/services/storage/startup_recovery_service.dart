import 'dart:io';
import 'dart:developer' as developer;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show Database;

import '../../../domain/models/recording.dart';
import '../../../domain/models/workflow_states.dart';
import '../audio/recording_checkpoint_store.dart';
import 'app_database.dart';
import 'app_file_layout.dart';
import 'durable_file_committer.dart';

typedef StartupRecoveryErrorReporter = void Function(
  String step,
  Object error,
  StackTrace stackTrace,
);

final class RecoveryReport {
  const RecoveryReport({
    required this.recoveredRecordings,
    required this.failedRecordings,
    required this.resetExpiredTasks,
    required this.removedModelTempDirectories,
    required this.reconciledModelRollbackDirectories,
    required this.removedShareTempDirectories,
    required this.removedStagedMeetingDirectories,
    required this.activatedSnapshots,
  });

  final int recoveredRecordings;
  final int failedRecordings;
  final int resetExpiredTasks;
  final int removedModelTempDirectories;
  final int reconciledModelRollbackDirectories;
  final int removedShareTempDirectories;
  final int removedStagedMeetingDirectories;
  final int activatedSnapshots;

  int get totalChanges =>
      recoveredRecordings +
      failedRecordings +
      resetExpiredTasks +
      removedModelTempDirectories +
      reconciledModelRollbackDirectories +
      removedShareTempDirectories +
      removedStagedMeetingDirectories +
      activatedSnapshots;
}

final class StartupRecoveryService {
  StartupRecoveryService({
    required this.database,
    required this.layout,
    this.fileCommitter = const DurableFileCommitter(),
    RecordingCheckpointStore? recordingCheckpoints,
    StartupRecoveryErrorReporter? reportError,
  }) : recordingCheckpoints =
           recordingCheckpoints ?? JsonRecordingCheckpointStore(layout),
       reportError = reportError ?? _logRecoveryError;

  final AppDatabase database;
  final AppFileLayout layout;
  final DurableFileCommitter fileCommitter;
  final RecordingCheckpointStore recordingCheckpoints;
  final StartupRecoveryErrorReporter reportError;

  Future<RecoveryReport> recover({required DateTime now}) async {
    final recoveredRecordings = await _attempt(
      'recoverRecordings',
      () => _recoverRecordings(now),
      (successes: 0, failures: 0),
    );
    final resetExpiredTasks = await _attempt(
      'resetExpiredTasks',
      () => _resetExpiredTasks(now),
      0,
    );
    final removedModelTempDirectories = await _attempt(
      'removeIncompleteModelDirectories',
      _removeIncompleteModelDirectories,
      0,
    );
    final reconciledModelRollbackDirectories = await _attempt(
      'reconcileModelRollbackDirectories',
      _reconcileModelRollbackDirectories,
      0,
    );
    final removedShareTempDirectories = await _attempt(
      'removeShareTempDirectories',
      _removeShareTempDirectories,
      0,
    );
    final removedStagedMeetingDirectories = await _attempt(
      'removeStagedMeetingDirectories',
      _removeStagedMeetingDirectories,
      0,
    );
    final activatedSnapshots = await _attempt(
      'activateCompletedSnapshots',
      _activateCompletedSnapshots,
      0,
    );

    return RecoveryReport(
      recoveredRecordings: recoveredRecordings.successes,
      failedRecordings: recoveredRecordings.failures,
      resetExpiredTasks: resetExpiredTasks,
      removedModelTempDirectories: removedModelTempDirectories,
      reconciledModelRollbackDirectories: reconciledModelRollbackDirectories,
      removedShareTempDirectories: removedShareTempDirectories,
      removedStagedMeetingDirectories: removedStagedMeetingDirectories,
      activatedSnapshots: activatedSnapshots,
    );
  }

  Future<({int successes, int failures})> _recoverRecordings(
    DateTime now,
  ) async {
    final db = await database.open();
    final rows = await db.query(
      'meetings',
      columns: ['id'],
      where: 'status = ?',
      whereArgs: [MeetingState.recording.name],
    );
    var successes = 0;
    var failures = 0;

    for (final row in rows) {
      final meetingId = row['id']! as String;
      try {
        await _alignRecoverablePcm(meetingId);
        await fileCommitter.commit(
          tempPath: layout.meetingAudioTempPath(meetingId),
          finalPath: layout.meetingAudioPath(meetingId),
          persistReference: (finalPath) async {
            final persistedBytes = await File(finalPath).length();
            await recordingCheckpoints.save(
              RecordingCheckpoint(
                meetingId: meetingId,
                state: RecordingCheckpointState.finalized,
                persistedBytes: persistedBytes,
                updatedAt: now.toUtc(),
              ),
            );
            await db.transaction((txn) async {
              final updated = await txn.update(
                'meetings',
                {
                  'audio_path': finalPath,
                  'audio_duration_ms': recordingDurationForBytes(persistedBytes)
                      .inMilliseconds,
                  'status': MeetingState.processing.name,
                  'last_error_code': null,
                },
                where: 'id = ? AND status = ?',
                whereArgs: [meetingId, MeetingState.recording.name],
              );
              if (updated != 1) {
                throw StateError('会议状态已变化，拒绝写入恢复音频引用：$meetingId');
              }
            });
          },
        );
        successes++;
      } on DurableFileCommitException {
        await _attempt(
          'markRecordingRecoveryFailed:$meetingId',
          () => _markRecordingRecoveryFailed(
            db,
            meetingId,
            'recovery.audio_missing_or_empty',
          ),
          null,
        );
        failures++;
      } on Object {
        await _attempt(
          'markRecordingRecoveryFailed:$meetingId',
          () => _markRecordingRecoveryFailed(
            db,
            meetingId,
            'recovery.unexpected',
          ),
          null,
        );
        failures++;
      }
    }
    return (successes: successes, failures: failures);
  }

  Future<void> _markRecordingRecoveryFailed(
    Database db,
    String meetingId,
    String errorCode,
  ) async {
    await db.update(
      'meetings',
      {'status': MeetingState.failed.name, 'last_error_code': errorCode},
      where: 'id = ? AND status = ?',
      whereArgs: [meetingId, MeetingState.recording.name],
    );
  }

  Future<void> _alignRecoverablePcm(String meetingId) async {
    final finalFile = File(layout.meetingAudioPath(meetingId));
    final tempFile = File(layout.meetingAudioTempPath(meetingId));
    final source = await finalFile.exists() ? finalFile : tempFile;
    if (!await source.exists()) {
      return;
    }
    final length = await source.length();
    final alignedLength = length - (length % recordingBytesPerSample);
    if (alignedLength <= 0) {
      throw DurableFileCommitException('恢复音频没有完整 PCM16 样本：${source.path}');
    }
    if (alignedLength == length) {
      return;
    }
    final handle = await source.open(mode: FileMode.append);
    try {
      await handle.truncate(alignedLength);
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  Future<int> _resetExpiredTasks(DateTime now) async {
    final db = await database.open();
    return db.update(
      'processing_tasks',
      {
        'state': ProcessingState.queued.name,
        'updated_at': now.millisecondsSinceEpoch,
        'lease_expires_at': null,
        'last_error_code': 'recovery.lease_expired',
      },
      where:
          'state = ? AND lease_expires_at IS NOT NULL '
          'AND lease_expires_at <= ?',
      whereArgs: [ProcessingState.running.name, now.millisecondsSinceEpoch],
    );
  }

  Future<int> _removeIncompleteModelDirectories() async {
    final tempRoot = Directory(layout.modelTempRoot);
    if (!await tempRoot.exists()) {
      return 0;
    }
    final normalizedRoot = p.normalize(p.absolute(tempRoot.path));
    var removed = 0;

    await for (final modelEntity in tempRoot.list(followLinks: false)) {
      if (modelEntity is! Directory) {
        continue;
      }
      await for (final versionEntity in modelEntity.list(followLinks: false)) {
        if (versionEntity is! Directory) {
          continue;
        }
        final target = p.normalize(p.absolute(versionEntity.path));
        if (!p.isWithin(normalizedRoot, target)) {
          throw StateError('拒绝清理模型临时根目录之外的路径：$target');
        }
        await versionEntity.delete(recursive: true);
        removed++;
      }
      if (await modelEntity.list(followLinks: false).isEmpty) {
        await modelEntity.delete();
      }
    }
    return removed;
  }

  Future<int> _reconcileModelRollbackDirectories() async {
    final rollbackRoot = Directory(layout.modelRollbackRoot);
    if (!await rollbackRoot.exists()) {
      return 0;
    }
    var reconciled = 0;
    await for (final model in rollbackRoot.list(followLinks: false)) {
      if (model is! Directory) {
        continue;
      }
      await for (final backup in model.list(followLinks: false)) {
        if (backup is! Directory) {
          continue;
        }
        try {
          final finalDirectory = Directory(
            layout.modelVersionDirectory(
              p.basename(model.path),
              p.basename(backup.path),
            ),
          );
          if (await finalDirectory.exists()) {
            await backup.delete(recursive: true);
          } else {
            await finalDirectory.parent.create(recursive: true);
            await backup.rename(finalDirectory.path);
          }
          reconciled++;
        } on Object catch (error, stackTrace) {
          reportError(
            'reconcileModelRollback:${backup.path}',
            error,
            stackTrace,
          );
        }
      }
      if (await model.list(followLinks: false).isEmpty) {
        await model.delete();
      }
    }
    if (await rollbackRoot.list(followLinks: false).isEmpty) {
      await rollbackRoot.delete();
    }
    return reconciled;
  }

  Future<int> _removeShareTempDirectories() async {
    final meetingsRoot = Directory(layout.meetingsRoot);
    if (!await meetingsRoot.exists()) {
      return 0;
    }
    final normalizedRoot = p.normalize(p.absolute(meetingsRoot.path));
    var removed = 0;
    await for (final meetingEntity in meetingsRoot.list(followLinks: false)) {
      if (meetingEntity is! Directory) {
        continue;
      }
      final target = p.normalize(
        p.absolute(p.join(meetingEntity.path, '.share')),
      );
      if (!p.isWithin(normalizedRoot, target)) {
        throw StateError('拒绝清理会议根目录之外的分享临时路径：$target');
      }
      final type = await FileSystemEntity.type(target, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        continue;
      }
      switch (type) {
        case FileSystemEntityType.directory:
          await Directory(target).delete(recursive: true);
        case FileSystemEntityType.link:
          await Link(target).delete();
        case FileSystemEntityType.file:
          await File(target).delete();
        case FileSystemEntityType.notFound:
          continue;
        default:
          throw StateError('无法识别分享临时路径类型：$target');
      }
      removed++;
    }
    return removed;
  }

  Future<int> _removeStagedMeetingDirectories() async {
    final meetingsRoot = Directory(layout.meetingsRoot);
    if (!await meetingsRoot.exists()) {
      return 0;
    }
    final db = await database.open();
    final normalizedRoot = p.normalize(p.absolute(meetingsRoot.path));
    var removed = 0;
    await for (final entity in meetingsRoot.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final match = RegExp(r'^\.deleting-(.+)-(\d+)$')
          .firstMatch(p.basename(entity.path));
      if (match == null) {
        continue;
      }
      final target = p.normalize(p.absolute(entity.path));
      if (!p.isWithin(normalizedRoot, target)) {
        continue;
      }
      try {
        final meetingId = match.group(1)!;
        final meetingExists = (await db.rawQuery(
          'SELECT 1 FROM meetings WHERE id = ? LIMIT 1',
          [meetingId],
        )).isNotEmpty;
        if (meetingExists) {
          final original = Directory(layout.meetingDirectory(meetingId));
          if (!await original.exists()) {
            await entity.rename(original.path);
          } else {
            reportError(
              'reconcileStagedMeeting:$meetingId',
              StateError('原目录与暂存删除目录同时存在：${entity.path}'),
              StackTrace.current,
            );
          }
          continue;
        }
        await entity.delete(recursive: true);
        removed++;
      } on Object catch (error, stackTrace) {
        reportError('removeStagedMeeting:${entity.path}', error, stackTrace);
        // 单个残留清理失败不阻断其他会议恢复或应用启动。
      }
    }
    return removed;
  }

  Future<int> _activateCompletedSnapshots() async {
    final db = await database.open();
    final rows = await db.rawQuery(
      '''
      SELECT s.id, s.meeting_id
      FROM transcript_snapshots s
      JOIN meetings m ON m.id = s.meeting_id
      WHERE s.kind = ?
        AND s.status = ?
        AND s.id = (
          SELECT latest.id
          FROM transcript_snapshots latest
          WHERE latest.meeting_id = s.meeting_id
            AND latest.kind = ?
            AND latest.status = ?
          ORDER BY latest.created_at DESC, latest.id DESC
          LIMIT 1
        )
        AND m.active_transcript_snapshot_id IS NOT s.id
    ''',
      ['finalTranscript', 'complete', 'finalTranscript', 'complete'],
    );
    var activated = 0;
    for (final row in rows) {
      activated += await db.update(
        'meetings',
        {
          'active_transcript_snapshot_id': row['id'],
          'status': MeetingState.completed.name,
          'last_error_code': null,
        },
        where: 'id = ? AND active_transcript_snapshot_id IS NOT ?',
        whereArgs: [row['meeting_id'], row['id']],
      );
    }
    return activated;
  }

  Future<T> _attempt<T>(
    String step,
    Future<T> Function() operation,
    T fallback,
  ) async {
    try {
      return await operation();
    } on Object catch (error, stackTrace) {
      reportError(step, error, stackTrace);
      return fallback;
    }
  }
}

void _logRecoveryError(String step, Object error, StackTrace stackTrace) {
  developer.log(
    '启动恢复步骤失败：$step',
    name: 'meettrace.recovery',
    error: error,
    stackTrace: stackTrace,
  );
}
