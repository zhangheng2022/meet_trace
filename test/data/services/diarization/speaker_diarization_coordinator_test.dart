import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/repository_contracts.dart';
import 'package:meettrace/data/services/diarization/speaker_diarization_coordinator.dart';
import 'package:meettrace/data/services/diarization/speaker_diarization_service.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/processing_task.dart';
import 'package:meettrace/domain/models/speaker_diarization.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';

void main() {
  test('成功映射只更新说话人且保留原文、时间轴和模型归属', () async {
    final fixture = _fixture(
      service: _FakeService(
        turns: const [
          SpeakerTurn(startMs: 0, endMs: 900, speakerId: 'speaker-a'),
          SpeakerTurn(startMs: 900, endMs: 2000, speakerId: 'speaker-b'),
        ],
      ),
    );

    final result = await fixture.coordinator.process(
      meetingId: fixture.meeting.id,
      snapshotId: fixture.snapshot.id,
      enabled: true,
    );

    expect(result.status, SpeakerDiarizationStatus.completed);
    expect(result.snapshot.segments.map((segment) => segment.speakerId), [
      'speaker-a',
      'speaker-b',
    ]);
    expect(
      result.snapshot.segments.map((segment) => segment.text),
      fixture.snapshot.segments.map((segment) => segment.text),
    );
    expect(
      result.snapshot.segments.map(
        (segment) => (
          segment.id,
          segment.startMs,
          segment.endMs,
          segment.modelId,
          segment.modelVersion,
        ),
      ),
      fixture.snapshot.segments.map(
        (segment) => (
          segment.id,
          segment.startMs,
          segment.endMs,
          segment.modelId,
          segment.modelVersion,
        ),
      ),
    );
    expect(fixture.tasks.records.single.state, ProcessingState.completed);
  });

  test('服务失败时降级为单一说话人且最终转录保持 complete', () async {
    final fixture = _fixture(service: _FakeService(error: StateError('资源不足')));

    final result = await fixture.coordinator.process(
      meetingId: fixture.meeting.id,
      snapshotId: fixture.snapshot.id,
      enabled: true,
    );

    expect(result.status, SpeakerDiarizationStatus.degraded);
    expect(result.errorCode, 'speaker_diarization.unexpected');
    expect(result.snapshot.status, TranscriptSnapshotStatus.complete);
    expect(
      result.snapshot.segments.map((segment) => segment.speakerId).toSet(),
      {'speaker-1'},
    );
    expect(fixture.tasks.records.single.state, ProcessingState.failed);
  });

  test('能力不可用时不调用服务并以明确错误码降级', () async {
    final service = _FakeService(available: false);
    final fixture = _fixture(service: service);

    final result = await fixture.coordinator.process(
      meetingId: fixture.meeting.id,
      snapshotId: fixture.snapshot.id,
      enabled: true,
    );

    expect(service.calls, 0);
    expect(result.status, SpeakerDiarizationStatus.degraded);
    expect(result.errorCode, 'speaker_diarization.unavailable');
    expect(result.snapshot.status, TranscriptSnapshotStatus.complete);
  });

  test('超时按稳定错误码降级且不会改写快照身份', () async {
    final fixture = _fixture(
      service: _FakeService(delay: const Duration(seconds: 1)),
      timeout: const Duration(milliseconds: 1),
    );

    final result = await fixture.coordinator.process(
      meetingId: fixture.meeting.id,
      snapshotId: fixture.snapshot.id,
      enabled: true,
    );

    expect(result.errorCode, 'speaker_diarization.timeout');
    expect(result.snapshot.id, fixture.snapshot.id);
    expect(result.snapshot.actualModelId, fixture.snapshot.actualModelId);
    expect(result.snapshot.status, TranscriptSnapshotStatus.complete);
  });

  test('关闭能力时不调用服务也不改写已有标签', () async {
    final service = _FakeService();
    final fixture = _fixture(service: service);

    final result = await fixture.coordinator.process(
      meetingId: fixture.meeting.id,
      snapshotId: fixture.snapshot.id,
      enabled: false,
    );

    expect(result.status, SpeakerDiarizationStatus.disabled);
    expect(service.calls, 0);
    expect(fixture.transcripts.updates, isEmpty);
    expect(fixture.tasks.records, isEmpty);
  });

  test('拒绝处理未完成、非最终或非活动快照', () async {
    for (final snapshot in [
      _snapshot(status: TranscriptSnapshotStatus.processing),
      _snapshot(kind: TranscriptSnapshotKind.temporary),
      _snapshot(id: 'not-active'),
    ]) {
      final fixture = _fixture(snapshot: snapshot, service: _FakeService());

      await expectLater(
        fixture.coordinator.process(
          meetingId: fixture.meeting.id,
          snapshotId: snapshot.id,
          enabled: true,
        ),
        throwsA(
          isA<SpeakerDiarizationException>().having(
            (error) => error.code,
            'code',
            'speaker_diarization.snapshot_not_eligible',
          ),
        ),
      );
    }
  });

  test('人工重命名会持久化同一说话人的全部片段', () async {
    final labeled = _snapshot(speakerIds: const ['speaker-a', 'speaker-a']);
    final fixture = _fixture(snapshot: labeled, service: _FakeService());

    final updated = await fixture.coordinator.renameSpeaker(
      meetingId: fixture.meeting.id,
      snapshotId: labeled.id,
      currentSpeakerId: 'speaker-a',
      newLabel: ' 张三 ',
    );

    expect(updated.segments.map((segment) => segment.speakerId).toSet(), {
      '张三',
    });
    expect(fixture.transcripts.updates.single.values.toSet(), {'张三'});
  });
}

