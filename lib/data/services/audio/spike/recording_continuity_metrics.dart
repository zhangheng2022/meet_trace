final class RecordingContinuityMetrics {
  const RecordingContinuityMetrics({
    required this.bytesWritten,
    required this.elapsed,
    required this.sampleRate,
    required this.channelCount,
  });

  static const _bytesPerPcm16Sample = 2;
  static const _minimumCompleteRatio = 0.98;

  final int bytesWritten;
  final Duration elapsed;
  final int sampleRate;
  final int channelCount;

  int get expectedBytes {
    final bytesPerSecond = sampleRate * channelCount * _bytesPerPcm16Sample;
    return (bytesPerSecond * elapsed.inMicroseconds) ~/
        Duration.microsecondsPerSecond;
  }

  double get completenessRatio {
    if (expectedBytes == 0) {
      return 0;
    }
    return bytesWritten / expectedBytes;
  }

  bool get isComplete => completenessRatio >= _minimumCompleteRatio;

  Map<String, Object> toJson() => {
    'bytesWritten': bytesWritten,
    'expectedBytes': expectedBytes,
    'elapsedMs': elapsed.inMilliseconds,
    'sampleRate': sampleRate,
    'channelCount': channelCount,
    'completenessRatio': completenessRatio,
    'isComplete': isComplete,
  };
}
