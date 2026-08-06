/// 录音期间暂停高开销遥测的领域边界。
abstract interface class RecordingTelemetryGate {
  bool get recordingActive;

  void setRecordingActive(bool active);
}

final class NoopRecordingTelemetryGate implements RecordingTelemetryGate {
  const NoopRecordingTelemetryGate();

  @override
  bool get recordingActive => false;

  @override
  void setRecordingActive(bool active) {}
}
