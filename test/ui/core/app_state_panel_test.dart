import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/core/app_state_panel.dart';

void main() {
  testWidgets('加载状态提供明确语义且不显示操作', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Application(home: AppStatePanel.loading(label: '正在加载会议')),
    );

    expect(find.byType(FProgress), findsOneWidget);
    expect(
      tester.widget<FProgress>(find.byType(FProgress)).semanticsLabel,
      '正在加载会议',
    );
    expect(find.byType(FButton), findsNothing);
  });

  testWidgets('空白状态显示单一下一步并响应点击', (WidgetTester tester) async {
    var started = false;
    await tester.pumpWidget(
      Application(
        home: AppStatePanel.empty(
          icon: FLucideIcons.calendar,
          title: '还没有会议',
          message: '开始录音后，会议会安全地保存在这台设备上。',
          actionLabel: '开始会议',
          onAction: () => started = true,
        ),
      ),
    );

    expect(find.text('还没有会议'), findsOneWidget);
    expect(find.text('开始会议'), findsOneWidget);
    await tester.tap(find.text('开始会议'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(started, isTrue);
  });

  testWidgets('无回调时不渲染无法解释的禁用按钮', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Application(
        home: AppStatePanel.empty(
          icon: FLucideIcons.calendar,
          title: '还没有会议',
          message: '开始录音后，会议会安全地保存在这台设备上。',
        ),
      ),
    );

    expect(find.byType(FButton), findsNothing);
  });

  testWidgets('错误状态在 320 宽度和 2.0 字体缩放下无溢出', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      Application(
        home: AppStatePanel.error(
          title: '会议加载失败',
          message: '本地数据仍保留在设备上，请重试。',
          actionLabel: '重试加载',
          onAction: () {},
        ),
      ),
    );

    expect(find.text('会议加载失败'), findsOneWidget);
    expect(find.text('重试加载'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
