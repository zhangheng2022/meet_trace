/// 录音会话对系统睡眠、恢复与系统退出的纯 Dart 响应契约。
///
/// 平台外壳只上报事实事件；写盘检查点、输入重连和缺口记录均由录音实现负责。
abstract interface class RecordingSystemLifecycle {
  Future<void> handleSystemSuspending();

  Future<void> handleSystemResumed();

  Future<void> prepareForSystemExit();
}

final class NoopRecordingSystemLifecycle implements RecordingSystemLifecycle {
  const NoopRecordingSystemLifecycle();

  @override
  Future<void> handleSystemSuspending() async {}

  @override
  Future<void> handleSystemResumed() async {}

  @override
  Future<void> prepareForSystemExit() async {}
}