_Fixture _fixture({
  required _FakeService service,
  TranscriptSnapshot? snapshot,
  Duration timeout = const Duration(seconds: 30),
}) {
  final selected = snapshot ?? _snapshot();
  final meeting = _meeting(activeSnapshotId: 'final-1');
  final meetings = _MeetingRepository(meeting);
  final transcripts = _TranscriptRepository(selected);
  final tasks = _TaskRepository();
  return _Fixture(
    meeting: meeting,
    snapshot: selected,
    transcripts: transcripts,
    tasks: tasks,
    coordinator: SpeakerDiarizationCoordinator(
      meetings: meetings,
      transcripts: transcripts,
      tasks: tasks,
      service: service,
      now: () => DateTime.utc(2026, 7, 25, 3),
      timeout: timeout,
    ),
  );
}

final class _Fixture {
  const _Fixture({
    required this.meeting,
    required this.snapshot,
    required this.transcripts,
    required this.tasks,
    required this.coordinator,
  });

  final Meeting meeting;
  final TranscriptSnapshot snapshot;
  final _TranscriptRepository transcripts;
  final _TaskRepository tasks;
  final SpeakerDiarizationCoordinator coordinator;
}

final class _FakeService implements SpeakerDiarizationService {
  _FakeService({
    this.turns = const [],
    this.error,
    this.delay = Duration.zero,
    this.available = true,
  });

  final List<SpeakerTurn> turns;
  final Object? error;
  final Duration delay;
  final bool available;
  int calls = 0;

  @override
  SpeakerDiarizationCapability get capability => available
      ? const SpeakerDiarizationCapability.available()
      : const SpeakerDiarizationCapability.unavailable(
          reasonCode: 'speaker_diarization.unavailable',
        );

  @override
  Future<List<SpeakerTurn>> diarize(AudioSource source) async {
    calls++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (error case final error?) {
      throw error;
    }
    return turns;
  }
}

final class _MeetingRepository implements MeetingRepository {
  _MeetingRepository(this.meeting);

  final Meeting meeting;

  @override
  Future<Meeting?> getById(String meetingId) async =>
      meeting.id == meetingId ? meeting : null;

  @override
  Stream<List<Meeting>> watchAll() => Stream.value([meeting]);

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Future<void> delete(String meetingId) async {}
}

final class _TranscriptRepository implements TranscriptRepository {
  _TranscriptRepository(this.snapshot);

  TranscriptSnapshot snapshot;
  final List<Map<String, String?>> updates = [];

