import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/theme/system_ui.dart';

void main() {
  test('浅色与深色主题使用透明状态栏和对应图标亮度', () {
    final light = appSystemUiOverlayStyle(Brightness.light);
    final dark = appSystemUiOverlayStyle(Brightness.dark);

    expect(light.statusBarColor, const Color(0x00000000));
    expect(light.statusBarIconBrightness, Brightness.dark);
    expect(light.statusBarBrightness, Brightness.light);
    expect(light.systemStatusBarContrastEnforced, isFalse);

    expect(dark.statusBarColor, const Color(0x00000000));
    expect(dark.statusBarIconBrightness, Brightness.light);
    expect(dark.statusBarBrightness, Brightness.dark);
    expect(dark.systemStatusBarContrastEnforced, isFalse);
  });

  testWidgets('应用启动时显式启用 edge-to-edge 系统界面', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await enableAppEdgeToEdge();

    expect(
      calls,
      contains(
        isA<MethodCall>()
            .having(
              (call) => call.method,
              'method',
              'SystemChrome.setEnabledSystemUIMode',
            )
            .having(
              (call) => call.arguments,
              'arguments',
              'SystemUiMode.edgeToEdge',
            ),
      ),
    );
  });
}
