// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · previews: UI-04 meeting result · macrostructure: Workbench

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../app/application.dart';
import '../../../../data/repositories/repository_contracts.dart';
import '../../../../data/services/asr/final_transcription_service.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/model_installation.dart';
import '../../../../domain/models/summary.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/models/workflow_states.dart';
import '../view_models/meeting_detail_view_model.dart';
import 'meeting_detail_view.dart';

@Preview(name: '会议结果 · 375', group: 'UI-04 会议结果', size: Size(375, 760))
Widget meetingResultCompactPreview() => _resultPreview();

@Preview(name: '会议结果 · 1024', group: 'UI-04 会议结果', size: Size(1024, 760))
Widget meetingResultExpandedPreview() => _resultPreview();

@Preview(name: '最终处理中 · 375', group: 'UI-04 会议结果', size: Size(375, 760))
Widget meetingProcessingPreview() {
  final meeting = _previewMeeting(status: MeetingState.processing);
  return Application(
    home: MeetingDetailView(
      viewModel: MeetingDetailViewModel(
        meeting: meeting,
        meetings: _PreviewMeetingRepository(meeting),
        transcripts: _PreviewTranscriptRepository(),
        installations: const _PreviewInstallations(),
        transcription: const _PendingTranscriptionRunner(),
      ),
      onBack: () {},
    ),
  );
}

Widget _resultPreview() {
  final snapshot = _previewSnapshot();
  final summary = _previewSummary(snapshot);
  final meeting = _previewMeeting(
    status: MeetingState.completed,
    activeTranscriptSnapshotId: snapshot.id,
    activeSummaryId: summary.id,
  );
  return Application(
    home: MeetingDetailView(
      viewModel: MeetingDetailViewModel(
        meeting: meeting,
        meetings: _PreviewMeetingRepository(meeting),
        transcripts: _PreviewTranscriptRepository(snapshot),
        installations: const _PreviewInstallations(),
        transcription: const _UnavailableTranscriptionRunner(),
        summaries: _PreviewSummaryRepository(summary),
      ),
      onBack: () {},
    ),
  );
}

Meeting _previewMeeting({
  required MeetingState status,
  String? activeTranscriptSnapshotId,
  String? activeSummaryId,
}) => Meeting(
  id: 'preview-result',
  title: '产品 Alpha 评审',
  createdAt: DateTime(2026, 7, 26, 9),
  startedAt: DateTime(2026, 7, 26, 9),
  endedAt: DateTime(2026, 7, 26, 9, 42),
  status: status,
  audioPath: 'preview://alpha-review.pcm',
  audioDurationMs: 42 * 60 * 1000 + 8 * 1000,
  requestedModelId: paraformerStandardModelId,
  recordingModelId: paraformerStandardModelId,
  recordingModelVersion: AsrModelRegistry.alpha.defaultModel.version,
  activeTranscriptSnapshotId: activeTranscriptSnapshotId,
  activeSummaryId: activeSummaryId,
);

TranscriptSnapshot _previewSnapshot() => TranscriptSnapshot(
  id: 'preview-snapshot',
  meetingId: 'preview-result',
  kind: TranscriptSnapshotKind.finalTranscript,
  actualModelId: paraformerStandardModelId,
  actualModelVersion: AsrModelRegistry.alpha.defaultModel.version,
  createdAt: DateTime(2026, 7, 26, 9, 43),
  status: TranscriptSnapshotStatus.complete,
  segments: [
    TranscriptSegment(
      id: 'preview-segment-1',
      snapshotId: 'preview-snapshot',
      startMs: 125000,
      endMs: 137000,
      text: '本周先完成 Android Alpha 的会议结果页和端侧回归。',
      speakerId: '陈工',
      modelId: paraformerStandardModelId,
      modelVersion: AsrModelRegistry.alpha.defaultModel.version,
    ),
    TranscriptSegment(
      id: 'preview-segment-2',
      snapshotId: 'preview-snapshot',
      startMs: 181000,
      endMs: 196000,
      text: '高级模型继续按需下载，标准模型保持内置并作为默认选择。',
      speakerId: '林同学',
      modelId: paraformerStandardModelId,
      modelVersion: AsrModelRegistry.alpha.defaultModel.version,
    ),
  ],
);

