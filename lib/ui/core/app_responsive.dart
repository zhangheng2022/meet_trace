import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';

/// 会迹 · MeetTrace 的内容驱动窗口尺寸类。
enum AppWindowSizeClass {
  compact,
  medium,
  expanded;

  static AppWindowSizeClass fromWidth(double width, AppStyle style) {
    if (width >= style.wideLayoutMinWidth) {
      return expanded;
    }
    if (width >= style.mediumLayoutMinWidth) {
      return medium;
    }
    return compact;
  }
}

typedef AppResponsiveWidgetBuilder =
    Widget Function(
      BuildContext context,
      AppWindowSizeClass sizeClass,
      BoxConstraints constraints,
    );

/// 只根据父布局约束选择布局，不读取设备型号、方向或平台字符串。
final class AppResponsiveBuilder extends StatelessWidget {
  const AppResponsiveBuilder({required this.builder, super.key});

  final AppResponsiveWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return LayoutBuilder(
      builder: (context, constraints) => builder(
        context,
        AppWindowSizeClass.fromWidth(constraints.maxWidth, appStyle),
        constraints,
      ),
    );
  }
}
