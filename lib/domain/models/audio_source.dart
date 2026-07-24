final class AudioSource {
  AudioSource({
    required this.path,
    required this.durationMs,
    this.sampleRate = 16000,
    this.channelCount = 1,
  }) {
    if (path.trim().isEmpty) {
      throw ArgumentError.value(path, 'path', '不能为空');
    }
    if (durationMs <= 0) {
      throw ArgumentError.value(durationMs, 'durationMs', '必须大于 0');
    }
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', '必须大于 0');
    }
    if (channelCount <= 0) {
      throw ArgumentError.value(channelCount, 'channelCount', '必须大于 0');
    }
  }

  final String path;
  final int durationMs;
  final int sampleRate;
  final int channelCount;
}
