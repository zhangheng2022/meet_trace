import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';

enum AppSwipeActionTone { neutral, destructive }

final class AppSwipeAction {
  const AppSwipeAction({
    required this.label,
    required this.icon,
    required this.onPress,
    this.tone = AppSwipeActionTone.neutral,
    this.semanticsHint,
    this.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPress;
  final AppSwipeActionTone tone;
  final String? semanticsHint;
  final Key? key;
}

/// 横向拖动后揭示一个或多个尾部操作的受控列表行。
///
/// 操作只会被揭示，不会由完整滑动直接执行。父级通过 [revealed] 保证同一时间
/// 只有一行处于展开状态。
final class AppSwipeActionRow extends StatefulWidget {
  const AppSwipeActionRow({
    required this.revealed,
    required this.enabled,
    required this.onRevealChanged,
    required this.actions,
    required this.child,
    this.onSwipeStart,
    super.key,
  });

  final bool revealed;
  final bool enabled;
  final ValueChanged<bool> onRevealChanged;
  final List<AppSwipeAction> actions;
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

  void _handleAction(AppSwipeAction action) {
    _settle(false);
    if (widget.revealed) {
      widget.onRevealChanged(false);
    }
    action.onPress();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final itemExtent = appStyle.controlHeight + appStyle.spaceLg;
    final actionExtent = itemExtent * widget.actions.length;

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
                  child: Row(
                    children: [
                      for (final action in widget.actions)
                        SizedBox(
                          width: itemExtent,
                          child: _SwipeActionButton(
                            action: action,
                            onPress: () => _handleAction(action),
                          ),
                        ),
                    ],
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

final class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({required this.action, required this.onPress});

  final AppSwipeAction action;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final destructive = action.tone == AppSwipeActionTone.destructive;
    final background = destructive
        ? theme.colors.destructive
        : theme.colors.muted;
    final foreground = destructive
        ? theme.colors.destructiveForeground
        : theme.colors.foreground;
    return FTappable(
      key: action.key,
      style: const FTappableStyleDelta.delta(motion: FTappableMotion.none),
      semanticsLabel: action.label,
      semanticsHint: action.semanticsHint,
      onPress: onPress,
      builder: (context, variants, child) {
        final pressed = variants.contains(FTappableVariant.pressed);
        return ColoredBox(
          color: Color.lerp(background, foreground, pressed ? 0.12 : 0)!,
          child: child!,
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 18, color: foreground),
            SizedBox(height: appStyle.space2Xs),
            Text(
              action.label,
              maxLines: 1,
              style: theme.typography.body.xs.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
