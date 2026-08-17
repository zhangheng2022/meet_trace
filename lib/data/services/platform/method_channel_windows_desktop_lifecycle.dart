import 'dart:async';

import 'package:flutter/services.dart';

import '../../../domain/ports/desktop_lifecycle.dart';

const windowsDesktopLifecycleChannelName =
    'com.meettrace.app/windows_desktop_lifecycle';

/// 只承载 Win32 窗口/托盘消息，不参与录音和会议业务判断。
final class MethodChannelWindowsDesktopLifecycle implements DesktopLifecycle {
  MethodChannelWindowsDesktopLifecycle({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(windowsDesktopLifecycleChannelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final StreamController<DesktopExitRequest> _exitRequests =
      StreamController<DesktopExitRequest>.broadcast(sync: true);
  final StreamController<DesktopSystemEvent> _systemEvents =
      StreamController<DesktopSystemEvent>.broadcast(sync: true);
  bool _disposed = false;

  @override
  Stream<DesktopExitRequest> get exitRequests => _exitRequests.stream;

  @override
  Stream<DesktopSystemEvent> get systemEvents => _systemEvents.stream;

  @override
  Future<void> setRecordingActive(bool active) =>
      _invokeBestEffort('setRecordingActive', active);

  @override
  Future<void> confirmExit() => _invokeBestEffort('confirmExit');

  @override
  Future<void> cancelExit({required String reason}) =>
      _invokeBestEffort('cancelExit', reason);

  Future<void> _handleNativeCall(MethodCall call) async {
    if (_disposed) {
      return;
    }
    if (call.method == 'stopAndExitRequested') {
      _exitRequests.add(DesktopExitRequest.stopRecordingAndExit);
      return;
    }
    final systemEvent = switch (call.method) {
      'systemSuspending' => DesktopSystemEvent.suspending,
      'systemResumed' => DesktopSystemEvent.resumed,
      'systemSessionEnding' => DesktopSystemEvent.sessionEnding,
      _ => null,
    };
    if (systemEvent != null) {
      _systemEvents.add(systemEvent);
    }
  }

  Future<void> _invokeBestEffort(String method, [Object? arguments]) async {
    if (_disposed) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on Object {
      // 非 Windows 测试壳、旧 runner 或窗口通道故障不得影响事实录音。
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _channel.setMethodCallHandler(null);
    await _exitRequests.close();
    await _systemEvents.close();
  }
}
