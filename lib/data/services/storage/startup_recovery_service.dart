import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/models/workflow_states.dart';
import 'app_database.dart';
import 'app_file_layout.dart';
import 'durable_file_committer.dart';

final class RecoveryReport {
  const RecoveryReport({
    required this.recoveredRecordings,
    required this.failedRecordings,
    required this.resetExpiredTasks,
    required this.removedModelTempDirectories,
    required this.activatedSnapshots,
  });

  final int recoveredRecordings;
  final int failedRecordings;
  final int resetExpiredTasks;
  final int removedModelTempDirectories;
  final int activatedSnapshots;

  int get totalChanges =>
      recoveredRecordings +
      failedRecordings +
      resetExpiredTasks +
      removedModelTempDirectories +
      activatedSnapshots;
}

final class StartupRecoveryService {
  StartupRecoveryService({
    required this.database,
    required this.layout,
    this.fileCommitter = const DurableFileCommitter(),
  });

  final AppDatabase database;
  final AppFileLayout layout;
  final DurableFileCommitter fileCommitter;

  Future<RecoveryReport> recover({required DateTime now}) async {
    final recoveredRecordings = await _recoverRecordings();
    final resetExpiredTasks = await _resetExpiredTasks(now);
    final removedModelTempDirectories =
        await _removeIncompleteModelDirectories();
    final activatedSnapshots = await _activateCompletedSnapshots();

    return RecoveryReport(
      recoveredRecordings: recoveredRecordings.successes,
      failedRecordings: recoveredRecordings.failures,
      resetExpiredTasks: resetExpiredTasks,
      removedModelTempDirectories: removedModelTempDirectories,
      activatedSnapshots: activatedSnapshots,
    );
  }

  Future<({int successes, int failures})> _recoverRecordings() async {
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
        await fileCommitter.commit(
          tempPath: layout.meetingAudioTempPath(meetingId),
          finalPath: layout.meetingAudioPath(meetingId),
          persistReference: (finalPath) async {
            await db.transaction((txn) async {
              final updated = await txn.update(
                'meetings',
                {
                  'audio_path': finalPath,
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
        await db.update(
          'meetings',
          {
            'status': MeetingState.failed.name,
            'last_error_code': 'recovery.audio_missing_or_empty',
          },
          where: 'id = ? AND status = ?',
          whereArgs: [meetingId, MeetingState.recording.name],
        );
        failures++;
      }
    }
    return (successes: successes, failures: failures);
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
        {'active_transcript_snapshot_id': row['id'], 'active_summary_id': null},
        where: 'id = ? AND active_transcript_snapshot_id IS NOT ?',
        whereArgs: [row['meeting_id'], row['id']],
      );
    }
    return activated;
  }
}
