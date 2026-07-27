// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · component: bottom-action-bar · genre: modern-minimal · theme: Cobalt
// Responsive: compact · medium · expanded · safe-area: enforced

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';
import 'app_page_body.dart';

/// 页面底部关键操作区。
///
/// 由 [FScaffold.footer] 承载，统一安全区、内容宽度与辅助说明；调用方负责提供
/// 具有明确动词的主操作控件。
final class AppBottomActionBar extends StatelessWidget {
  const AppBottomActionBar({
    required this.child,
    this.supportingText,
    this.width = AppPageWidth.compact,
    super.key,
  });

  final Widget child;
  final String? supportingText;
  final AppPageWidth width;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;

    final maxWidth = switch (width) {
      AppPageWidth.compact => appStyle.contentMaxWidth,
      AppPageWidth.reading => appStyle.readingContentMaxWidth,
      AppPageWidth.wide => appStyle.wideContentMaxWidth,
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          appStyle.spaceMd,
          appStyle.spaceSm,
          appStyle.spaceMd,
          appStyle.spaceMd,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (supportingText case final text?) ...[
                    Text(
                      text,
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                    SizedBox(height: appStyle.spaceSm),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
