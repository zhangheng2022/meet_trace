import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';

/// 为应用内 Forui Sheet 提供一致的实色背景、圆角与安全区。
final class AppSheetSurface extends StatelessWidget {
  const AppSheetSurface({
    required this.title,
    required this.semanticsLabel,
    required this.child,
    this.description,
    this.compact = false,
    this.footer,
    this.surfaceKey,
    super.key,
  });

  final String title;
  final String? description;
  final String semanticsLabel;
  final Widget child;
  final bool compact;
  final Widget? footer;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          key: surfaceKey,
          decoration: BoxDecoration(
            color: theme.colors.card,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(appStyle.panelRadius),
              topRight: Radius.circular(appStyle.panelRadius),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  appStyle.spaceMd,
                  compact ? appStyle.spaceMd : appStyle.spaceLg,
                  appStyle.spaceMd,
                  compact ? appStyle.spaceMd : appStyle.spaceLg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: theme.typography.display.lg),
                    if (description case final description?) ...[
                      SizedBox(height: appStyle.spaceSm),
                      Text(
                        description,
                        style: theme.typography.body.sm.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                    SizedBox(
                      height: compact ? appStyle.spaceSm : appStyle.spaceLg,
                    ),
                    child,
                    if (footer != null) ...[
                      SizedBox(
                        height: compact ? appStyle.spaceMd : appStyle.spaceLg,
                      ),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
