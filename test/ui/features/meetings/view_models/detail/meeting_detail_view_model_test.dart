import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/repository_contracts.dart';
import 'package:meettrace/data/services/asr/final_transcription_service.dart';
import 'package:meettrace/data/services/diarization/speaker_diarization_coordinator.dart';
import 'package:meettrace/data/services/summary/summary_generation_service.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/processing_task.dart';
import 'package:meettrace/domain/models/speaker_diarization.dart';
import 'package:meettrace/domain/models/summary.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/use_cases/generate_summary.dart';
import 'package:meettrace/ui/features/meetings/view_models/detail/meeting_detail_view_model.dart';

import '../../../../../support/final_transcription_fakes.dart';
import '../../../../../support/model_selection_fakes.dart';

void main() {
  test('processing 会议自动使用锁定模型并接收完整音频进度', () async {
    final fixture = _fixture(_meeting());
    final completed = _snapshot(id: 'final-1');
    fixture.runner.onCall =
        ({
          required meetingId,
          required modelId,
          required modelVersion,
          required retrySnapshotId,
          required onProgress,
        }) async {
          final meeting = fixture.meetings.value!.activateFinalTranscript(
            completed,
          );
          fixture.meetings.value = meeting;
          fixture.transcripts.records[completed.id] = completed;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await fixture.viewModel.load();

    expect(fixture.runner.calls.single.modelId, isNull);
    expect(fixture.runner.calls.single.modelVersion, isNull);
    expect(fixture.viewModel.progress, 1);
    expect(fixture.viewModel.snapshot?.id, completed.id);
    expect(fixture.viewModel.meeting.status, MeetingState.completed);
    await fixture.dispose();
  });

  test('失败后重试复用失败 snapshot ID 和来源模型', () async {
    final fixture = _fixture(_meeting());
    final failed = _snapshot(
      id: 'failed-1',
      status: TranscriptSnapshotStatus.failed,
    );
    var attempt = 0;
    fixture.runner.onCall =
        ({
          required meetingId,
          required modelId,
          required modelVersion,
          required retrySnapshotId,
          required onProgress,
        }) async {
          attempt++;
          if (attempt == 1) {
            fixture.transcripts.records[failed.id] = failed;
            fixture.meetings.value = fixture.meetings.value!.fail(
              errorCode: 'asr.failed',
            );
            throw StateError('failed');
          }
          final completed = _snapshot(id: failed.id);
          final processing = fixture.meetings.value!.beginFinalTranscription();
          final meeting = processing.activateFinalTranscript(completed);
          fixture.meetings.value = meeting;
          fixture.transcripts.records[completed.id] = completed;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await fixture.viewModel.load();
    expect(fixture.viewModel.canRetry, isTrue);

    await fixture.viewModel.retry();

    final retry = fixture.runner.calls.last;
    expect(retry.retrySnapshotId, failed.id);
    expect(retry.modelId, senseVoiceDefaultModelId);
    expect(retry.modelVersion, '2024-07-17');
    expect(
      fixture.viewModel.snapshot?.status,
      TranscriptSnapshotStatus.complete,
    );
    await fixture.dispose();
  });

  test('完成后可选择当前已安装 SenseVoice 生成独立重转录', () async {
    final active = _snapshot(id: 'old');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
    );
    fixture.runner.onCall =
        ({
          required meetingId,
          required modelId,
          required modelVersion,
          required retrySnapshotId,
          required onProgress,
        }) async {
          final completed = _snapshot(
            id: 'sense-voice-new',
            modelId: senseVoiceDefaultModelId,
            modelVersion: '2024-07-17',
          );
          final processing = fixture.meetings.value!.beginFinalTranscription();
          final meeting = processing.activateFinalTranscript(completed);
          fixture.meetings.value = meeting;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };
    await fixture.viewModel.load();

    fixture.viewModel.selectModel(senseVoiceDefaultModelId);
    await fixture.viewModel.retranscribe();

    expect(fixture.runner.calls.single.modelId, senseVoiceDefaultModelId);
    expect(fixture.runner.calls.single.retrySnapshotId, isNull);
    expect(fixture.viewModel.snapshot?.id, 'sense-voice-new');
    await fixture.dispose();
  });

  test('恢复 processing 快照时复用原 ID 和来源模型而不改回锁定模型', () async {
    final pending = _snapshot(
      id: 'sense-voice-pending',
      status: TranscriptSnapshotStatus.processing,
      modelId: senseVoiceDefaultModelId,
      modelVersion: '2024-07-17',
    );
    final fixture = _fixture(_meeting());
    fixture.transcripts.records[pending.id] = pending;
    fixture.runner.onCall =
        ({
          required meetingId,
          required modelId,
          required modelVersion,
          required retrySnapshotId,
          required onProgress,
        }) async {
          final completed = _snapshot(
            id: pending.id,
            modelId: senseVoiceDefaultModelId,
            modelVersion: '2024-07-17',
          );
          final meeting = fixture.meetings.value!.activateFinalTranscript(
            completed,
          );
          fixture.meetings.value = meeting;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await fixture.viewModel.load();

    final resumed = fixture.runner.calls.single;
    expect(resumed.retrySnapshotId, pending.id);
    expect(resumed.modelId, senseVoiceDefaultModelId);
    expect(resumed.modelVersion, '2024-07-17');
    await fixture.dispose();
  });

  test('说话人服务失败后最终转录仍可用并显示独立降级状态', () async {
    final active = _snapshot(id: 'active');
    final diarization = _DiarizationRunner(
      result: SpeakerDiarizationResult(
        snapshot: _snapshot(id: 'active', speakerId: 'speaker-1'),
        status: SpeakerDiarizationStatus.degraded,
        errorCode: 'speaker_diarization.timeout',
      ),
    );
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      diarization: diarization,
      diarizationEnabled: true,
    );

    await fixture.viewModel.load();

    expect(diarization.processCalls, 1);
    expect(
      fixture.viewModel.snapshot?.status,
      TranscriptSnapshotStatus.complete,
    );
    expect(
      fixture.viewModel.diarizationStatus,
      SpeakerDiarizationStatus.degraded,
    );
    expect(fixture.viewModel.diarizationMessage, contains('单一说话人'));
    expect(fixture.viewModel.errorMessage, isNull);
    await fixture.dispose();
  });

  test('人工修改说话人标签后刷新最终快照', () async {
    final active = _snapshot(id: 'active', speakerId: 'speaker-a');
    final diarization = _DiarizationRunner(
      result: SpeakerDiarizationResult(
        snapshot: active,
        status: SpeakerDiarizationStatus.disabled,
      ),
    );
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      diarization: diarization,
    );
    await fixture.viewModel.load();

    await fixture.viewModel.renameSpeaker('speaker-a', ' 张三 ');

    expect(diarization.renameCalls.single, ('speaker-a', ' 张三 '));
    expect(fixture.viewModel.snapshot?.segments.single.speakerId, '张三');
    await fixture.dispose();
  });

  test('重新打开页面会从持久化失败任务恢复降级提示且不重复运行', () async {
    final active = _snapshot(id: 'active', speakerId: 'speaker-1');
    final diarization = _DiarizationRunner(
      result: SpeakerDiarizationResult(
        snapshot: active,
        status: SpeakerDiarizationStatus.degraded,
      ),
    );
    final tasks = _TaskRepository([
      ProcessingTask(
        id: 'speaker-diarization-active',
        kind: ProcessingTaskKind.speakerDiarization,
        meetingId: 'meeting-1',
        state: ProcessingState.failed,
        createdAt: DateTime.utc(2026, 7, 25, 3),
        updatedAt: DateTime.utc(2026, 7, 25, 3),
        lastErrorCode: 'speaker_diarization.timeout',
      ),
    ]);
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      diarization: diarization,
      diarizationEnabled: true,
      processingTasks: tasks,
    );

    await fixture.viewModel.load();

    expect(diarization.processCalls, 0);
    expect(
      fixture.viewModel.diarizationStatus,
      SpeakerDiarizationStatus.degraded,
    );
    expect(fixture.viewModel.diarizationMessage, contains('最终转录不受影响'));
    await fixture.dispose();
  });

  test('加载会议时恢复当前摘要和本地证据', () async {
    final active = _snapshot(id: 'active');
    final summary = _summary(
      id: 'summary-active',
      snapshot: active,
      status: SummaryStatus.complete,
    );
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
        activeSummaryId: summary.id,
      ),
      active: active,
      summary: summary,
    );

    await fixture.viewModel.load();

    expect(fixture.viewModel.summary?.overview, '会议概览');
    final evidence =
        fixture.viewModel.summary!.keyPoints.single.evidence.single;
    expect(evidence.segmentId, active.segments.single.id);
    expect(evidence.quote, active.segments.single.text);
    await fixture.dispose();
  });

  test('详情 Facade 向分区 ViewModel 暴露一致状态', () async {
    final active = _snapshot(id: 'active');
    final summary = _summary(
      id: 'summary-active',
      snapshot: active,
      status: SummaryStatus.complete,
    );
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
        activeSummaryId: summary.id,
      ),
      active: active,
      summary: summary,
    );

    await fixture.viewModel.load();

    final viewModel = fixture.viewModel;
    expect(viewModel.state.meeting, same(viewModel.meeting));
    expect(viewModel.state.snapshot, same(viewModel.snapshot));
    expect(viewModel.state.summary, same(viewModel.summary));
    expect(viewModel.transcriptSection.snapshot, same(viewModel.snapshot));
    expect(viewModel.summarySection.summary, same(viewModel.summary));
    expect(viewModel.audioSection.state, viewModel.playbackState);
    expect(viewModel.actions.canShare, viewModel.canShare);
    await fixture.dispose();
  });

  test('仅使用当前最终转录生成摘要并原子激活', () async {
    final active = _snapshot(id: 'active');
    final service = _SummaryService();
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      summaryService: service,
    );
    await fixture.viewModel.load();

    await fixture.viewModel.generateSummary();

    expect(service.requests.single.segments.single.id, 'active-segment');
    expect(service.requests.single.toJson(), isNot(contains('audioPath')));
    expect(fixture.viewModel.meeting.activeSummaryId, 'summary-active');
    expect(fixture.viewModel.summary?.status, SummaryStatus.complete);
    expect(
      fixture.viewModel.summary!.keyPoints.single.evidence.single.quote,
      '最终事实文本',
    );
    await fixture.dispose();
  });

  test('待生成标题的会议在最终转录就绪后自动生成总结和标题', () async {
    final active = _snapshot(id: 'active');
    final service = _SummaryService();
    final fixture = _fixture(
      _meeting(
        title: pendingMeetingTitle,
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      summaryService: service,
    );

    await fixture.viewModel.load();

    expect(service.requests, hasLength(1));
    expect(fixture.viewModel.meeting.title, '产品评审会');
    expect(fixture.viewModel.meeting.activeSummaryId, 'summary-active');
    expect(fixture.viewModel.summaryMessage, contains('会议标题已生成'));
    await fixture.dispose();
  });

  test('摘要失败不隐藏最终转录且可重试', () async {
    final active = _snapshot(id: 'active');
    final service = _SummaryService(errorCode: 'summary.remote_failed');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      summaryService: service,
    );
    await fixture.viewModel.load();

    await fixture.viewModel.generateSummary();

    expect(fixture.viewModel.snapshot?.segments.single.text, '最终事实文本');
    expect(fixture.viewModel.summary?.status, SummaryStatus.failed);
    expect(fixture.viewModel.summaryMessage, contains('最终转录不受影响'));

    service.errorCode = null;
    await fixture.viewModel.generateSummary();

    expect(service.requests, hasLength(2));
    expect(fixture.viewModel.summary?.status, SummaryStatus.complete);
    expect(fixture.viewModel.meeting.activeSummaryId, 'summary-active');
    await fixture.dispose();
  });
}

