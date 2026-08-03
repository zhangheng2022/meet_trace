// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · previews: UI-04 meeting result · macrostructure: Workbench

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../app/application.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/model_installation.dart';
import '../../../../domain/models/summary.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../domain/ports/final_transcription.dart';
import '../../../../domain/ports/repositories.dart';
import '../view_models/detail/meeting_detail_view_model.dart';
import '../views/detail/meeting_detail_view.dart';

part 'support/meeting_detail_preview_fixture.dart';

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
  requestedModelId: senseVoiceDefaultModelId,
  recordingModelId: senseVoiceDefaultModelId,
  recordingModelVersion: AsrModelRegistry.alpha.defaultModel.version,
  activeTranscriptSnapshotId: activeTranscriptSnapshotId,
  activeSummaryId: activeSummaryId,
);

TranscriptSnapshot _previewSnapshot() => TranscriptSnapshot(
  id: 'preview-snapshot',
  meetingId: 'preview-result',
  kind: TranscriptSnapshotKind.finalTranscript,
  actualModelId: senseVoiceDefaultModelId,
  actualModelVersion: AsrModelRegistry.alpha.defaultModel.version,
  createdAt: DateTime(2026, 7, 26, 9, 43),
  status: TranscriptSnapshotStatus.complete,
  segments: [
    TranscriptSegment(
      id: 'preview-segment-1',
      snapshotId: 'preview-snapshot',
      startMs: 125000,
      endMs: 137000,
      text: '本周先完成 Android + iOS Alpha 的会议结果页和端侧回归。',
      speakerId: '陈工',
      modelId: senseVoiceDefaultModelId,
      modelVersion: AsrModelRegistry.alpha.defaultModel.version,
    ),
    TranscriptSegment(
      id: 'preview-segment-2',
      snapshotId: 'preview-snapshot',
      startMs: 181000,
      endMs: 196000,
      text: 'SenseVoice 与 VAD 均在首次初始化时按需下载，不进入安装包。',
      speakerId: '林同学',
      modelId: senseVoiceDefaultModelId,
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
  overview: '会议确认了 Alpha 结果页与 SenseVoice 交付顺序。',
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
    SummaryItem(id: 'preview-action', text: '完成 Android + iOS Alpha 结果页回归。'),
  ],
  status: SummaryStatus.complete,
);
