import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';

/// 横向拖动后揭示单个尾部操作的受控列表行。
///
/// 操作只会被揭示，不会由完整滑动直接执行。父级通过 [revealed] 保证同一时间
/// 只有一行处于展开状态。
final class AppSwipeActionRow extends StatefulWidget {
  const AppSwipeActionRow({
    required this.revealed,
    required this.enabled,
    required this.onRevealChanged,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.child,
    this.actionKey,
    this.onSwipeStart,
    super.key,
  });

  final bool revealed;
  final bool enabled;
  final ValueChanged<bool> onRevealChanged;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final Key? actionKey;
  final VoidCallback? onSwipeStart;
  final Widget child;

  @override
  State<AppSwipeActionRow> createState() => _AppSwipeActionRowState();
}

final class _AppSwipeActionRowState extends State<AppSwipeActionRow>
    with SingleTickerProviderStateMixin {
  static const _revealDuration = Duration(milliseconds: 180);
  static const _closeDuration = Duration(milliseconds: 140);
  static const _flingVelocity = 420.0;
  static const _revealThreshold = 0.42;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.revealed ? 1 : 0,
  );
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant AppSwipeActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _settle(false);
      return;
    }
    if (!_dragging && widget.revealed != oldWidget.revealed) {
      _settle(widget.revealed);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _dragging = true;
    _controller.stop();
    widget.onSwipeStart?.call();
  }

  void _handleDragUpdate(DragUpdateDetails details, double actionExtent) {
    final delta = details.primaryDelta;
    if (delta == null || actionExtent <= 0) {
      return;
    }
    _controller.value = (_controller.value - delta / actionExtent).clamp(
      0.0,
      1.0,
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragging = false;
    final velocity = details.primaryVelocity ?? 0;
    final reveal = switch (velocity) {
      < -_flingVelocity => true,
      > _flingVelocity => false,
      _ => _controller.value >= _revealThreshold,
    };
    _settle(reveal);
    if (widget.revealed != reveal) {
      widget.onRevealChanged(reveal);
    }
  }

  void _settle(bool reveal) {
    final target = reveal ? 1.0 : 0.0;
    if (!mounted || context.accessibility.motion == .disabled) {
      _controller.value = target;
      return;
    }
    _controller.animateTo(
      target,
      duration: reveal ? _revealDuration : _closeDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _handleAction() {
    _settle(false);
    if (widget.revealed) {
      widget.onRevealChanged(false);
    }
    widget.onAction();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final actionExtent = appStyle.controlHeight + appStyle.spaceLg;

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(
                width: actionExtent,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final exposed = _controller.value >= 0.95;
                    return IgnorePointer(
                      ignoring: !exposed,
                      child: ExcludeSemantics(
                        excluding: !exposed,
                        child: child,
                      ),
                    );
                  },
                  child: FTappable(
                    key: widget.actionKey,
                    style: const FTappableStyleDelta.delta(
                      motion: FTappableMotion.none,
                    ),
                    semanticsLabel: widget.actionLabel,
                    semanticsHint: '打开永久删除确认',
                    onPress: _handleAction,
                    builder: (context, variants, child) {
                      final pressed = variants.contains(
                        FTappableVariant.pressed,
                      );
                      return ColoredBox(
                        color: Color.lerp(
                          theme.colors.destructive,
                          theme.colors.destructiveForeground,
                          pressed ? 0.12 : 0,
                        )!,
                        child: child!,
                      );
                    },
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.actionIcon,
                            size: 18,
                            color: theme.colors.destructiveForeground,
                          ),
                          SizedBox(height: appStyle.space2Xs),
                          Text(
                            widget.actionLabel,
                            maxLines: 1,
                            style: theme.typography.body.xs.copyWith(
                              color: theme.colors.destructiveForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: widget.enabled ? _handleDragStart : null,
              onHorizontalDragUpdate: widget.enabled
                  ? (details) => _handleDragUpdate(details, actionExtent)
                  : null,
              onHorizontalDragEnd: widget.enabled ? _handleDragEnd : null,
              child: RepaintBoundary(child: widget.child),
            ),
            builder: (context, child) => Transform.translate(
              offset: Offset(-actionExtent * _controller.value, 0),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
