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

  test('启动恢复器处理四类残留且重复运行结果不变', () async {
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
    await File(
      '${modelTemp.path}${Platform.pathSeparator}partial.onnx',
    ).writeAsBytes([1]);

    final first = await recovery.recover(now: now);
    final second = await recovery.recover(now: now);

    expect(first.recoveredRecordings, 1);
    expect(first.resetExpiredTasks, 1);
    expect(first.removedModelTempDirectories, 1);
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
      (await JsonRecordingCheckpointStore(
        layout,
      ).load(recordingMeeting.id))?.state,
      RecordingCheckpointState.finalized,
    );
    expect((await tasks.getById('task-1'))!.state, ProcessingState.queued);
    expect(await modelTemp.exists(), false);
  });
}