_Fixture _fixture(
  Meeting meeting, {
  TranscriptSnapshot? active,
  SpeakerDiarizationRunner? diarization,
  bool diarizationEnabled = false,
  ProcessingTaskRepository? processingTasks,
  Summary? summary,
  SummaryGenerationService? summaryService,
}) {
  final meetings = DetailMeetingRepository(meeting);
  final transcripts = DetailTranscriptRepository();
  if (active != null) {
    transcripts.records[active.id] = active;
  }
  final summaries = DetailSummaryRepository(meetings);
  if (summary != null) {
    summaries.records[summary.id] = summary;
  }
  final summaryTasks = DetailProcessingTaskRepository();
  final selectedTasks = processingTasks ?? summaryTasks;
  final summaryGeneration = summaryService == null
      ? null
      : GenerateSummaryUseCase(
          meetings: meetings,
          transcripts: transcripts,
          summaries: summaries,
          tasks: selectedTasks,
          service: summaryService,
          now: () => DateTime.utc(2026, 7, 25, 4),
        );
  final installations = TestActiveInstallations();
  final registry = AsrModelRegistry.alpha;
  installations.install(
    installations.installed(registry.requireById(senseVoiceDefaultModelId)),
  );
  late final DetailTranscriptionRunner runner;
  runner = DetailTranscriptionRunner(
    ({
      required meetingId,
      required modelId,
      required modelVersion,
      required retrySnapshotId,
      required onProgress,
    }) => throw UnimplementedError(),
  );
  return _Fixture(
    meetings: meetings,
    transcripts: transcripts,
    installations: installations,
    runner: runner,
    summaries: summaries,
    summaryTasks: summaryTasks,
    viewModel: MeetingDetailViewModel(
      meeting: meeting,
      meetings: meetings,
      transcripts: transcripts,
      installations: installations,
      transcription: runner,
      diarization: diarization,
      diarizationPreferences: _DiarizationPreference(diarizationEnabled),
      processingTasks: selectedTasks,
      summaries: summaries,
      summaryGeneration: summaryGeneration,
    ),
  );
}

