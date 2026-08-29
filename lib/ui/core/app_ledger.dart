import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';

/// 事实账本的连续表面。相邻记录共享外边界，不形成悬浮卡片网格。
final class AppLedgerSurface extends StatelessWidget {
  const AppLedgerSurface({
    required this.children,
    this.framed = true,
    super.key,
  });

  final List<Widget> children;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    if (!framed) {
      return ColoredBox(
        color: theme.colors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(appStyle.cardRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.card,
          border: Border.all(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
          borderRadius: BorderRadius.circular(appStyle.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// 会议、转录与证据共用的时间记录条。
final class AppLedgerRow extends StatelessWidget {
  const AppLedgerRow({
    required this.timeLabel,
    required this.title,
    required this.statusLabel,
    required this.statusIcon,
    this.dateLabel,
    this.metaLabel,
    this.emphasized = false,
    this.selected = false,
    this.showDivider = true,
    this.onPress,
    this.semanticsLabel,
    this.semanticsHint,
    this.customSemanticsActions,
    super.key,
  });

  final String timeLabel;
  final String? dateLabel;
  final String title;
  final String statusLabel;
  final IconData statusIcon;
  final String? metaLabel;
  final bool emphasized;
  final bool selected;
  final bool showDivider;
  final VoidCallback? onPress;
  final String? semanticsLabel;
  final String? semanticsHint;
  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized || selected
            ? theme.colors.secondary
            : theme.colors.card,
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: theme.colors.border,
                  width: appStyle.dividerWidth,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: appStyle.spaceMd,
          vertical: appStyle.spaceSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: appStyle.ledgerTimeColumnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dateLabel case final date?)
                    Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  Text(
                    timeLabel,
                    maxLines: 1,
                    style: theme.typography.body.sm.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: appStyle.spaceMd,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Container(
                      width: emphasized
                          ? appStyle.strongBorderWidth
                          : appStyle.dividerWidth,
                      color: emphasized
                          ? theme.colors.foreground
                          : theme.colors.border,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: emphasized
                          ? theme.colors.foreground
                          : theme.colors.app.borderStrong,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: emphasized ? 8 : 6),
                  ),
                ],
              ),
            ),
            SizedBox(width: appStyle.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.display.md,
                        ),
                      ),
                      if (emphasized) ...[
                        SizedBox(width: appStyle.spaceXs),
                        _LedgerStatusBadge(label: statusLabel),
                      ],
                    ],
                  ),
                  if (emphasized) ...[
                    if (metaLabel case final meta?) ...[
                      SizedBox(height: appStyle.space2Xs),
                      Text(
                        meta,
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ] else ...[
                    SizedBox(height: appStyle.spaceXs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (metaLabel case final meta?)
                          Text(
                            meta,
                            maxLines: 1,
                            style: theme.typography.body.xs.copyWith(
                              color: theme.colors.mutedForeground,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        if (metaLabel != null)
                          SizedBox(width: appStyle.spaceSm),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: _LedgerStatus(
                              icon: statusIcon,
                              label: statusLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final result = onPress == null
        ? content
        : FTappable(
            semanticsLabel: semanticsLabel,
            semanticsHint: semanticsHint,
            excludeSemantics: semanticsLabel != null,
            onPress: onPress,
            child: content,
          );
    return Semantics(
      selected: selected,
      customSemanticsActions: customSemanticsActions,
      child: result,
    );
  }
}

final class _LedgerStatus extends StatelessWidget {
  const _LedgerStatus({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colors.mutedForeground),
        SizedBox(width: appStyle.space2Xs),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

final class _LedgerStatusBadge extends StatelessWidget {
  const _LedgerStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.foreground,
        borderRadius: BorderRadius.circular(appStyle.cardRadius / 2),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          appStyle.spaceXs,
          appStyle.space2Xs,
          appStyle.spaceXs,
          appStyle.space2Xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.background,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 7),
            ),
            SizedBox(width: appStyle.space2Xs),
            Text(
              label,
              maxLines: 1,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.background,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
