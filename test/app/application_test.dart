import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/app_language.dart';
import 'package:meettrace/domain/models/app_theme.dart';
import 'package:meettrace/l10n/l10n.dart';
import 'package:meettrace/ui/features/meetings/views/list/meeting_list_view.dart';

void main() {
  testWidgets('使用真实主题显示会议列表首页', (WidgetTester tester) async {
    await tester.pumpWidget(const Application());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      '会迹 MeetTrace',
    );
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

  testWidgets('语言即时切换且不重建会议页面状态', (tester) async {
    final languageMode = ValueNotifier(AppLanguageMode.english);
    addTearDown(languageMode.dispose);
    _LocaleProbeState.initializations = 0;

    await tester.pumpWidget(
      Application(languageMode: languageMode, home: const _LocaleProbe()),
    );
    expect(find.text('Settings'), findsOneWidget);
    expect(_LocaleProbeState.initializations, 1);

    languageMode.value = AppLanguageMode.simplifiedChinese;
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(_LocaleProbeState.initializations, 1);
  });

  test('系统语言仅将中文解析为简体中文，其余回退英文', () {
    expect(resolveAppLocale(const Locale('zh')), const Locale('zh'));
    expect(resolveAppLocale(const Locale('zh', 'TW')), const Locale('zh'));
    expect(resolveAppLocale(const Locale('zh', 'HK')), const Locale('zh'));
    expect(
      resolveAppLocale(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      const Locale('zh'),
    );
    expect(resolveAppLocale(const Locale('fr', 'FR')), const Locale('en'));
    expect(resolveAppLocale(null), const Locale('en'));
  });
}

class _LocaleProbe extends StatefulWidget {
  const _LocaleProbe();

  @override
  State<_LocaleProbe> createState() => _LocaleProbeState();
}

class _LocaleProbeState extends State<_LocaleProbe> {
  static int initializations = 0;

  @override
  void initState() {
    super.initState();
    initializations += 1;
  }

  @override
  Widget build(BuildContext context) => Text(context.l10n.settingsTitle);
}