final class _Fixture {
  const _Fixture({
    required this.meetings,
    required this.transcripts,
    required this.installations,
    required this.runner,
    required this.summaries,
    required this.summaryTasks,
    required this.viewModel,
  });

  final DetailMeetingRepository meetings;
  final DetailTranscriptRepository transcripts;
  final TestActiveInstallations installations;
  final DetailTranscriptionRunner runner;
  final DetailSummaryRepository summaries;
  final DetailProcessingTaskRepository summaryTasks;
  final MeetingDetailViewModel viewModel;

  Future<void> dispose() async {
    viewModel.dispose();
    await installations.dispose();
  }
}

Meeting _meeting({
  String title = '周会',
  MeetingState status = MeetingState.processing,
  String? activeTranscriptSnapshotId,
  String? activeSummaryId,
}) {
  return Meeting(
    id: 'meeting-1',
    title: title,
    createdAt: DateTime.utc(2026, 7, 25),
    startedAt: DateTime.utc(2026, 7, 25, 1),
    endedAt: DateTime.utc(2026, 7, 25, 1, 0, 2),
    status: status,
    audioPath: '/audio/fact.pcm',
    audioDurationMs: 2000,
    requestedModelId: senseVoiceDefaultModelId,
    recordingModelId: senseVoiceDefaultModelId,
    recordingModelVersion: '2024-07-17',
    activeTranscriptSnapshotId: activeTranscriptSnapshotId,
    activeSummaryId: activeSummaryId,
  );
}

