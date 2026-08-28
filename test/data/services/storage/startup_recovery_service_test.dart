import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_meeting_repository.dart';
import 'package:meettrace/data/repositories/sqflite_processing_task_repository.dart';
import 'package:meettrace/data/repositories/sqflite_transcript_repository.dart';
import 'package:meettrace/data/services/audio/recording_checkpoint_store.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/storage/startup_recovery_service.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/processing_task.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory root;
  late AppDatabase database;
  late AppFileLayout layout;
  late SqfliteMeetingRepository meetings;
  late SqfliteTranscriptRepository transcripts;
  late SqfliteProcessingTaskRepository tasks;
  late StartupRecoveryService recovery;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-recovery-');
    layout = AppFileLayout(rootPath: root.path);
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: layout.databasePath,
    );
    await database.open();
    meetings = SqfliteMeetingRepository(database);
    transcripts = SqfliteTranscriptRepository(database);
    tasks = SqfliteProcessingTaskRepository(database);
    recovery = StartupRecoveryService(database: database, layout: layout);
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('启动恢复器处理五类残留且重复运行结果不变', () async {
    final now = DateTime.utc(2026, 7, 24, 8);
    final recordingMeeting = Meeting(
      id: 'meeting-1',
      title: '会议',
      createdAt: now.subtract(const Duration(hours: 1)),
      status: MeetingState.created,
      audioDurationMs: 0,
      recordingModelId: 'paraformer',
      recordingModelVersion: '1',
    ).startRecording(startedAt: now.subtract(const Duration(minutes: 50)));
    await meetings.save(recordingMeeting);
    final tempAudio = File(layout.meetingAudioTempPath(recordingMeeting.id));
    await tempAudio.parent.create(recursive: true);
    await tempAudio.writeAsBytes(List<int>.filled(32001, 1), flush: true);
    await JsonRecordingCheckpointStore(layout).save(
      RecordingCheckpoint(
        meetingId: recordingMeeting.id,
        state: RecordingCheckpointState.recording,
        persistedBytes: 32000,
        updatedAt: now.subtract(const Duration(minutes: 1)),
      ),
    );

    await tasks.save(
      ProcessingTask(
        id: 'task-1',
        kind: ProcessingTaskKind.finalTranscription,
        meetingId: recordingMeeting.id,
        state: ProcessingState.running,
        createdAt: now.subtract(const Duration(minutes: 30)),
        updatedAt: now.subtract(const Duration(minutes: 20)),
        leaseExpiresAt: now.subtract(const Duration(minutes: 10)),
      ),
    );

    final snapshot = TranscriptSnapshot(
      id: 'snapshot-1',
      meetingId: recordingMeeting.id,
      kind: TranscriptSnapshotKind.finalTranscript,
      actualModelId: 'paraformer',
      actualModelVersion: '1',
      createdAt: now.subtract(const Duration(minutes: 5)),
      status: TranscriptSnapshotStatus.complete,
      segments: const [],
    );
    await transcripts.save(snapshot);

    final modelTemp = Directory(layout.modelTempDirectory('qwen', '1'));
    await modelTemp.create(recursive: true);
    await File('${modelTemp.path}${Platform.pathSeparator}partial.onnx')
        .writeAsBytes([1]);
    final shareTemp = Directory(
      layout.meetingShareTempDirectory(recordingMeeting.id),
    );
    await shareTemp.create(recursive: true);
    await File('${shareTemp.path}${Platform.pathSeparator}stale.wav')
        .writeAsBytes([1]);
    final stagedDeletion = Directory(
      '${layout.meetingsRoot}${Platform.pathSeparator}'
      '.deleting-old-meeting-1',
    );
    await stagedDeletion.create(recursive: true);
    await File('${stagedDeletion.path}${Platform.pathSeparator}fact.pcm')
        .writeAsBytes([1]);

    final first = await recovery.recover(now: now);
    final second = await recovery.recover(now: now);

    expect(first.recoveredRecordings, 1);
    expect(first.resetExpiredTasks, 1);
    expect(first.removedModelTempDirectories, 1);
    expect(first.removedShareTempDirectories, 1);
    expect(first.removedStagedMeetingDirectories, 1);
    expect(first.activatedSnapshots, 1);
    expect(second.totalChanges, 0);

    final recoveredMeeting = (await meetings.getById(recordingMeeting.id))!;
    expect(recoveredMeeting.status, MeetingState.completed);
    expect(
      recoveredMeeting.audioPath,
      layout.meetingAudioPath(recordingMeeting.id),
    );
    expect(recoveredMeeting.activeTranscriptSnapshotId, snapshot.id);
    expect(await File(recoveredMeeting.audioPath!).exists(), true);
    expect(await File(recoveredMeeting.audioPath!).length(), 32000);
    expect(recoveredMeeting.audioDurationMs, 1000);
    expect(
      (await JsonRecordingCheckpointStore(layout).load(recordingMeeting.id))
          ?.state,
      RecordingCheckpointState.finalized,
    );
    expect((await tasks.getById('task-1'))!.state, ProcessingState.queued);
    expect(await modelTemp.exists(), false);
    expect(await shareTemp.exists(), false);
    expect(await stagedDeletion.exists(), false);
  });

  test('单条录音恢复异常不会阻断后续会议恢复或应用启动', () async {
    final now = DateTime.utc(2026, 7, 24, 9);
    for (final id in ['meeting-bad', 'meeting-good']) {
      await meetings.save(
        Meeting(
          id: id,
          title: id,
          createdAt: now,
          status: MeetingState.created,
          audioDurationMs: 0,
          recordingModelId: 'paraformer',
          recordingModelVersion: '1',
        ).startRecording(startedAt: now),
      );
      final audio = File(layout.meetingAudioTempPath(id));
      await audio.parent.create(recursive: true);
      await audio.writeAsBytes(List<int>.filled(32000, 1));
    }
    recovery = StartupRecoveryService(
      database: database,
      layout: layout,
      recordingCheckpoints: _SelectiveFailingCheckpointStore(layout),
    );

    final report = await recovery.recover(now: now);

    expect(report.failedRecordings, 1);
    expect(report.recoveredRecordings, 1);
    expect(
      (await meetings.getById('meeting-bad'))?.status,
      MeetingState.failed,
    );
    expect(
      (await meetings.getById('meeting-good'))?.status,
      MeetingState.processing,
    );
  });

  test('标记缺失录音失败时仍继续恢复后续会议', () async {
    final now = DateTime.utc(2026, 7, 24, 10);
    for (final id in ['meeting-bad', 'meeting-good']) {
      await meetings.save(
        Meeting(
          id: id,
          title: id,
          createdAt: now,
          status: MeetingState.created,
          audioDurationMs: 0,
          recordingModelId: 'paraformer',
          recordingModelVersion: '1',
        ).startRecording(startedAt: now),
      );
    }
    final goodAudio = File(layout.meetingAudioTempPath('meeting-good'));
    await goodAudio.parent.create(recursive: true);
    await goodAudio.writeAsBytes(List<int>.filled(32000, 1));
    final db = await database.open();
    await db.execute('''
      CREATE TRIGGER reject_bad_recovery_update
      BEFORE UPDATE ON meetings
      WHEN OLD.id = 'meeting-bad'
      BEGIN
        SELECT RAISE(FAIL, 'forced update failure');
      END
    ''');

    final report = await recovery.recover(now: now);

    expect(report.failedRecordings, 1);
    expect(report.recoveredRecordings, 1);
    expect(
      (await meetings.getById('meeting-bad'))?.status,
      MeetingState.recording,
    );
    expect(
      (await meetings.getById('meeting-good'))?.status,
      MeetingState.processing,
    );
  });

  test('数据库仍有会议时恢复已暂存的删除目录', () async {
    final now = DateTime.utc(2026, 7, 24, 11);
    const meetingId = 'meeting-survives-crash';
    await meetings.save(
      Meeting(
        id: meetingId,
        title: meetingId,
        createdAt: now,
        status: MeetingState.created,
        audioDurationMs: 0,
        recordingModelId: 'paraformer',
        recordingModelVersion: '1',
      ),
    );
    final original = Directory(layout.meetingDirectory(meetingId));
    await original.create(recursive: true);
    await File('${original.path}${Platform.pathSeparator}fact.pcm')
        .writeAsBytes([1]);
    final staged = await original.rename(
      '${layout.meetingsRoot}${Platform.pathSeparator}'
      '.deleting-$meetingId-${now.microsecondsSinceEpoch}',
    );

    final report = await recovery.recover(now: now);

    expect(report.removedStagedMeetingDirectories, 0);
    expect(await staged.exists(), isFalse);
    expect(
      await File('${original.path}${Platform.pathSeparator}fact.pcm').exists(),
      isTrue,
    );
    expect(await meetings.getById(meetingId), isNotNull);
  });
}

final class _SelectiveFailingCheckpointStore
    implements RecordingCheckpointStore {
  _SelectiveFailingCheckpointStore(this.layout);

  final AppFileLayout layout;

  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<RecordingCheckpoint?> load(String meetingId) async => null;

  @override
  Future<void> save(RecordingCheckpoint checkpoint) {
    if (checkpoint.meetingId == 'meeting-bad') {
      throw FileSystemException('checkpoint failed');
    }
    return JsonRecordingCheckpointStore(layout).save(checkpoint);
  }
}
