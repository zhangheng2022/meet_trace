import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/repositories/repository_contracts.dart';
import 'package:meetily_ai/data/services/summary/summary_generation_service.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
import 'package:meetily_ai/domain/models/processing_task.dart';
import 'package:meetily_ai/domain/models/summary.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:meetily_ai/domain/use_cases/generate_summary.dart';

void main() {
  test('只把最终文本和最小片段元数据发送给生成服务', () async {
    final fixture = _fixture(
      draft: GeneratedSummaryDraft(
        overview: '项目按计划推进。',
        keyPoints: const [
          GeneratedSummaryItem(text: '周五发布', evidenceSegmentIds: ['segment-1']),
        ],
        actionItems: const [
          GeneratedSummaryItem(
            text: '张三准备发布清单',
            evidenceSegmentIds: ['segment-2'],
          ),
        ],
      ),
    );

    final result = await fixture.useCase.execute(meetingId: 'meeting-1');

    expect(fixture.service.requests, hasLength(1));
    final request = fixture.service.requests.single;
    expect(request.segments, hasLength(2));
    expect(request.segments.first.id, 'segment-1');
    expect(request.segments.first.text, '周五发布第一版');
    expect(request.segments.first.speakerLabel, '张三');
    expect(
      request.toJson().keys,
      unorderedEquals(['schemaVersion', 'segments']),
    );
    expect(request.toJson().toString(), isNot(contains('/audio/')));
    expect(request.toJson().toString(), isNot(contains('audioPath')));
    expect(result.summary.status, SummaryStatus.complete);
    expect(result.meeting.activeSummaryId, result.summary.id);
    expect(fixture.tasks.records.last.state, ProcessingState.completed);
  });

  test('证据时间和引用只从本地最终片段生成', () async {
    final fixture = _fixture(
      draft: GeneratedSummaryDraft(
        overview: '概览',
        keyPoints: const [
          GeneratedSummaryItem(
            text: '确定发布时间',
            evidenceSegmentIds: ['segment-1'],
          ),
        ],
        actionItems: const [],
      ),
    );

    final result = await fixture.useCase.execute(meetingId: 'meeting-1');

    final evidence = result.summary.keyPoints.single.evidence.single;
    expect(evidence.segmentId, 'segment-1');
    expect((evidence.startMs, evidence.endMs), (100, 900));
    expect(evidence.quote, '周五发布第一版');
  });

  test('未知证据 ID 被丢弃且结论标记为待核对', () async {
    final fixture = _fixture(
      draft: GeneratedSummaryDraft(
        overview: '概览',
        keyPoints: const [
          GeneratedSummaryItem(
            text: '无法核实的结论',
            evidenceSegmentIds: ['unknown-segment'],
          ),
        ],
        actionItems: const [],
      ),
    );

    final result = await fixture.useCase.execute(meetingId: 'meeting-1');

    expect(result.summary.keyPoints.single.evidence, isEmpty);
    expect(result.summary.keyPoints.single.isPendingReview, isTrue);
  });

  test('临时、处理中或非活动快照不能触发总结', () async {
    for (final snapshot in [
      _snapshot(kind: TranscriptSnapshotKind.temporary),
      _snapshot(status: TranscriptSnapshotStatus.processing),
      _snapshot(id: 'not-active'),
    ]) {
      final fixture = _fixture(snapshot: snapshot);

      await expectLater(
        fixture.useCase.execute(meetingId: 'meeting-1'),
        throwsA(
          isA<SummaryGenerationException>().having(
            (error) => error.code,
            'code',
            'summary.snapshot_not_eligible',
          ),
        ),
      );
      expect(fixture.service.requests, isEmpty);
    }
  });

  test('安全网关未配置时不调用生成服务', () async {
    final fixture = _fixture(available: false);

    await expectLater(
      fixture.useCase.execute(meetingId: 'meeting-1'),
      throwsA(
        isA<SummaryGenerationException>().having(
          (error) => error.code,
          'code',
          'summary.gateway_unavailable',
        ),
      ),
    );

    expect(fixture.service.requests, isEmpty);
    expect(fixture.summaries.records, isEmpty);
  });

  test('生成失败只保存失败摘要和任务且不影响最终转录', () async {
    final fixture = _fixture(error: StateError('服务不可用'));
    final before = fixture.meetings.value;

    await expectLater(
      fixture.useCase.execute(meetingId: 'meeting-1'),
      throwsA(isA<SummaryGenerationException>()),
    );

    expect(
      fixture.meetings.value.activeTranscriptSnapshotId,
      before.activeTranscriptSnapshotId,
    );
    expect(fixture.meetings.value.activeSummaryId, isNull);
    expect(
      fixture.summaries.records.values.single.status,
      SummaryStatus.failed,
    );
    expect(fixture.tasks.records.last.state, ProcessingState.failed);
    expect(
      fixture.tasks.records.last.lastErrorCode,
      'summary.generation_failed',
    );
  });

  test('摘要激活后辅助任务写入失败不会反向污染摘要', () async {
    final fixture = _fixture(failCompletedTaskSave: true);

    final result = await fixture.useCase.execute(meetingId: 'meeting-1');

    expect(result.summary.status, SummaryStatus.complete);
    expect(result.meeting.activeSummaryId, result.summary.id);
    expect(
      fixture.summaries.records[result.summary.id]?.status,
      SummaryStatus.complete,
    );
    expect(fixture.tasks.records.single.state, ProcessingState.running);
  });
}

