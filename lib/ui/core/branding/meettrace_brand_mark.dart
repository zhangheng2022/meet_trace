import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../theme/theme.dart';

const meetTraceBrandMotionDuration = Duration(milliseconds: 960);
const meetTraceBrandHandoffSize = 88.0;

/// 会迹的共享品牌标志。
///
final class MeetTraceBrandMark extends StatelessWidget {
  const MeetTraceBrandMark({this.size = 52, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      key: const ValueKey('meettrace-brand-mark'),
      dimension: size,
      child: CustomPaint(
        painter: _MeetTraceBrandMarkPainter(
          color: color ?? context.theme.colors.foreground,
        ),
      ),
    ),
  );
}

/// 使用官方标志轮廓呈现连续墨带写入效果。
///
/// 该组件只负责绘制确定进度的单帧，不自行持有动画控制器，便于预览、
/// 测试以及后续由启动流程决定是否采用。
final class MeetTraceRibbonRevealMark extends StatelessWidget {
  const MeetTraceRibbonRevealMark({
    required this.progress,
    this.size = 72,
    this.color,
    super.key,
  }) : assert(progress >= 0 && progress <= 1);

  final double progress;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      key: const ValueKey('meettrace-ribbon-reveal-mark'),
      dimension: size,
      child: CustomPaint(
        painter: _MeetTraceRibbonRevealPainter(
          color: color ?? context.theme.colors.foreground,
          progress: progress,
        ),
      ),
    ),
  );
}

/// 启动页使用的一次性品牌动效。
///
/// 960ms 内依次完成官方墨带写入、标志归位和中英文字标揭示。
/// 动画完成信号只用于保证启动页完整展示，不参与初始化业务状态，并遵循系统
/// “减少动态效果”。
final class MeetTraceAnimatedWordmark extends StatefulWidget {
  const MeetTraceAnimatedWordmark({
    this.duration = meetTraceBrandMotionDuration,
    this.disableAnimations,
    this.onCompleted,
    super.key,
  });

  final Duration duration;

  /// 测试入口；生产环境为空时遵循系统“减少动态效果”。
  final bool? disableAnimations;
  final VoidCallback? onCompleted;

  @override
  State<MeetTraceAnimatedWordmark> createState() =>
      _MeetTraceAnimatedWordmarkState();
}

