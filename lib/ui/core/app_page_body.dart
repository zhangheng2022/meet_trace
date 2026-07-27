// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V4
// Hallmark · component: page-body · genre: modern-minimal · theme: Cobalt
// Responsive: compact · medium · expanded · contrast: inherited from FTheme

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';

/// 页面内容的最大宽度角色。
enum AppPageWidth { compact, reading, wide }

/// 统一页面安全区、水平留白和内容宽度。
///
/// 子组件仍负责选择自身是否滚动，避免页面骨架与列表、表单的滚动行为耦合。
final class AppPageBody extends StatelessWidget {
  const AppPageBody({
    required this.child,
    this.width = AppPageWidth.compact,
    this.padding,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final AppPageWidth width;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    final maxWidth = switch (width) {
      AppPageWidth.compact => appStyle.contentMaxWidth,
      AppPageWidth.reading => appStyle.readingContentMaxWidth,
      AppPageWidth.wide => appStyle.wideContentMaxWidth,
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: padding ?? EdgeInsets.all(appStyle.spaceMd),
        child: Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }
}
