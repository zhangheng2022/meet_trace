import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/app_theme.dart';
import 'package:meettrace/ui/features/meetings/views/list/meeting_list_view.dart';

void main() {
  testWidgets('使用真实主题显示会议列表首页', (WidgetTester tester) async {
    await tester.pumpWidget(const Application());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, '会迹');
    expect(find.byType(FTheme), findsOneWidget);
    expect(find.byType(MeetingListView), findsOneWidget);
    expect(find.text('会迹'), findsNothing);
    expect(find.byType(FButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('主题模式在整个应用即时切换并支持跟随系统', (tester) async {
    final themeMode = ValueNotifier(AppThemeMode.dark);
    addTearDown(themeMode.dispose);
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    await tester.pumpWidget(
      Application(themeMode: themeMode, home: const SizedBox.shrink()),
    );
    expect(
      tester.widget<FTheme>(find.byType(FTheme)).data.colors.brightness,
      Brightness.dark,
    );

    themeMode.value = AppThemeMode.light;
    await tester.pumpAndSettle();
    expect(
      tester.widget<FTheme>(find.byType(FTheme)).data.colors.brightness,
      Brightness.light,
    );

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    themeMode.value = AppThemeMode.system;
    await tester.pumpAndSettle();
    expect(
      tester.widget<FTheme>(find.byType(FTheme)).data.colors.brightness,
      Brightness.light,
    );

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      tester.widget<FTheme>(find.byType(FTheme)).data.colors.brightness,
      Brightness.dark,
    );
  });
}
