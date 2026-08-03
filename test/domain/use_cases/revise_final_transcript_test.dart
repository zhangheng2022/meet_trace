import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/use_cases/revise_final_transcript.dart';

void main() {
  test('编辑文本和说话人生成新最终快照并保留旧版本', () async {
    final source = _snapshot();
    final meetings = _MeetingRepository(_meeting(source.id));
    final transcripts = _TranscriptRepository(source, meetings);
    final useCase = ReviseFinalTranscriptUseCase(
      meetings: meetings,
      transcripts: transcripts,
      now: () => DateTime.utc(2026, 7, 25, 9),
      snapshotIdFactory: (_, _) => 'revision-1',
    );

    final result = await useCase.execute(
      meetingId: 'meeting-1',
      revisions: [
        const TranscriptSegmentRevision(
          segmentId: 'segment-1',
          text: '修订后的事实',
          speakerLabel: '张三',
        ),
      ],
    );

    expect(result.snapshot.id, 'revision-1');
    expect(result.snapshot.segments.single.id, 'revision-1-segment-1');
    expect(result.snapshot.segments.single.text, '修订后的事实');
    expect(result.snapshot.segments.single.speakerId, '张三');
    expect(result.meeting.activeTranscriptSnapshotId, 'revision-1');
    expect(result.meeting.activeSummaryId, isNull);
    expect(transcripts.records[source.id], same(source));
  });

  test('遗漏片段、空文本或没有实际变化时拒绝生成伪版本', () async {
    final source = _snapshot();

    for (final revisions in <List<TranscriptSegmentRevision>>[
      const [],
      const [
        TranscriptSegmentRevision(
          segmentId: 'segment-1',
          text: ' ',
          speakerLabel: '说话人 1',
        ),
      ],
      const [
        TranscriptSegmentRevision(
          segmentId: 'segment-1',
          text: '原始事实',
          speakerLabel: '说话人 1',
        ),
      ],
    ]) {
      final meetings = _MeetingRepository(_meeting(source.id));
      final transcripts = _TranscriptRepository(source, meetings);
      final useCase = ReviseFinalTranscriptUseCase(
        meetings: meetings,
        transcripts: transcripts,
        now: DateTime.now,
      );

      await expectLater(
        useCase.execute(meetingId: 'meeting-1', revisions: revisions),
        throwsA(isA<TranscriptRevisionException>()),
      );
      expect(transcripts.records, hasLength(1));
    }
  });
}

final class _MeetingRepository implements MeetingRepository {
  _MeetingRepository(this.value);

  Meeting value;

  @override
  Future<Meeting?> getById(String meetingId) async =>
      value.id == meetingId ? value : null;

  @override
  Stream<List<Meeting>> watchAll() => Stream.value([value]);

  @override
  Future<void> save(Meeting meeting) async {
    value = meeting;
  }

  @override
  Future<void> delete(String meetingId) async {}
}

final class _TranscriptRepository implements TranscriptRepository {
  _TranscriptRepository(TranscriptSnapshot source, this.meetings)
    : records = {source.id: source};

  final _MeetingRepository meetings;
  final Map<String, TranscriptSnapshot> records;

  @override
  Future<TranscriptSnapshot?> getById(String snapshotId) async =>
      records[snapshotId];

  @override
  Future<List<TranscriptSnapshot>> listByMeeting(String meetingId) async =>
      records.values
          .where((snapshot) => snapshot.meetingId == meetingId)
          .toList();

  @override
  Future<void> save(TranscriptSnapshot snapshot) async {
    records[snapshot.id] = snapshot;
  }

  @override
  Future<void> saveFinalAndActivate({
    required TranscriptSnapshot snapshot,
    required String? expectedActiveSnapshotId,
  }) async {
    expect(meetings.value.activeTranscriptSnapshotId, expectedActiveSnapshotId);
    records[snapshot.id] = snapshot;
    meetings.value = Meeting(
      id: meetings.value.id,
      title: meetings.value.title,
      createdAt: meetings.value.createdAt,
      startedAt: meetings.value.startedAt,
      endedAt: meetings.value.endedAt,
      status: meetings.value.status,
      audioPath: meetings.value.audioPath,
      audioDurationMs: meetings.value.audioDurationMs,
      recordingModelId: meetings.value.recordingModelId,
      recordingModelVersion: meetings.value.recordingModelVersion,
      activeTranscriptSnapshotId: snapshot.id,
    );
  }

  @override
  Future<TranscriptSnapshot> updateSpeakerLabels({
    required String snapshotId,
    required Map<String, String?> labelsBySegmentId,
  }) async => records[snapshotId]!;
}

Meeting _meeting(String snapshotId) => Meeting(
  id: 'meeting-1',
  title: '周会',
  createdAt: DateTime.utc(2026, 7, 25),
  startedAt: DateTime.utc(2026, 7, 25, 1),
  endedAt: DateTime.utc(2026, 7, 25, 1, 0, 1),
  status: MeetingState.completed,
  audioPath: '/private/fact.pcm',
  audioDurationMs: 1000,
  recordingModelId: 'paraformer',
  recordingModelVersion: '1',
  activeTranscriptSnapshotId: snapshotId,
  activeSummaryId: 'summary-1',
);

TranscriptSnapshot _snapshot() => TranscriptSnapshot(
  id: 'final-1',
  meetingId: 'meeting-1',
  kind: TranscriptSnapshotKind.finalTranscript,
  actualModelId: 'paraformer',
  actualModelVersion: '1',
  createdAt: DateTime.utc(2026, 7, 25, 2),
  status: TranscriptSnapshotStatus.complete,
  segments: [
    TranscriptSegment(
      id: 'segment-1',
      snapshotId: 'final-1',
      startMs: 0,
      endMs: 1000,
      text: '原始事实',
      speakerId: '说话人 1',
      modelId: 'paraformer',
      modelVersion: '1',
    ),
  ],
);
