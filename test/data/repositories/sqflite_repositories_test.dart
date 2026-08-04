import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_meeting_repository.dart';
import 'package:meettrace/data/repositories/sqflite_model_installation_repository.dart';
import 'package:meettrace/data/repositories/sqflite_processing_task_repository.dart';
import 'package:meettrace/data/repositories/sqflite_transcript_repository.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/domain_exception.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/processing_task.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SqfliteMeetingRepository meetings;
  late SqfliteTranscriptRepository transcripts;
  late SqfliteModelInstallationRepository modelInstallations;
  late SqfliteProcessingTaskRepository tasks;

  setUp(() async {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await database.open();
    meetings = SqfliteMeetingRepository(database);
    transcripts = SqfliteTranscriptRepository(database);
    modelInstallations = SqfliteModelInstallationRepository(database);
    tasks = SqfliteProcessingTaskRepository(database);
  });

  tearDown(() => database.close());

  test('失败的新最终快照不会覆盖旧活动快照', () async {
    await meetings.save(_meeting('meeting-1', status: MeetingState.processing));
    final oldSnapshot = _snapshot(
      id: 'old',
      meetingId: 'meeting-1',
      status: TranscriptSnapshotStatus.complete,
    );
    await transcripts.saveFinalAndActivate(
      snapshot: oldSnapshot,
      expectedActiveSnapshotId: null,
    );
    final failedSnapshot = _snapshot(
      id: 'failed',
      meetingId: 'meeting-1',
      status: TranscriptSnapshotStatus.failed,
    );

    await expectLater(
      transcripts.saveFinalAndActivate(
        snapshot: failedSnapshot,
        expectedActiveSnapshotId: 'old',
      ),
      throwsA(isA<DomainInvariantViolation>()),
    );

    expect(
      (await meetings.getById('meeting-1'))!.activeTranscriptSnapshotId,
      'old',
    );
    expect(await transcripts.getById('failed'), isNull);
  });

  test('成功激活最终快照时原子完成会议', () async {
    await meetings.save(_meeting('meeting-1', status: MeetingState.processing));
    final snapshot = _snapshot(
      id: 'snapshot-1',
      meetingId: 'meeting-1',
      status: TranscriptSnapshotStatus.complete,
    );

    await transcripts.saveFinalAndActivate(
      snapshot: snapshot,
      expectedActiveSnapshotId: null,
    );

    final completed = (await meetings.getById('meeting-1'))!;
    expect(completed.status, MeetingState.completed);
    expect(completed.activeTranscriptSnapshotId, snapshot.id);
    expect(completed.lastErrorCode, isNull);
  });

  test('删除会议只级联删除目标会议派生数据', () async {
    await meetings.save(_meeting('meeting-1'));
    await meetings.save(_meeting('meeting-2'));
    final snapshot = _snapshot(
      id: 'snapshot-1',
      meetingId: 'meeting-1',
      status: TranscriptSnapshotStatus.complete,
    );
    await transcripts.saveFinalAndActivate(
      snapshot: snapshot,
      expectedActiveSnapshotId: null,
    );
    await tasks.save(
      ProcessingTask(
        id: 'task-1',
        kind: ProcessingTaskKind.finalTranscription,
        meetingId: 'meeting-1',
        state: ProcessingState.queued,
        createdAt: DateTime.utc(2026, 7, 24),
        updatedAt: DateTime.utc(2026, 7, 24),
      ),
    );

    await meetings.delete('meeting-1');

    expect(await meetings.getById('meeting-1'), isNull);
    expect(await meetings.getById('meeting-2'), isNotNull);
    expect(await transcripts.listByMeeting('meeting-1'), isEmpty);
    expect(await tasks.listByMeeting('meeting-1'), isEmpty);
  });

  test('转录片段和模型安装可以无损往返', () async {
    await meetings.save(_meeting('meeting-1'));
    final snapshot = _snapshot(
      id: 'snapshot-1',
      meetingId: 'meeting-1',
      status: TranscriptSnapshotStatus.complete,
      withSegment: true,
    );
    await transcripts.saveFinalAndActivate(
      snapshot: snapshot,
      expectedActiveSnapshotId: null,
    );
    final installation = ModelInstallation(
      modelId: 'qwen',
      version: '1',
      installationType: AsrInstallationType.downloadable,
      state: ModelInstallationState.installed,
      installedPath: '/models/qwen/1',
      verifiedAt: DateTime.utc(2026, 7, 24),
      bytes: 100,
    );
    await modelInstallations.save(installation);

    final restoredSnapshot = await transcripts.getById(snapshot.id);
    final restoredInstallation = await modelInstallations.get(
      modelId: 'qwen',
      version: '1',
    );

    expect(restoredSnapshot!.segments.single.text, '测试');
    expect(restoredInstallation!.installedPath, '/models/qwen/1');
  });
}

Meeting _meeting(String id, {MeetingState status = MeetingState.created}) {
  return Meeting(
    id: id,
    title: '2026-07-24 09:00 会议',
    createdAt: DateTime.utc(2026, 7, 24),
    status: status,
    audioDurationMs: 0,
    recordingModelId: 'paraformer',
    recordingModelVersion: '1',
  );
}

TranscriptSnapshot _snapshot({
  required String id,
  required String meetingId,
  required TranscriptSnapshotStatus status,
  bool withSegment = false,
}) {
  return TranscriptSnapshot(
    id: id,
    meetingId: meetingId,
    kind: TranscriptSnapshotKind.finalTranscript,
    actualModelId: 'paraformer',
    actualModelVersion: '1',
    createdAt: DateTime.utc(2026, 7, 24),
    status: status,
    segments: withSegment
        ? [
            TranscriptSegment(
              id: 'segment-1',
              snapshotId: id,
              startMs: 0,
              endMs: 1000,
              text: '测试',
              confidence: 0.8,
              modelId: 'paraformer',
              modelVersion: '1',
            ),
          ]
        : const [],
  );
}
