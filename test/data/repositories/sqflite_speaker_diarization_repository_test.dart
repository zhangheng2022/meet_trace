import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_diarization_preference_repository.dart';
import 'package:meettrace/data/repositories/sqflite_meeting_repository.dart';
import 'package:meettrace/data/repositories/sqflite_transcript_repository.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/domain/models/domain_exception.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SqfliteMeetingRepository meetings;
  late SqfliteTranscriptRepository transcripts;
  late SqfliteDiarizationPreferenceRepository preference;

  setUp(() async {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await database.open();
    meetings = SqfliteMeetingRepository(database);
    transcripts = SqfliteTranscriptRepository(database);
    preference = SqfliteDiarizationPreferenceRepository(database);
  });

  tearDown(() => database.close());

  test('说话人能力开关默认开启并可持久化关闭', () async {
    expect(await preference.getEnabled(), isTrue);

    await preference.setEnabled(false);

    expect(await preference.getEnabled(), isFalse);

    await preference.setEnabled(true);

    expect(await preference.getEnabled(), isTrue);
  });

  test('只更新已完成最终快照的说话人标签且保留其余字段', () async {
    final meeting = _meeting();
    final snapshot = _snapshot();
    await meetings.save(meeting);
    await transcripts.saveFinalAndActivate(
      snapshot: snapshot,
      expectedActiveSnapshotId: null,
    );

    final updated = await transcripts.updateSpeakerLabels(
      snapshotId: snapshot.id,
      labelsBySegmentId: const {'segment-1': '张三'},
    );

    final segment = updated.segments.single;
    expect(segment.speakerId, '张三');
    expect(segment.text, '原始文本');
    expect((segment.startMs, segment.endMs), (0, 1000));
    expect((segment.modelId, segment.modelVersion), ('paraformer', '1'));
    expect(updated.status, TranscriptSnapshotStatus.complete);
  });

  test('拒绝未知片段、空标签和未完成快照', () async {
    await meetings.save(_meeting());
    await transcripts.save(_snapshot(status: TranscriptSnapshotStatus.failed));

    await expectLater(
      transcripts.updateSpeakerLabels(
        snapshotId: 'final-1',
        labelsBySegmentId: const {'missing': '张三'},
      ),
      throwsA(isA<DomainInvariantViolation>()),
    );
    await expectLater(
      transcripts.updateSpeakerLabels(
        snapshotId: 'final-1',
        labelsBySegmentId: const {'segment-1': '   '},
      ),
      throwsA(isA<DomainInvariantViolation>()),
    );
  });
}

Meeting _meeting() {
  return Meeting(
    id: 'meeting-1',
    title: '会议',
    createdAt: DateTime.utc(2026, 7, 25),
    status: MeetingState.processing,
    audioDurationMs: 1000,
    recordingModelId: 'paraformer',
    recordingModelVersion: '1',
  );
}

TranscriptSnapshot _snapshot({
  TranscriptSnapshotStatus status = TranscriptSnapshotStatus.complete,
}) {
  return TranscriptSnapshot(
    id: 'final-1',
    meetingId: 'meeting-1',
    kind: TranscriptSnapshotKind.finalTranscript,
    actualModelId: 'paraformer',
    actualModelVersion: '1',
    createdAt: DateTime.utc(2026, 7, 25),
    status: status,
    segments: [
      TranscriptSegment(
        id: 'segment-1',
        snapshotId: 'final-1',
        startMs: 0,
        endMs: 1000,
        text: '原始文本',
        modelId: 'paraformer',
        modelVersion: '1',
      ),
    ],
  );
}
