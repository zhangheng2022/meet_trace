import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/models/transcript.dart';
import '../../../../../domain/ports/audio_playback.dart';

final class MeetingDetailState {
  const MeetingDetailState({
    required this.meeting,
    required this.snapshot,
    required this.isLoading,
    required this.isProcessing,
    required this.progress,
    required this.errorMessage,
    required this.resultMessage,
    required this.diarizationMessage,
    required this.playbackState,
  });
  final Meeting meeting;
  final TranscriptSnapshot? snapshot;
  final bool isLoading;
  final bool isProcessing;
  final double progress;
  final String? errorMessage;
  final String? resultMessage;
  final String? diarizationMessage;
  final AudioPlaybackState playbackState;
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