TranscriptSnapshot _snapshot({
  required String id,
  TranscriptSnapshotStatus status = TranscriptSnapshotStatus.complete,
  String modelId = senseVoiceDefaultModelId,
  String modelVersion = '2024-07-17',
  String? speakerId,
}) {
  return TranscriptSnapshot(
    id: id,
    meetingId: 'meeting-1',
    kind: TranscriptSnapshotKind.finalTranscript,
    actualModelId: modelId,
    actualModelVersion: modelVersion,
    createdAt: DateTime.utc(2026, 7, 25, 2),
    status: status,
    segments: status == TranscriptSnapshotStatus.complete
        ? [
            TranscriptSegment(
              id: '$id-segment',
              snapshotId: id,
              startMs: 0,
              endMs: 1000,
              text: '最终事实文本',
              speakerId: speakerId,
              modelId: modelId,
              modelVersion: modelVersion,
            ),
          ]
        : const [],
  );
}

Summary _summary({
  required String id,
  required TranscriptSnapshot snapshot,
  required SummaryStatus status,
}) {
  final segment = snapshot.segments.single;
  return Summary(
    id: id,
    meetingId: snapshot.meetingId,
    transcriptSnapshotId: snapshot.id,
    provider: 'test-provider',
    model: 'test-model',
    createdAt: DateTime.utc(2026, 7, 25, 3),
    overview: status == SummaryStatus.complete ? '会议概览' : '',
    keyPoints: status == SummaryStatus.complete
        ? [
            SummaryItem(
              id: '$id-key-point-1',
              text: '关键结论',
              evidence: [
                SummaryEvidence(
                  segmentId: segment.id,
                  startMs: segment.startMs,
                  endMs: segment.endMs,
                  quote: segment.text,
                ),
              ],
            ),
          ]
        : const [],
    actionItems: const [],
    status: status,
  );
}

