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
