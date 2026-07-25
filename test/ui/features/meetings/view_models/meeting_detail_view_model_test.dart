import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/asr/final_transcription_service.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:meetily_ai/ui/features/meetings/view_models/meeting_detail_view_model.dart';

import '../../../../support/final_transcription_fakes.dart';
import '../../../../support/model_selection_fakes.dart';

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
    expect(retry.modelId, paraformerStandardModelId);
    expect(retry.modelVersion, '2024-03-09');
    expect(
      fixture.viewModel.snapshot?.status,
      TranscriptSnapshotStatus.complete,
    );
    await fixture.dispose();
  });

  test('完成后可选择当前已安装高级模型生成独立重转录', () async {
    final active = _snapshot(id: 'old');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
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

    fixture.viewModel.selectModel(qwenAdvancedModelId);
    await fixture.viewModel.retranscribe();

    expect(fixture.runner.calls.single.modelId, qwenAdvancedModelId);
    expect(fixture.runner.calls.single.retrySnapshotId, isNull);
    expect(fixture.viewModel.snapshot?.id, 'qwen-new');
    await fixture.dispose();
  });

  test('恢复 processing 快照时复用原 ID 和来源模型而不改回锁定模型', () async {
    final pending = _snapshot(
      id: 'qwen-pending',
      status: TranscriptSnapshotStatus.processing,
      modelId: qwenAdvancedModelId,
      modelVersion: '2026-03-25',
    );
    final fixture = _fixture(_meeting(), installQwen: true);
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
            modelId: qwenAdvancedModelId,
            modelVersion: '2026-03-25',
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
    expect(resumed.modelId, qwenAdvancedModelId);
    expect(resumed.modelVersion, '2026-03-25');
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
              modelId: modelId,
              modelVersion: modelVersion,
            ),
          ]
        : const [],
  );
}
