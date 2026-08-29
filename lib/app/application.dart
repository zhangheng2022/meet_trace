import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/domain/models/app_theme.dart';
import 'package:meettrace/domain/models/app_language.dart';
import 'package:meettrace/l10n/l10n.dart';
import 'package:meettrace/theme/theme.dart';
import 'package:meettrace/ui/features/meetings/views/list/meeting_list_view.dart';

const appDisplayName = '会迹 MeetTrace';

/// 会迹（MeetTrace）的应用外壳。
///
/// 这里仅负责主题、本地化和根页面组装，不承载业务逻辑。
class Application extends StatelessWidget {
  const Application({
    super.key,
    this.home,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.themeMode,
    this.languageMode,
  });

  /// 测试或后续路由层可以替换根页面。
  final Widget? home;
  final List<NavigatorObserver> navigatorObservers;
  final ValueListenable<AppThemeMode>? themeMode;
  final ValueListenable<AppLanguageMode>? languageMode;

  @override
  Widget build(BuildContext context) {
    final themeListenable = themeMode;
    if (themeListenable == null) {
      return _buildWithLanguage(AppThemeMode.system);
    }
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: themeListenable,
      builder: (context, theme, _) => _buildWithLanguage(theme),
    );
  }

  Widget _buildWithLanguage(AppThemeMode theme) {
    final languageListenable = languageMode;
    if (languageListenable == null) {
      // Tests and previews omit runtime preferences; keep their established locale.
      return _buildApplication(theme, AppLanguageMode.simplifiedChinese);
    }
    return ValueListenableBuilder<AppLanguageMode>(
      valueListenable: languageListenable,
      builder: (context, language, _) => _buildApplication(theme, language),
    );
  }

  Widget _buildApplication(AppThemeMode mode, AppLanguageMode language) =>
      MaterialApp(
        title: appDisplayName,
        debugShowCheckedModeBanner: false,
        navigatorObservers: navigatorObservers,
        locale: language.locale,
        localeResolutionCallback: (locale, _) => resolveAppLocale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...FLocalizations.localizationsDelegates,
        ],
        theme: lightTheme.toApproximateMaterialTheme(),
        darkTheme: darkTheme.toApproximateMaterialTheme(),
        themeMode: switch (mode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        builder: (context, child) => FTheme(
          data: Theme.brightnessOf(context) == Brightness.light
              ? lightTheme
              : darkTheme,
          child: FToaster(
            child: FTooltipGroup(child: child ?? const SizedBox.shrink()),
          ),
        ),
        // 测试保留轻量默认首页；生产入口注入完整 MeetTraceBootstrap。
        home: home ?? const MeetingListView(),
      );
}
