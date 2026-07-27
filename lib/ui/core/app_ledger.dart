import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';

/// 事实账本的连续表面。相邻记录共享外边界，不形成悬浮卡片网格。
final class AppLedgerSurface extends StatelessWidget {
  const AppLedgerSurface({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
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
    this.showDivider = true,
    this.onPress,
    this.semanticsLabel,
    this.semanticsHint,
    super.key,
  });

  final String timeLabel;
  final String? dateLabel;
  final String title;
  final String statusLabel;
  final IconData statusIcon;
  final String? metaLabel;
  final bool emphasized;
  final bool showDivider;
  final VoidCallback? onPress;
  final String? semanticsLabel;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized ? theme.colors.secondary : theme.colors.card,
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
          vertical: appStyle.spaceMd,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Container(
                width: emphasized
                    ? appStyle.strongBorderWidth
                    : appStyle.dividerWidth,
                margin: EdgeInsetsDirectional.only(end: appStyle.spaceMd),
                color: emphasized
                    ? theme.colors.foreground
                    : theme.colors.border,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.display.md,
                    ),
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
                    SizedBox(height: appStyle.spaceXs),
                    Row(
                      children: [
                        Icon(
                          statusIcon,
                          size: 16,
                          color: emphasized
                              ? theme.colors.foreground
                              : theme.colors.mutedForeground,
                        ),
                        SizedBox(width: appStyle.spaceXs),
                        Expanded(
                          child: Text(
                            statusLabel,
                            maxLines: 2,
                            style: theme.typography.body.xs.copyWith(
                              color: emphasized
                                  ? theme.colors.foreground
                                  : theme.colors.mutedForeground,
                            ),
                          ),
                        ),
                        if (onPress != null)
                          Icon(
                            FLucideIcons.chevronRight,
                            size: 18,
                            color: theme.colors.mutedForeground,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onPress == null) {
      return content;
    }
    return FTappable(
      semanticsLabel: semanticsLabel,
      semanticsHint: semanticsHint,
      excludeSemantics: semanticsLabel != null,
      onPress: onPress,
      child: content,
    );
  }
}

/// 录音时间刻度。只表达已持续的时间，不模拟音量或装饰性波形。
final class AppTimeRuler extends StatelessWidget {
  const AppTimeRuler({required this.elapsed, super.key});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Semantics(
      label: '录音已持续 ${_durationLabel(elapsed)}',
      excludeSemantics: true,
      child: SizedBox(
        height: 28,
        width: double.infinity,
        child: CustomPaint(
          painter: _TimeRulerPainter(
            color: theme.colors.foreground,
            mutedColor: theme.colors.app.borderStrong,
          ),
        ),
      ),
    );
  }
}

final class _TimeRulerPainter extends CustomPainter {
  const _TimeRulerPainter({required this.color, required this.mutedColor});

  final Color color;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = mutedColor
      ..strokeWidth = 1;
    final emphasis = Paint()
      ..color = color
      ..strokeWidth = 2;
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), baseline);
    const step = 12.0;
    var index = 0;
    for (var x = 0.0; x <= size.width; x += step) {
      final major = index % 5 == 0;
      final height = major ? 14.0 : 7.0;
      canvas.drawLine(
        Offset(x, y - height / 2),
        Offset(x, y + height / 2),
        major ? emphasis : baseline,
      );
      index++;
    }
    canvas.drawLine(
      Offset(size.width / 2, 2),
      Offset(size.width / 2, size.height - 2),
      emphasis,
    );
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) =>
      color != oldDelegate.color || mutedColor != oldDelegate.mutedColor;
}

String _durationLabel(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
