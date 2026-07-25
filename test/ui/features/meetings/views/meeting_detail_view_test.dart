import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/app/application.dart';
import 'package:meetily_ai/data/services/asr/final_transcription_service.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
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

    await tester.tap(find.text('高级模型（Qwen3-ASR）'));
    await tester.pump();
    await tester.tap(find.text('使用所选模型重新转录'));
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
}

_Fixture _fixture(
  Meeting meeting, {
  TranscriptSnapshot? active,
  bool installQwen = false,
}) {
  final meetings = DetailMeetingRepository(meeting);
  final transcripts = DetailTranscriptRepository();
  if (active != null) {
    transcripts.records[active.id] = active;
  }
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
    viewModel: MeetingDetailViewModel(
      meeting: meeting,
      meetings: meetings,
      transcripts: transcripts,
      installations: installations,
      transcription: runner,
    ),
  );
}

final class _Fixture {
  const _Fixture({
    required this.meetings,
    required this.transcripts,
    required this.installations,
    required this.runner,
    required this.viewModel,
  });

  final DetailMeetingRepository meetings;
  final DetailTranscriptRepository transcripts;
  final TestActiveInstallations installations;
  final DetailTranscriptionRunner runner;
  final MeetingDetailViewModel viewModel;

  Future<void> dispose() async {
    viewModel.dispose();
    await installations.dispose();
  }
}

Meeting _meeting({
  MeetingState status = MeetingState.processing,
  String? activeTranscriptSnapshotId,
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
  );
}

TranscriptSnapshot _snapshot({
  required String id,
  TranscriptSnapshotStatus status = TranscriptSnapshotStatus.complete,
  String modelId = paraformerStandardModelId,
  String modelVersion = '2024-03-09',
  String text = '最终事实文本',
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
              modelId: modelId,
              modelVersion: modelVersion,
            ),
          ]
        : const [],
  );
}