_Fixture _fixture({
  TranscriptSnapshot? snapshot,
  GeneratedSummaryDraft? draft,
  Object? error,
  bool available = true,
  bool failCompletedTaskSave = false,
}) {
  final active = snapshot ?? _snapshot();
  final meetings = _MeetingRepository(_meeting(activeSnapshotId: 'final-1'));
  final transcripts = _TranscriptRepository(active);
  final summaries = _SummaryRepository(meetings);
  final tasks = _TaskRepository(failCompletedSave: failCompletedTaskSave);
  final service = _SummaryService(
    draft:
        draft ??
        GeneratedSummaryDraft(
          overview: '概览',
          keyPoints: const [],
          actionItems: const [],
        ),
    error: error,
    available: available,
  );
  return _Fixture(
    meetings: meetings,
    summaries: summaries,
    tasks: tasks,
    service: service,
    useCase: GenerateSummaryUseCase(
      meetings: meetings,
      transcripts: transcripts,
      summaries: summaries,
      tasks: tasks,
      service: service,
      now: () => DateTime.utc(2026, 7, 25, 6),
    ),
  );
}

final class _Fixture {
  const _Fixture({
    required this.meetings,
    required this.summaries,
    required this.tasks,
    required this.service,
    required this.useCase,
  });

  final _MeetingRepository meetings;
  final _SummaryRepository summaries;
  final _TaskRepository tasks;
  final _SummaryService service;
  final GenerateSummaryUseCase useCase;
}

final class _SummaryService implements SummaryGenerationService {
  _SummaryService({
    required this.draft,
    required this.error,
    required this.available,
  });

  final GeneratedSummaryDraft draft;
  final Object? error;
  final bool available;
  final List<SummaryGenerationRequest> requests = [];

  @override
  SummaryGenerationCapability get capability => available
      ? const SummaryGenerationCapability.available(
          provider: 'test-provider',
          model: 'test-model',
        )
      : const SummaryGenerationCapability.unavailable(
          reasonCode: 'summary.gateway_unavailable',
        );

  @override
  Future<GeneratedSummaryDraft> generate(
    SummaryGenerationRequest request,
  ) async {
    requests.add(request);
    if (error case final error?) {
      throw error;
    }
    return draft;
  }
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
  _TranscriptRepository(this.snapshot);

  TranscriptSnapshot snapshot;

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
  }) async => snapshot;
}

final class _SummaryRepository implements SummaryRepository {
  _SummaryRepository(this.meetings);

  final _MeetingRepository meetings;
  final Map<String, Summary> records = {};

  @override
  Future<Summary?> getById(String summaryId) async => records[summaryId];

  @override
  Future<List<Summary>> listByMeeting(String meetingId) async => records.values
      .where((summary) => summary.meetingId == meetingId)
      .toList();

  @override
  Future<void> save(Summary summary) async {
    records[summary.id] = summary;
  }

  @override
  Future<void> saveAndActivate({
    required Summary summary,
    required String expectedTranscriptSnapshotId,
  }) async {
    records[summary.id] = summary;
    final meeting = meetings.value;
    meetings.value = Meeting(
      id: meeting.id,
      title: meeting.title,
      createdAt: meeting.createdAt,
      startedAt: meeting.startedAt,
      endedAt: meeting.endedAt,
      status: meeting.status,
      audioPath: meeting.audioPath,
      audioDurationMs: meeting.audioDurationMs,
      requestedModelId: meeting.requestedModelId,
      recordingModelId: meeting.recordingModelId,
      recordingModelVersion: meeting.recordingModelVersion,
      modelFallbackReason: meeting.modelFallbackReason,
      activeTranscriptSnapshotId: meeting.activeTranscriptSnapshotId,
      activeSummaryId: summary.id,
      lastErrorCode: meeting.lastErrorCode,
    );
  }
}

final class _TaskRepository implements ProcessingTaskRepository {
  _TaskRepository({this.failCompletedSave = false});

  final bool failCompletedSave;
  final List<ProcessingTask> records = [];

  @override
  Future<ProcessingTask?> getById(String taskId) async {
    for (final task in records.reversed) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  @override
  Future<List<ProcessingTask>> listByMeeting(String meetingId) async =>
      records.where((task) => task.meetingId == meetingId).toList();

  @override
  Future<void> save(ProcessingTask task) async {
    if (failCompletedSave && task.state == ProcessingState.completed) {
      throw StateError('辅助任务状态写入失败');
    }
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
              startMs: 100,
              endMs: 900,
              text: '周五发布第一版',
              speakerId: '张三',
              modelId: 'paraformer',
              modelVersion: '1',
            ),
            TranscriptSegment(
              id: 'segment-2',
              snapshotId: id,
              startMs: 1000,
              endMs: 1800,
              text: '张三准备发布清单',
              speakerId: '李四',
              modelId: 'paraformer',
              modelVersion: '1',
            ),
          ]
        : const [],
  );
}
