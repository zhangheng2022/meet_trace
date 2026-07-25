import 'transcript.dart';

final class SpeakerDiarizationCapability {
  const SpeakerDiarizationCapability.available()
    : isAvailable = true,
      reasonCode = null;

  const SpeakerDiarizationCapability.unavailable({required this.reasonCode})
    : isAvailable = false;

  final bool isAvailable;
  final String? reasonCode;
}

final class SpeakerTurn {
  const SpeakerTurn({
    required this.startMs,
    required this.endMs,
    required this.speakerId,
  }) : assert(startMs >= 0),
       assert(endMs > startMs),
       assert(speakerId != '');

  final int startMs;
  final int endMs;
  final String speakerId;
}

enum SpeakerDiarizationStatus { disabled, completed, degraded }

final class SpeakerDiarizationResult {
  const SpeakerDiarizationResult({
    required this.snapshot,
    required this.status,
    this.errorCode,
  });

  final TranscriptSnapshot snapshot;
  final SpeakerDiarizationStatus status;
  final String? errorCode;
}

final class SpeakerDiarizationException implements Exception {
  const SpeakerDiarizationException(this.code);

  final String code;

  @override
  String toString() => 'SpeakerDiarizationException: $code';
}
