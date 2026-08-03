enum RuntimeInitializationPhase {
  checking,
  awaitingMobileConsent,
  insufficientSpace,
  downloading,
  paused,
  verifying,
  activating,
  failed,
  ready,
}

final class RuntimeInitializationProgress {
  const RuntimeInitializationProgress({
    required this.phase,
    required this.completedBytes,
    required this.totalBytes,
    this.resourceName,
    this.message,
    this.shortageBytes,
  });

  final RuntimeInitializationPhase phase;
  final int completedBytes;
  final int totalBytes;
  final String? resourceName;
  final String? message;
  final int? shortageBytes;

  double get fraction => totalBytes <= 0
      ? 0
      : (completedBytes / totalBytes).clamp(0, 1).toDouble();
}

final class RuntimeInitializationException implements Exception {
  const RuntimeInitializationException({
    required this.code,
    required this.message,
    this.shortageBytes,
    this.cause,
  });

  final String code;
  final String message;
  final int? shortageBytes;
  final Object? cause;
}
