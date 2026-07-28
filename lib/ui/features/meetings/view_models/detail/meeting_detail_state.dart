part of 'meeting_detail_view_model.dart';

final class MeetingDetailState {
  const MeetingDetailState({
    required this.meeting,
    required this.snapshot,
    required this.summary,
    required this.isLoading,
    required this.isProcessing,
    required this.progress,
    required this.errorMessage,
    required this.resultMessage,
    required this.summaryMessage,
    required this.diarizationMessage,
    required this.playbackState,
  });
  final Meeting meeting;
  final TranscriptSnapshot? snapshot;
  final Summary? summary;
  final bool isLoading;
  final bool isProcessing;
  final double progress;
  final String? errorMessage;
  final String? resultMessage;
  final String? summaryMessage;
  final String? diarizationMessage;
  final EvidencePlaybackState playbackState;
}

final class SpeakerLabelGroup {
  const SpeakerLabelGroup({
    required this.speakerId,
    required this.displayLabel,
    required this.segmentCount,
  });

  final String? speakerId;
  final String displayLabel;
  final int segmentCount;
}

String displaySpeakerLabel(String? speakerId) {
  if (speakerId == null || speakerId == 'speaker-1') {
    return '说话人 1';
  }
  final numeric = RegExp(r'^speaker-(\d+)$').firstMatch(speakerId);
  if (numeric != null) {
    return '说话人 ${numeric.group(1)}';
  }
  return speakerId;
}
