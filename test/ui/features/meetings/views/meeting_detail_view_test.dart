import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/app/application.dart';
import 'package:meetily_ai/data/repositories/repository_contracts.dart';
import 'package:meetily_ai/data/services/asr/final_transcription_service.dart';
import 'package:meetily_ai/data/services/diarization/speaker_diarization_coordinator.dart';
import 'package:meetily_ai/data/services/summary/summary_generation_service.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
import 'package:meetily_ai/domain/models/speaker_diarization.dart';
import 'package:meetily_ai/domain/models/summary.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:meetily_ai/domain/use_cases/generate_summary.dart';
import 'package:meetily_ai/ui/features/meetings/view_models/meeting_detail_view_model.dart';
import 'package:meetily_ai/ui/features/meetings/views/meeting_detail_view.dart';

import '../../../../support/final_transcription_fakes.dart';
import '../../../../support/model_selection_fakes.dart';

void main() {
  testWidgets('完成页显示最终事实文本并可选择高级模型生成独立快照', (tester) async {
    final old = _snapshot(id: 'old');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: old.id,
      ),
      active: old,
      installQwen: true,
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
            id: 'qwen-new',
            modelId: qwenAdvancedModelId,
            modelVersion: '2026-03-25',
            text: '高级模型最终文本',
          );
          final meeting = fixture.meetings.value!
              .beginFinalTranscription()
              .activateFinalTranscript(completed);
          fixture.meetings.value = meeting;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('最终事实文本'), findsOneWidget);
    expect(find.text('标准模型（Paraformer）'), findsOneWidget);
    expect(find.text('高级模型（Qwen3-ASR）'), findsOneWidget);

    final advanced = find.text('高级模型（Qwen3-ASR）');
    await tester.ensureVisible(advanced);
    await tester.tap(advanced);
    await tester.pump();
    final retranscribe = find.text('使用所选模型重新转录');
    await tester.ensureVisible(retranscribe);
    await tester.tap(retranscribe);
    await tester.pumpAndSettle();

    expect(fixture.runner.calls.single.modelId, qwenAdvancedModelId);
    expect(fixture.runner.calls.single.retrySnapshotId, isNull);
    expect(find.textContaining('高级模型最终文本'), findsOneWidget);
    expect(find.text('来源模型：高级模型（Qwen3-ASR）'), findsOneWidget);
    await fixture.dispose();
  });

  testWidgets('处理失败显示保留事实提示并以同一快照重试', (tester) async {
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
          final completed = _snapshot(id: failed.id, text: '重试后的最终文本');
          final meeting = fixture.meetings.value!
              .beginFinalTranscription()
              .activateFinalTranscript(completed);
          fixture.meetings.value = meeting;
          fixture.transcripts.records[completed.id] = completed;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最终转录未完成'), findsOneWidget);
    expect(find.textContaining('事实音频和旧结果均已保留'), findsOneWidget);

    await tester.tap(find.text('重试最终转录'));
    await tester.pumpAndSettle();

    expect(fixture.runner.calls.last.retrySnapshotId, failed.id);
    expect(find.textContaining('重试后的最终文本'), findsOneWidget);
    await fixture.dispose();
  });

  testWidgets('未配置分离模型时仍可手工保存说话人标签', (tester) async {
    final active = _snapshot(id: 'active', speakerId: 'speaker-1');
    final diarization = _DiarizationRunner(
      result: SpeakerDiarizationResult(
        snapshot: active,
        status: SpeakerDiarizationStatus.disabled,
      ),
      available: false,
    );
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      diarization: diarization,
    );

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('当前构建未配置已验证'), findsOneWidget);
    expect(find.textContaining('说话人 1 · 00:00'), findsOneWidget);

    final field = find.byKey(const ValueKey('speaker-label-speaker-1'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '张三');
    final save = find.byKey(const ValueKey('save-speaker-label-speaker-1'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(diarization.renameCalls.single, ('speaker-1', '张三'));
    expect(find.textContaining('张三 · 00:00'), findsOneWidget);
    expect(find.text('说话人标签已保存'), findsOneWidget);
    await fixture.dispose();
  });

  testWidgets('分离失败提示降级但继续显示最终转录', (tester) async {
    final active = _snapshot(id: 'active');
    final degraded = _snapshot(id: 'active', speakerId: 'speaker-1');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      diarization: _DiarizationRunner(
        result: SpeakerDiarizationResult(
          snapshot: degraded,
          status: SpeakerDiarizationStatus.degraded,
          errorCode: 'speaker_diarization.timeout',
        ),
      ),
      diarizationEnabled: true,
    );

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('最终事实文本'), findsOneWidget);
    expect(find.text('说话人分离已降级'), findsOneWidget);
    expect(find.textContaining('最终转录不受影响'), findsOneWidget);
    await fixture.dispose();
  });

  testWidgets('未配置安全网关时中文说明总结已关闭且最终转录可见', (tester) async {
    final active = _snapshot(id: 'active');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      summaryService: const UnavailableSummaryGenerationService(),
    );

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('最终事实文本'), findsOneWidget);
    expect(find.text('安全总结网关未配置'), findsOneWidget);
    expect(find.textContaining('不会上传音频或会中临时文本'), findsOneWidget);
    expect(find.byKey(const ValueKey('generate-summary')), findsNothing);
    await fixture.dispose();
  });

  testWidgets('已完成总结显示本地原文证据并标记待核对项', (tester) async {
    final active = _snapshot(id: 'active');
    final summary = _summary(id: 'summary-active', snapshot: active);
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
        activeSummaryId: summary.id,
      ),
      active: active,
      summary: summary,
    );

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('会议概览'), findsOneWidget);
    expect(find.text('关键结论'), findsOneWidget);
    expect(find.text('证据 00:00–00:01：最终事实文本'), findsOneWidget);
    expect(find.text('待核对：未找到有效原文证据'), findsOneWidget);
    await fixture.dispose();
  });
}

