import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/theme/theme.dart';
import 'package:meettrace/ui/core/app_status_notice.dart';

void main() {
  for (final tone in AppStatusTone.values) {
    testWidgets('${tone.name} 同时显示图标和中文状态', (WidgetTester tester) async {
      await tester.pumpWidget(
        Application(
          home: AppStatusNotice(
            tone: tone,
            title: '状态标题',
            message: '事实音频仍然安全。',
          ),
        ),
      );

      expect(find.byType(FAlert), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
      expect(find.text('状态标题'), findsOneWidget);
      expect(find.text('事实音频仍然安全。'), findsOneWidget);
    });
  }

  testWidgets('深色主题使用深色语义令牌', (WidgetTester tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      const Application(
        home: AppStatusNotice(tone: AppStatusTone.success, title: '事实音频已保存'),
      ),
    );

    final context = tester.element(find.byType(AppStatusNotice));
    expect(context.theme.colors.brightness, Brightness.dark);
    expect(
      context.theme.colors.app.success.toARGB32(),
      const Color(0xFF4ADE80).toARGB32(),
    );
  });
}
