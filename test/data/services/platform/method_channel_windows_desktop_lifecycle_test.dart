import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/platform/method_channel_windows_desktop_lifecycle.dart';
import 'package:meettrace/domain/ports/desktop_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(windowsDesktopLifecycleChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('向 Win32 同步录音状态并确认或取消退出', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    final lifecycle = MethodChannelWindowsDesktopLifecycle(channel: channel);

    await lifecycle.setRecordingActive(true);
    await lifecycle.cancelExit(reason: '尚未封存');
    await lifecycle.confirmExit();

    expect(calls.map((call) => call.method), [
      'setRecordingActive',
      'cancelExit',
      'confirmExit',
    ]);
    expect(calls[0].arguments, isTrue);
    expect(calls[1].arguments, '尚未封存');
    await lifecycle.dispose();
  });

  test('把原生停止并退出请求发布为领域事件', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final lifecycle = MethodChannelWindowsDesktopLifecycle(channel: channel);
    final received = <DesktopExitRequest>[];
    final subscription = lifecycle.exitRequests.listen(received.add);

    await _sendNativeMethod(messenger, 'stopAndExitRequested');

    expect(received, [DesktopExitRequest.stopRecordingAndExit]);
    await subscription.cancel();
    await lifecycle.dispose();
  });

  test('把原生睡眠、恢复和会话结束消息映射为有序领域事件', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final lifecycle = MethodChannelWindowsDesktopLifecycle(channel: channel);
    final received = <DesktopSystemEvent>[];
    final subscription = lifecycle.systemEvents.listen(received.add);

    await _sendNativeMethod(messenger, 'systemSuspending');
    await _sendNativeMethod(messenger, 'systemResumed');
    await _sendNativeMethod(messenger, 'systemSessionEnding');

    expect(received, [
      DesktopSystemEvent.suspending,
      DesktopSystemEvent.resumed,
      DesktopSystemEvent.sessionEnding,
    ]);
    await subscription.cancel();
    await lifecycle.dispose();
  });

  test('非平台类型的窗口通道故障也不向事实录音链抛出异常', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) => throw StateError('window unavailable'),
    );
    final lifecycle = MethodChannelWindowsDesktopLifecycle(channel: channel);

    await expectLater(lifecycle.setRecordingActive(true), completes);
    await expectLater(lifecycle.confirmExit(), completes);

    await lifecycle.dispose();
  });
}

Future<void> _sendNativeMethod(
  TestDefaultBinaryMessenger messenger,
  String method,
) async {
  final response = Completer<ByteData?>();
  await messenger.handlePlatformMessage(
    windowsDesktopLifecycleChannelName,
    const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
    response.complete,
  );
  await response.future;
}
