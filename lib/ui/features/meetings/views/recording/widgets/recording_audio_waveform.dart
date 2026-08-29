import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../l10n/l10n.dart';
import '../../../../../../theme/theme.dart';

const recordingWaveformTransitionDuration = Duration(milliseconds: 100);

enum RecordingAudioWaveformState { waiting, live, paused, stopped }

/// 由真实麦克风 PCM 音量驱动的只读波形反馈。
final class RecordingAudioWaveform extends StatefulWidget {
  const RecordingAudioWaveform({
    required this.levels,
    required this.state,
    this.height = 52,
    super.key,
  });

  final List<double> levels;
  final RecordingAudioWaveformState state;
  final double height;

  @override
  State<RecordingAudioWaveform> createState() => _RecordingAudioWaveformState();
}

final class _RecordingAudioWaveformState extends State<RecordingAudioWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: recordingWaveformTransitionDuration,
    value: 1,
  );
  late List<double> _fromLevels = List<double>.of(widget.levels);
  late List<double> _targetLevels = List<double>.of(widget.levels);

  @override
  void didUpdateWidget(covariant RecordingAudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(widget.levels, oldWidget.levels)) {
      return;
    }

    final progress = _controller.value;
    _fromLevels = _interpolateRightAligned(
      _fromLevels,
      _targetLevels,
      progress,
    );
    _targetLevels = List<double>.of(widget.levels);

    if (context.accessibility.motion == .disabled) {
      _fromLevels = _targetLevels;
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final appStyle = theme.style.app;
    final (semanticsLabel, caption) = switch (widget.state) {
      RecordingAudioWaveformState.waiting => (
        l10n.waveformWaitingSemantics,
        l10n.waveformWaitingLabel,
      ),
      RecordingAudioWaveformState.live => (
        l10n.waveformLiveSemantics,
        l10n.waveformLiveLabel,
      ),
      RecordingAudioWaveformState.paused => (
        l10n.waveformPausedSemantics,
        l10n.waveformPausedLabel,
      ),
      RecordingAudioWaveformState.stopped => (
        l10n.waveformStoppedSemantics,
        l10n.waveformStoppedLabel,
      ),
    };
    final active = widget.state == RecordingAudioWaveformState.live;
    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            key: const ValueKey('recording-audio-waveform'),
            width: double.infinity,
            height: widget.height,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final progress = _controller.value;
                  return CustomPaint(
                    painter: _RecordingWaveformPainter(
                      levels: _interpolateRightAligned(
                        _fromLevels,
                        _targetLevels,
                        progress,
                      ),
                      active: active,
                      foreground: theme.colors.foreground,
                      muted: theme.colors.app.borderStrong,
                      baseline: theme.colors.border,
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: appStyle.space2Xs),
          Text(
            caption,
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

List<double> _interpolateRightAligned(
  List<double> from,
  List<double> to,
  double progress,
) {
  final length = math.max(from.length, to.length);
  final fromOffset = length - from.length;
  final toOffset = length - to.length;
  return List<double>.generate(length, (index) {
    final fromIndex = index - fromOffset;
    final toIndex = index - toOffset;
    final fromValue = fromIndex < 0 ? 0.0 : from[fromIndex];
    final toValue = toIndex < 0 ? 0.0 : to[toIndex];
    return fromValue + (toValue - fromValue) * progress;
  }, growable: false);
}

final class _RecordingWaveformPainter extends CustomPainter {
  const _RecordingWaveformPainter({
    required this.levels,
    required this.active,
    required this.foreground,
    required this.muted,
    required this.baseline,
  });

  final List<double> levels;
  final bool active;
  final Color foreground;
  final Color muted;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final baselineY = size.height - 0.5;
    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    final slotCount = math.min(48, math.max(16, (size.width / 6).floor()));
    final visibleCount = math.min(levels.length, slotCount);
    final firstLevel = levels.length - visibleCount;
    final leadingEmpty = slotCount - visibleCount;
    final slotWidth = size.width / slotCount;
    final strokeWidth = math.min(4.0, slotWidth * 0.56);
    final availableHeight = math.max(2.0, size.height - 6);
    final recentStart = math.max(0, levels.length - 16);
    final recentPeak = levels
        .skip(recentStart)
        .fold(0.0, (peak, level) => math.max(peak, level));
    final visualReference = math.max(0.55, recentPeak);
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < slotCount; index++) {
      final rawValue = index < leadingEmpty
          ? 0.0
          : levels[firstLevel + index - leadingEmpty].clamp(0.0, 1.0);
      final value = _visualAmplitude(rawValue, visualReference);
      final height = math.max(3.0, value * availableHeight);
      final recency = slotCount == 1 ? 1.0 : index / (slotCount - 1);
      paint.color = active
          ? Color.lerp(muted, foreground, 0.28 + recency * 0.72)!
          : Color.lerp(baseline, muted, 0.55)!;
      final x = slotWidth * (index + 0.5);
      canvas.drawLine(
        Offset(x, baselineY),
        Offset(x, baselineY - height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RecordingWaveformPainter oldDelegate) {
    return active != oldDelegate.active ||
        foreground != oldDelegate.foreground ||
        muted != oldDelegate.muted ||
        baseline != oldDelegate.baseline ||
        !listEquals(levels, oldDelegate.levels);
  }
}

double _visualAmplitude(double level, double reference) {
  const noiseGate = 0.08;
  if (level <= noiseGate) {
    return 0;
  }
  final normalized = ((level - noiseGate) / (reference - noiseGate)).clamp(
    0.0,
    1.0,
  );
  return math.pow(normalized, 0.82).toDouble();
}
