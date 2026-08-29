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

String displaySpeakerLabel(
  String? speakerId, {
  required String Function(int number) speakerLabelBuilder,
}) {
  if (speakerId == null || speakerId == 'speaker-1') {
    return speakerLabelBuilder(1);
  }
  final numeric = RegExp(r'^speaker-(\d+)$').firstMatch(speakerId);
  final number = numeric == null ? null : int.tryParse(numeric.group(1)!);
  if (number != null) {
    return speakerLabelBuilder(number);
  }
  return speakerId;
}
