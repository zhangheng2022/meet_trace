import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/core/app_bottom_action_bar.dart';

void main() {
  testWidgets('底部关键操作遵守安全区并响应点击', (WidgetTester tester) async {
    var pressed = false;

    await tester.pumpWidget(
      Application(
        home: FScaffold(
          childPad: false,
          footer: AppBottomActionBar(
            supportingText: '开始后本场模型锁定；实时转录变慢不会中断本机录音。',
            child: FButton(
              onPress: () => pressed = true,
              child: const Text('开始录音'),
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.text('开始录音'), findsOneWidget);
    expect(find.textContaining('实时转录变慢不会中断'), findsOneWidget);
    await tester.tap(find.text('开始录音'));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
  });

  testWidgets('320 宽度和 2.0 字体缩放下页脚不会占满页面或溢出', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      Application(
        home: FScaffold(
          childPad: false,
          footer: AppBottomActionBar(
            supportingText: '正在检查权限、存储空间和模型；尚未开始录音。',
            child: FButton(
              onPress: () {},
              child: const Text('正在准备录音', maxLines: 1),
            ),
          ),
          child: const Center(child: Text('页面内容仍然可见')),
        ),
      ),
    );

    expect(find.text('页面内容仍然可见').hitTestable(), findsOneWidget);
    expect(find.text('正在准备录音'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
