import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windows 单实例与托盘录音守卫', () {
    test('重复启动通过命名对象唤醒已有窗口', () async {
      final main = await File('windows/runner/main.cpp').readAsString();

      expect(main, contains('MeetTrace.SingleInstance.1'));
      expect(main, contains('MeetTrace.ActivateExisting.1'));
      expect(main, contains('ERROR_ALREADY_EXISTS'));
      expect(main, contains('SetEvent(activation_event)'));
      expect(main, contains('window.ActivateExistingInstance()'));
      expect(main, contains('MsgWaitForMultipleObjects'));
    });

    test('录音 close 只进入托盘且托盘退出先请求 Dart 封存', () async {
      final window = await File('windows/runner/flutter_window.cpp')
          .readAsString();
      final requestStart = window.indexOf(
        'void FlutterWindow::RequestStopAndExit()',
      );
      final requestEnd = window.indexOf('\n}', requestStart);
      final requestBody = window.substring(requestStart, requestEnd);

      expect(window, contains('case WM_CLOSE:'));
      expect(window, contains('if (recording_active_)'));
      expect(window, contains('HideRecordingToTray()'));
      expect(window, contains('if (AddTrayIcon(true))'));
      expect(window, contains('Shell_NotifyIcon'));
      expect(window, contains('NIF_INFO'));
      expect(window, contains('RegisterWindowMessage(L"TaskbarCreated")'));
      expect(window, contains('stopAndExitRequested'));
      expect(window, contains('case kConfirmExitMessage:'));
      expect(requestBody, isNot(contains('DestroyWindow')));
    });

    test('Dart 与 Win32 使用同一通道且窗口保持最小内容尺寸', () async {
      final dart = await File(
        'lib/data/services/platform/'
        'method_channel_windows_desktop_lifecycle.dart',
      ).readAsString();
      final window = await File('windows/runner/flutter_window.cpp')
          .readAsString();
      final main = await File('windows/runner/main.cpp').readAsString();

      const channel = 'com.meettrace.app/windows_desktop_lifecycle';
      expect(dart, contains(channel));
      expect(window, contains(channel));
      expect(main, contains('SetMinimumSize(Win32Window::Size(840, 640))'));
    });

    test('系统挂起、恢复和会话结束只通过生命周期通道通知 Dart', () async {
      final window = await File('windows/runner/flutter_window.cpp')
          .readAsString();

      expect(window, contains('case WM_POWERBROADCAST:'));
      expect(window, contains('PBT_APMSUSPEND'));
      expect(window, contains('PBT_APMRESUMEAUTOMATIC'));
      expect(window, contains('PBT_APMRESUMESUSPEND'));
      expect(window, contains('NotifyDart("systemSuspending")'));
      expect(window, contains('NotifyDart("systemResumed")'));
      expect(window, contains('case WM_QUERYENDSESSION:'));
      expect(window, contains('NotifyDart("systemSessionEnding")'));
    });
  });
}