Summary _previewSummary(TranscriptSnapshot snapshot) => Summary(
  id: 'preview-summary',
  meetingId: snapshot.meetingId,
  transcriptSnapshotId: snapshot.id,
  provider: 'preview',
  model: 'preview',
  createdAt: DateTime(2026, 7, 26, 9, 44),
  overview: '会议确认了 Alpha 结果页与双模型交付顺序。',
  keyPoints: [
    SummaryItem(
      id: 'preview-key-point',
      text: '先完成结果页与端侧回归。',
      evidence: [
        SummaryEvidence(
          segmentId: snapshot.segments.first.id,
          startMs: snapshot.segments.first.startMs,
          endMs: snapshot.segments.first.endMs,
          quote: snapshot.segments.first.text,
        ),
      ],
    ),
  ],
  actionItems: [
    SummaryItem(id: 'preview-action', text: '完成 Android Alpha 结果页回归。'),
  ],
  status: SummaryStatus.complete,
);

final class _PreviewMeetingRepository implements MeetingRepository {
  _PreviewMeetingRepository(this.meeting);

  Meeting? meeting;

  @override
  Future<void> delete(String meetingId) async {
    if (meeting?.id == meetingId) {
      meeting = null;
    }
  }

  @override
  Future<Meeting?> getById(String meetingId) async =>
      meeting?.id == meetingId ? meeting : null;

  @override
  Future<void> save(Meeting meeting) async {
    this.meeting = meeting;
  }

  @override
  Stream<List<Meeting>> watchAll() => Stream.value([?meeting]);
}

final class _PreviewTranscriptRepository implements TranscriptRepository {
  _PreviewTranscriptRepository([TranscriptSnapshot? snapshot])
    : _snapshot = snapshot;

  final TranscriptSnapshot? _snapshot;

  @override
  Future<TranscriptSnapshot?> getById(String snapshotId) async =>
      _snapshot?.id == snapshotId ? _snapshot : null;

  @override
  Future<List<TranscriptSnapshot>> listByMeeting(String meetingId) async {
    final snapshot = _snapshot;
    return snapshot?.meetingId == meetingId ? [snapshot!] : const [];
  }

  @override
  Future<void> save(TranscriptSnapshot snapshot) async {}

  @override
  Future<void> saveFinalAndActivate({
    required TranscriptSnapshot snapshot,
    required String? expectedActiveSnapshotId,
  }) async {}

  @override
  Future<TranscriptSnapshot> updateSpeakerLabels({
    required String snapshotId,
    required Map<String, String?> labelsBySegmentId,
  }) async => _snapshot!;
}

final class _PreviewSummaryRepository implements SummaryRepository {
  const _PreviewSummaryRepository(this.summary);

  final Summary summary;

  @override
  Future<Summary?> getById(String summaryId) async =>
      summary.id == summaryId ? summary : null;

  @override
  Future<List<Summary>> listByMeeting(String meetingId) async =>
      summary.meetingId == meetingId ? [summary] : const [];

  @override
  Future<void> save(Summary summary) async {}

  @override
  Future<void> saveAndActivate({
    required Summary summary,
    required String expectedTranscriptSnapshotId,
  }) async {}
}

final class _PreviewInstallations implements ModelInstallationRepository {
  const _PreviewInstallations();

  ModelInstallation get _standard => ModelInstallation(
    modelId: AsrModelRegistry.alpha.defaultModel.modelId,
    version: AsrModelRegistry.alpha.defaultModel.version,
    installationType: AsrInstallationType.bundled,
    state: ModelInstallationState.installed,
    installedPath: 'preview://standard-model',
    verifiedAt: DateTime(2026, 7, 26),
    bytes: 82 * 1024 * 1024,
  );

  @override
  Future<ModelInstallation?> get({
    required String modelId,
    required String version,
  }) async => modelId == _standard.modelId && version == _standard.version
      ? _standard
      : null;

  @override
  Future<void> save(ModelInstallation installation) async {}

  @override
  Stream<List<ModelInstallation>> watchAll() => Stream.value([_standard]);
}

final class _UnavailableTranscriptionRunner
    implements FinalTranscriptionRunner {
  const _UnavailableTranscriptionRunner();

  @override
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? modelId,
    String? modelVersion,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  }) => throw UnsupportedError('组件预览不运行最终转录');
}

final class _PendingTranscriptionRunner implements FinalTranscriptionRunner {
  const _PendingTranscriptionRunner();

  @override
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? modelId,
    String? modelVersion,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  }) => Completer<FinalTranscriptionResult>().future;
}