final class _MeetTraceAnimatedWordmarkState
    extends State<MeetTraceAnimatedWordmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _configured = false;
  bool _completionNotified = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completionNotified) {
      return;
    }
    _completionNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onCompleted?.call();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled =
        widget.disableAnimations ?? MediaQuery.disableAnimationsOf(context);
    if (animationsDisabled) {
      _controller.value = 1;
      _configured = true;
      return;
    }
    if (_configured) {
      return;
    }
    _configured = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.isCompleted) {
        return;
      }
      _controller.forward();
    });
  }

  @override
  void didUpdateWidget(MeetTraceAnimatedWordmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final accessibilityHeight = math.max(0, textScale - 1).toDouble() * 48;
    return Semantics(
      key: const ValueKey('meettrace-startup-wordmark'),
      container: true,
      header: true,
      label: '会迹，MeetTrace',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 84 + accessibilityHeight,
          child: LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                const startSize = meetTraceBrandHandoffSize;
                const endSize = 52.0;
                final startRect = Rect.fromLTWH(
                  (constraints.maxWidth - startSize) / 2,
                  4,
                  startSize,
                  startSize,
                );
                const endRect = Rect.fromLTWH(0, 10, endSize, endSize);
                final dockProgress = _emphasizedInterval(
                  _controller.value,
                  0.595,
                  0.929,
                );
                final markRect = Rect.lerp(startRect, endRect, dockProgress)!;
                final ribbonProgress = _linearInterval(
                  _controller.value,
                  0,
                  0.667,
                );
                final chineseProgress = _emphasizedInterval(
                  _controller.value,
                  0.774,
                  0.952,
                );
                final englishProgress = _emphasizedInterval(
                  _controller.value,
                  0.857,
                  1,
                );

                return ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        key: const ValueKey(
                          'meettrace-startup-brand-mark-stage',
                        ),
                        rect: markRect,
                        child: MeetTraceRibbonRevealMark(
                          progress: ribbonProgress,
                          size: markRect.width,
                        ),
                      ),
                      Positioned(
                        left: endRect.right + appStyle.spaceSm,
                        top: 4,
                        right: 0,
                        height: 64 + accessibilityHeight,
                        child: _RevealedWordmark(
                          chineseProgress: chineseProgress,
                          englishProgress: englishProgress,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

final class _RevealedWordmark extends StatelessWidget {
  const _RevealedWordmark({
    required this.chineseProgress,
    required this.englishProgress,
  });

  final double chineseProgress;
  final double englishProgress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRect(
          child: Align(
            key: const ValueKey('meettrace-wordmark-chinese-reveal'),
            alignment: Alignment.centerLeft,
            widthFactor: chineseProgress,
            child: Text(
              '会迹',
              maxLines: 1,
              softWrap: false,
              style: theme.typography.display.xl2,
            ),
          ),
        ),
        SizedBox(height: appStyle.space2Xs),
        ClipRect(
          child: Align(
            key: const ValueKey('meettrace-wordmark-english-reveal'),
            alignment: Alignment.centerLeft,
            widthFactor: englishProgress,
            child: Text(
              'MeetTrace',
              maxLines: 1,
              softWrap: false,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.app.inkSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

double _linearInterval(double value, double begin, double end) =>
    ((value - begin) / (end - begin)).clamp(0, 1);

double _emphasizedInterval(double value, double begin, double end) =>
    const Cubic(0.16, 1, 0.3, 1).transform(_linearInterval(value, begin, end));

final class _MeetTraceBrandMarkPainter extends CustomPainter {
  const _MeetTraceBrandMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = _meetTraceMarkPath.getBounds();
    final scale = math.min(
      size.width / bounds.width,
      size.height / bounds.height,
    );
    final dx = (size.width - bounds.width * scale) / 2 - bounds.left * scale;
    final dy = (size.height - bounds.height * scale) / 2 - bounds.top * scale;

    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    canvas.drawPath(
      _meetTraceMarkPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MeetTraceBrandMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

final class _MeetTraceRibbonRevealPainter extends CustomPainter {
  const _MeetTraceRibbonRevealPainter({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    final bounds = _meetTraceMarkPath.getBounds();
    final scale = math.min(
      size.width / bounds.width,
      size.height / bounds.height,
    );
    final dx = (size.width - bounds.width * scale) / 2 - bounds.left * scale;
    final dy = (size.height - bounds.height * scale) / 2 - bounds.top * scale;

    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    if (progress >= 1) {
      canvas.drawPath(
        _meetTraceMarkPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
      return;
    }

    canvas.clipPath(_meetTraceMarkPath);
    canvas.drawPath(
      _extractMeetTraceRibbonPath(progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 62
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MeetTraceRibbonRevealPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}

final Path _meetTraceMotionPath = Path()
  ..moveTo(144, 342)
  ..cubicTo(146, 292, 149, 220, 153, 176)
  ..cubicTo(184, 202, 225, 237, 264, 273)
  ..cubicTo(291, 247, 331, 205, 358, 177)
  ..cubicTo(358, 222, 358, 294, 358, 342);

final PathMetric _meetTraceMotionMetric = _meetTraceMotionPath
    .computeMetrics()
    .single;

Path _extractMeetTraceRibbonPath(double progress) => Path()
  ..addPath(
    _meetTraceMotionMetric.extractPath(
      0,
      _meetTraceMotionMetric.length * progress,
    ),
    Offset.zero,
  );

// Generated from assets/branding/stitch/meettrace-mark-black.svg.
// Keep the SVG as the geometry source of truth and regenerate this path when it
// changes instead of editing individual control points here.
final Path _meetTraceMarkPath = _buildMeetTraceMarkPath();

Path _buildMeetTraceMarkPath() {
  final path = Path()..fillType = PathFillType.evenOdd;
  path.moveTo(143.5, 148.707);
  path.cubicTo(140.076, 149.874, 136.711, 152.19, 132.822, 156.054);
  path.cubicTo(128.364, 160.484, 126.821, 162.856, 125.637, 167.098);
  path.cubicTo(124.666, 170.581, 123.392, 185.646, 122.051, 209.5);
  path.cubicTo(120.907, 229.85, 118.855, 266.3, 117.49, 290.5);
  path.cubicTo(116.125, 314.7, 115.006, 337.457, 115.004, 341.072);
  path.cubicTo(114.998, 350.766, 117.327, 356.474, 124.024, 363.178);
  path.cubicTo(128.548, 367.707, 130.875, 369.199, 135.526, 370.551);
  path.cubicTo(143.284, 372.806, 151.273, 372.065, 157.862, 368.478);
  path.cubicTo(161.662, 366.41, 171.819, 356.145, 200.028, 325.863);
  path.lineTo(237.189, 285.972);
  path.lineTo(242.144, 290.236);
  path.cubicTo(253.491, 300.001, 259.527, 302.538, 269.519, 301.745);
  path.cubicTo(280.038, 300.91, 283.633, 298.288, 306.131, 275.035);
  path.lineTo(326.5, 253.983);
  path.lineTo(327, 302.241);
  path.lineTo(327.5, 350.5);
  path.lineTo(330.28, 356.161);
  path.cubicTo(335.575, 366.943, 345.401, 373.246, 357.083, 373.353);
  path.cubicTo(362.623, 373.404, 364.808, 372.877, 370.332, 370.157);
  path.cubicTo(377.383, 366.686, 382.598, 361.357, 385.729, 354.423);
  path.cubicTo(387.373, 350.782, 387.52, 344.263, 387.777, 263.598);
  path.cubicTo(388.024, 186.008, 387.88, 176.1, 386.438, 171.137);
  path.cubicTo(383.239, 160.133, 374.886, 152.156, 364.251, 149.948);
  path.cubicTo(361.193, 149.313, 356.867, 149.086, 354.638, 149.442);
  path.cubicTo(344.679, 151.034, 343.239, 152.249, 303, 193.013);
  path.lineTo(264.5, 232.014);
  path.lineTo(255.424, 224.257);
  path.cubicTo(204.778, 180.97, 171.024, 153.003, 166.581, 150.643);
  path.cubicTo(159.708, 146.993, 150.733, 146.24, 143.5, 148.707);
  path.close();
  path.moveTo(145.4, 168.4);
  path.cubicTo(142.457, 171.343, 142, 172.46, 142, 176.709);
  path.cubicTo(142, 179.409, 142.563, 182.382, 143.25, 183.317);
  path.cubicTo(143.938, 184.252, 164.975, 202.283, 190, 223.385);
  path.lineTo(235.5, 261.754);
  path.lineTo(243.75, 253.649);
  path.cubicTo(248.287, 249.191, 252, 245.224, 252, 244.833);
  path.cubicTo(252, 244.442, 248.287, 240.983, 243.75, 237.146);
  path.cubicTo(149.973, 157.846, 158.936, 165, 153.361, 165);
  path.cubicTo(149.507, 165, 148.273, 165.527, 145.4, 168.4);
  path.close();
  path.moveTo(352.832, 168.034);
  path.cubicTo(350.443, 169.428, 250, 271.916, 250, 272.959);
  path.cubicTo(250, 273.436, 252.739, 276.116, 256.087, 278.913);
  path.cubicTo(261.656, 283.566, 262.615, 284.003, 267.337, 284.031);
  path.lineTo(272.5, 284.063);
  path.lineTo(296.903, 259.281);
  path.cubicTo(337.833, 217.717, 367.436, 186.961, 368.715, 184.673);
  path.cubicTo(371.647, 179.426, 369.27, 171.225, 364.033, 168.517);
  path.cubicTo(360.725, 166.806, 355.334, 166.574, 352.832, 168.034);
  path.close();
  path.moveTo(139.598, 212.197);
  path.cubicTo(139.278, 216.214, 138.558, 227.6, 137.999, 237.5);
  path.cubicTo(137.44, 247.4, 136.311, 266.837, 135.491, 280.693);
  path.cubicTo(134.671, 294.549, 134.021, 306.699, 134.048, 307.693);
  path.cubicTo(134.079, 308.869, 138.388, 305.017, 146.389, 296.662);
  path.lineTo(158.682, 283.824);
  path.lineTo(159.883, 262.162);
  path.cubicTo(160.543, 250.248, 161.326, 236.45, 161.621, 231.5);
  path.lineTo(162.158, 222.5);
  path.lineTo(151.876, 214);
  path.cubicTo(146.221, 209.325, 141.276, 205.364, 140.887, 205.197);
  path.cubicTo(140.499, 205.03, 139.918, 208.18, 139.598, 212.197);
  path.close();
  path.moveTo(357.25, 222.565);
  path.lineTo(345, 235.484);
  path.lineTo(345, 291.607);
  path.cubicTo(345, 347.007, 345.027, 347.764, 347.088, 350.385);
  path.cubicTo(349.72, 353.731, 354.05, 356, 357.802, 356);
  path.cubicTo(361.417, 356, 367.09, 352.278, 368.757, 348.812);
  path.cubicTo(369.736, 346.776, 369.957, 331.125, 369.757, 277.922);
  path.lineTo(369.5, 209.645);
  path.lineTo(357.25, 222.565);
  path.close();
  path.moveTo(178.6, 241.241);
  path.cubicTo(178.312, 243.583, 177.899, 249.775, 177.683, 255);
  path.lineTo(177.291, 264.5);
  path.lineTo(184.734, 256.837);
  path.cubicTo(188.828, 252.622, 192.251, 248.983, 192.339, 248.75);
  path.cubicTo(192.428, 248.518, 189.491, 245.775, 185.813, 242.654);
  path.lineTo(179.125, 236.981);
  path.lineTo(178.6, 241.241);
  path.close();
  path.moveTo(181.388, 285.764);
  path.cubicTo(130.972, 337.915, 133.353, 335.305, 132.615, 339.238);
  path.cubicTo(131.832, 343.415, 133.577, 348.478, 136.784, 351.335);
  path.cubicTo(139.729, 353.957, 145.988, 354.574, 149.776, 352.616);
  path.cubicTo(151.482, 351.734, 166.929, 335.822, 184.103, 317.256);
  path.cubicTo(201.277, 298.69, 217.262, 281.475, 219.625, 279);
  path.lineTo(223.921, 274.5);
  path.lineTo(217.344, 269);
  path.cubicTo(213.727, 265.975, 209.755, 262.719, 208.518, 261.764);
  path.cubicTo(206.276, 260.035, 206.172, 260.127, 181.388, 285.764);
  path.close();
  return path;
}
