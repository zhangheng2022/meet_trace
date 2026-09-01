/// 录音期间暂停高开销遥测的领域边界。
abstract interface class RecordingTelemetryGate {
  bool get recordingActive;

  void setRecordingActive(bool active);

  void observePcmWrite({required Duration latency, required int pendingChunks});

  void observePreview({
    required int queuedAudioMs,
    required int droppedWindows,
  });

  void recordInterruption();

  void recordRecovery();
}

final class NoopRecordingTelemetryGate implements RecordingTelemetryGate {
  const NoopRecordingTelemetryGate();

  @override
  bool get recordingActive => false;

  @override
  void setRecordingActive(bool active) {}

  @override
  void observePcmWrite({
    required Duration latency,
    required int pendingChunks,
  }) {}

  @override
  void observePreview({
    required int queuedAudioMs,
    required int droppedWindows,
  }) {}

  @override
  void recordInterruption() {}

  @override
  void recordRecovery() {}
}