  @override
  Future<TranscriptSnapshot?> getById(String snapshotId) async =>
      snapshot.id == snapshotId ? snapshot : null;

  @override
  Future<List<TranscriptSnapshot>> listByMeeting(String meetingId) async =>
      snapshot.meetingId == meetingId ? [snapshot] : [];

  @override
  Future<void> save(TranscriptSnapshot snapshot) async {
    this.snapshot = snapshot;
  }

  @override
  Future<void> saveFinalAndActivate({
    required TranscriptSnapshot snapshot,
    required String? expectedActiveSnapshotId,
  }) async {
    this.snapshot = snapshot;
  }

  @override
  Future<TranscriptSnapshot> updateSpeakerLabels({
    required String snapshotId,
    required Map<String, String?> labelsBySegmentId,
  }) async {
    updates.add(Map.of(labelsBySegmentId));
    snapshot = TranscriptSnapshot(
      id: snapshot.id,
      meetingId: snapshot.meetingId,
      kind: snapshot.kind,
      actualModelId: snapshot.actualModelId,
      actualModelVersion: snapshot.actualModelVersion,
      createdAt: snapshot.createdAt,
      status: snapshot.status,
      segments: [
        for (final segment in snapshot.segments)
          TranscriptSegment(
            id: segment.id,
            snapshotId: segment.snapshotId,
            startMs: segment.startMs,
            endMs: segment.endMs,
            text: segment.text,
            speakerId: labelsBySegmentId[segment.id] ?? segment.speakerId,
            confidence: segment.confidence,
            modelId: segment.modelId,
            modelVersion: segment.modelVersion,
          ),
      ],
    );
    return snapshot;
  }
}

final class _TaskRepository implements ProcessingTaskRepository {
  final List<ProcessingTask> records = [];

  @override
  Future<ProcessingTask?> getById(String taskId) async {
    for (final record in records.reversed) {
      if (record.id == taskId) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<List<ProcessingTask>> listByMeeting(String meetingId) async =>
      records.where((task) => task.meetingId == meetingId).toList();

  @override
  Future<void> save(ProcessingTask task) async {
    records.removeWhere((record) => record.id == task.id);
    records.add(task);
  }
}

Meeting _meeting({required String activeSnapshotId}) {
  return Meeting(
    id: 'meeting-1',
    title: '周会',
    createdAt: DateTime.utc(2026, 7, 25),
    startedAt: DateTime.utc(2026, 7, 25, 1),
    endedAt: DateTime.utc(2026, 7, 25, 1, 0, 2),
    status: MeetingState.completed,
    audioPath: '/audio/fact.pcm',
    audioDurationMs: 2000,
    requestedModelId: 'paraformer',
    recordingModelId: 'paraformer',
    recordingModelVersion: '1',
    activeTranscriptSnapshotId: activeSnapshotId,
  );
}

TranscriptSnapshot _snapshot({
  String id = 'final-1',
  TranscriptSnapshotKind kind = TranscriptSnapshotKind.finalTranscript,
  TranscriptSnapshotStatus status = TranscriptSnapshotStatus.complete,
  List<String?> speakerIds = const [null, null],
}) {
  return TranscriptSnapshot(
    id: id,
    meetingId: 'meeting-1',
    kind: kind,
    actualModelId: 'paraformer',
    actualModelVersion: '1',
    createdAt: DateTime.utc(2026, 7, 25, 2),
    status: status,
    segments: status == TranscriptSnapshotStatus.complete
        ? [
            TranscriptSegment(
              id: 'segment-1',
              snapshotId: id,
              startMs: 0,
              endMs: 800,
              text: '第一段原文',
              speakerId: speakerIds[0],
              modelId: 'paraformer',
              modelVersion: '1',
            ),
            TranscriptSegment(
              id: 'segment-2',
              snapshotId: id,
              startMs: 1000,
              endMs: 1800,
              text: '第二段原文',
              speakerId: speakerIds[1],
              modelId: 'paraformer',
              modelVersion: '1',
            ),
          ]
        : const [],
  );
}
