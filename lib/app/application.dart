import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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
  });

  /// 测试或后续路由层可以替换根页面。
  final Widget? home;
  final List<NavigatorObserver> navigatorObservers;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appDisplayName,
    debugShowCheckedModeBanner: false,
    navigatorObservers: navigatorObservers,
    supportedLocales: FLocalizations.supportedLocales,
    localizationsDelegates: const [...FLocalizations.localizationsDelegates],
    theme: lightTheme.toApproximateMaterialTheme(),
    darkTheme: darkTheme.toApproximateMaterialTheme(),
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
