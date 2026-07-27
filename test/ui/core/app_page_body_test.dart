import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/app/application.dart';
import 'package:meetily_ai/ui/core/app_page_body.dart';

void main() {
  for (final width in [320.0, 375.0, 414.0, 768.0, 1024.0]) {
    testWidgets('$width 宽度不产生横向溢出并保留页面留白', (WidgetTester tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const Application(
          home: AppPageBody(
            width: AppPageWidth.wide,
            child: SizedBox.expand(key: ValueKey('content')),
          ),
        ),
      );

      final content = tester.getRect(find.byKey(const ValueKey('content')));
      expect(content.left, greaterThanOrEqualTo(16));
      expect(content.right, lessThanOrEqualTo(width - 16));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wide 内容在超宽窗口限制为 1200', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const Application(
        home: AppPageBody(
          width: AppPageWidth.wide,
          child: SizedBox.expand(key: ValueKey('content')),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, 1200);
  });
}