final class _SummaryService implements SummaryGenerationService {
  _SummaryService({this.errorCode});

  String? errorCode;
  final List<SummaryGenerationRequest> requests = [];

  @override
  SummaryGenerationCapability get capability =>
      const SummaryGenerationCapability.available(
        provider: 'test-provider',
        model: 'test-model',
      );

  @override
  Future<GeneratedSummaryDraft> generate(
    SummaryGenerationRequest request,
  ) async {
    requests.add(request);
    final code = errorCode;
    if (code != null) {
      throw SummaryGenerationServiceException(code);
    }
    return GeneratedSummaryDraft(
      title: '产品评审会',
      overview: '会议概览',
      keyPoints: [
        GeneratedSummaryItem(
          text: '关键结论',
          evidenceSegmentIds: [request.segments.single.id],
        ),
      ],
      actionItems: [
        GeneratedSummaryItem(text: '待核对行动项', evidenceSegmentIds: const []),
      ],
    );
  }
}

final class _DiarizationPreference implements DiarizationPreferenceRepository {
  _DiarizationPreference(this.enabled);

  bool enabled;

  @override
  Future<bool> getEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    this.enabled = enabled;
  }
}

final class _DiarizationRunner implements SpeakerDiarizationRunner {
  _DiarizationRunner({required this.result});

  SpeakerDiarizationResult result;
  int processCalls = 0;
  final List<(String?, String)> renameCalls = [];

  @override
  SpeakerDiarizationCapability get capability =>
      const SpeakerDiarizationCapability.available();

  @override
  Future<SpeakerDiarizationResult> process({
    required String meetingId,
    required String snapshotId,
    required bool enabled,
  }) async {
    processCalls++;
    return result;
  }

  @override
  Future<TranscriptSnapshot> renameSpeaker({
    required String meetingId,
    required String snapshotId,
    required String? currentSpeakerId,
    required String newLabel,
  }) async {
    renameCalls.add((currentSpeakerId, newLabel));
    final source = result.snapshot;
    final updated = TranscriptSnapshot(
      id: source.id,
      meetingId: source.meetingId,
      kind: source.kind,
      actualModelId: source.actualModelId,
      actualModelVersion: source.actualModelVersion,
      createdAt: source.createdAt,
      status: source.status,
      segments: [
        for (final segment in source.segments)
          TranscriptSegment(
            id: segment.id,
            snapshotId: segment.snapshotId,
            startMs: segment.startMs,
            endMs: segment.endMs,
            text: segment.text,
            speakerId: newLabel.trim(),
            confidence: segment.confidence,
            modelId: segment.modelId,
            modelVersion: segment.modelVersion,
          ),
      ],
    );
    result = SpeakerDiarizationResult(
      snapshot: updated,
      status: result.status,
      errorCode: result.errorCode,
    );
    return updated;
  }
}

final class _TaskRepository implements ProcessingTaskRepository {
  _TaskRepository(this.records);

  final List<ProcessingTask> records;

  @override
  Future<ProcessingTask?> getById(String taskId) async {
    for (final task in records) {
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
    records.removeWhere((record) => record.id == task.id);
    records.add(task);
  }
}