_Fixture _fixture(
  Meeting meeting, {
  TranscriptSnapshot? active,
  bool installQwen = false,
  SpeakerDiarizationRunner? diarization,
  bool diarizationEnabled = false,
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
  final summaryGeneration = summaryService == null
      ? null
      : GenerateSummaryUseCase(
          meetings: meetings,
          transcripts: transcripts,
          summaries: summaries,
          tasks: summaryTasks,
          service: summaryService,
          now: () => DateTime.utc(2026, 7, 25, 4),
        );
  final installations = TestActiveInstallations();
  final registry = AsrModelRegistry.alpha;
  installations.install(
    installations.installed(registry.requireById(paraformerStandardModelId)),
  );
  if (installQwen) {
    installations.install(
      installations.installed(registry.requireById(qwenAdvancedModelId)),
    );
  }
  final runner = DetailTranscriptionRunner(
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
      processingTasks: summaryTasks,
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
  MeetingState status = MeetingState.processing,
  String? activeTranscriptSnapshotId,
  String? activeSummaryId,
}) {
  return Meeting(
    id: 'meeting-1',
    title: '周会',
    createdAt: DateTime.utc(2026, 7, 25),
    startedAt: DateTime.utc(2026, 7, 25, 1),
    endedAt: DateTime.utc(2026, 7, 25, 1, 0, 2),
    status: status,
    audioPath: '/audio/fact.pcm',
    audioDurationMs: 2000,
    requestedModelId: paraformerStandardModelId,
    recordingModelId: paraformerStandardModelId,
    recordingModelVersion: '2024-03-09',
    activeTranscriptSnapshotId: activeTranscriptSnapshotId,
    activeSummaryId: activeSummaryId,
  );
}

TranscriptSnapshot _snapshot({
  required String id,
  TranscriptSnapshotStatus status = TranscriptSnapshotStatus.complete,
  String modelId = paraformerStandardModelId,
  String modelVersion = '2024-03-09',
  String text = '最终事实文本',
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
              text: text,
              speakerId: speakerId,
              modelId: modelId,
              modelVersion: modelVersion,
            ),
          ]
        : const [],
  );
}

Summary _summary({required String id, required TranscriptSnapshot snapshot}) {
  final segment = snapshot.segments.single;
  return Summary(
    id: id,
    meetingId: snapshot.meetingId,
    transcriptSnapshotId: snapshot.id,
    provider: 'test-provider',
    model: 'test-model',
    createdAt: DateTime.utc(2026, 7, 25, 3),
    overview: '会议概览',
    keyPoints: [
      SummaryItem(
        id: '$id-key-point-1',
        text: '已确认结论',
        evidence: [
          SummaryEvidence(
            segmentId: segment.id,
            startMs: segment.startMs,
            endMs: segment.endMs,
            quote: segment.text,
          ),
        ],
      ),
    ],
    actionItems: [SummaryItem(id: '$id-action-item-1', text: '待核对行动项')],
    status: SummaryStatus.complete,
  );
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
  _DiarizationRunner({required this.result, this.available = true});

  SpeakerDiarizationResult result;
  final bool available;
  final List<(String?, String)> renameCalls = [];

  @override
  SpeakerDiarizationCapability get capability => available
      ? const SpeakerDiarizationCapability.available()
      : const SpeakerDiarizationCapability.unavailable(
          reasonCode: 'speaker_diarization.model_unavailable',
        );

  @override
  Future<SpeakerDiarizationResult> process({
    required String meetingId,
    required String snapshotId,
    required bool enabled,
  }) async {
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
