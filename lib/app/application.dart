import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/domain/models/app_theme.dart';
import 'package:meettrace/theme/theme.dart';
import 'package:meettrace/ui/features/meetings/views/list/meeting_list_view.dart';

const appDisplayName = '会迹';

/// 会迹（MeetTrace）的应用外壳。
///
/// 这里仅负责主题、本地化和根页面组装，不承载业务逻辑。
class Application extends StatelessWidget {
  const Application({
    super.key,
    this.home,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.themeMode,
  });

  /// 测试或后续路由层可以替换根页面。
  final Widget? home;
  final List<NavigatorObserver> navigatorObservers;
  final ValueListenable<AppThemeMode>? themeMode;

  @override
  Widget build(BuildContext context) {
    final listenable = themeMode;
    if (listenable == null) {
      return _buildApplication(AppThemeMode.system);
    }
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: listenable,
      builder: (context, mode, _) => _buildApplication(mode),
    );
  }

  Widget _buildApplication(AppThemeMode mode) => MaterialApp(
    title: appDisplayName,
    debugShowCheckedModeBanner: false,
    navigatorObservers: navigatorObservers,
    supportedLocales: FLocalizations.supportedLocales,
    localizationsDelegates: const [...FLocalizations.localizationsDelegates],
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
