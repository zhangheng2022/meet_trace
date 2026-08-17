enum DesktopExitRequest { stopRecordingAndExit }

enum DesktopSystemEvent { suspending, resumed, sessionEnding }

/// 桌面窗口生命周期的纯 Dart 契约。
///
/// 原生窗口负责决定 close 是退出还是进入托盘；录音会话只通过此端口同步
/// “是否必须保护事实音频”，并在托盘请求退出时完成安全封存。
abstract interface class DesktopLifecycle {
  Stream<DesktopExitRequest> get exitRequests;

  Stream<DesktopSystemEvent> get systemEvents;

  Future<void> setRecordingActive(bool active);

  Future<void> confirmExit();

  Future<void> cancelExit({required String reason});

  Future<void> dispose();
}

final class NoopDesktopLifecycle implements DesktopLifecycle {
  const NoopDesktopLifecycle();

  @override
  Stream<DesktopExitRequest> get exitRequests =>
      const Stream<DesktopExitRequest>.empty();

  @override
  Stream<DesktopSystemEvent> get systemEvents =>
      const Stream<DesktopSystemEvent>.empty();

  @override
  Future<void> setRecordingActive(bool active) async {}

  @override
  Future<void> confirmExit() async {}

  @override
  Future<void> cancelExit({required String reason}) async {}

  @override
  Future<void> dispose() async {}
}
