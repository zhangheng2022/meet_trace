// Hallmark · preview: brand motion lab · world: Evidence Ledger

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:forui/forui.dart';

import '../../../../app/application.dart';
import '../../../../theme/theme.dart';
import '../meettrace_brand_mark.dart';

const _brandMotionDurations = <int>[720, 840, 960];

@Preview(name: 'Logo 轨迹归位 · 交互实验台', group: 'UI-00 品牌动效', size: Size(430, 900))
Widget meetTraceBrandMotionPreview() => const MeetTraceBrandMotionLab();

@Preview(
  name: 'Logo 轨迹归位 · 深色',
  group: 'UI-00 品牌动效',
  size: Size(430, 900),
  brightness: Brightness.dark,
)
Widget meetTraceBrandMotionDarkPreview() =>
    const MeetTraceBrandMotionLab(initialDarkMode: true);

/// 仅供 Widget Previewer 与独立调试入口使用的品牌动效实验台。
final class MeetTraceBrandMotionLab extends StatefulWidget {
  const MeetTraceBrandMotionLab({
    this.initialDurationMs = 960,
    this.initialDarkMode = false,
    this.autoplay = true,
    super.key,
  }) : assert(
         initialDurationMs == 720 ||
             initialDurationMs == 840 ||
             initialDurationMs == 960,
       );

  final int initialDurationMs;
  final bool initialDarkMode;
  final bool autoplay;

  @override
  State<MeetTraceBrandMotionLab> createState() =>
      _MeetTraceBrandMotionLabState();
}

final class _MeetTraceBrandMotionLabState extends State<MeetTraceBrandMotionLab>
    with SingleTickerProviderStateMixin {
  late int _durationMs = widget.initialDurationMs;
  late bool _darkMode = widget.initialDarkMode;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _durationMs),
  );

  @override
  void initState() {
    super.initState();
    if (widget.autoplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectDuration(int durationMs) {
    setState(() => _durationMs = durationMs);
    _controller
      ..duration = Duration(milliseconds: durationMs)
      ..forward(from: 0);
  }

  void _replay() => _controller.forward(from: 0);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '$appDisplayName · 品牌动效实验台',
    debugShowCheckedModeBanner: false,
    supportedLocales: FLocalizations.supportedLocales,
    localizationsDelegates: const [...FLocalizations.localizationsDelegates],
    theme: lightTheme.toApproximateMaterialTheme(),
    darkTheme: darkTheme.toApproximateMaterialTheme(),
    themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => FTheme(
      data: Theme.brightnessOf(context) == Brightness.light
          ? lightTheme
          : darkTheme,
      child: child ?? const SizedBox.shrink(),
    ),
    home: Builder(
      builder: (context) => Scaffold(
        backgroundColor: context.theme.colors.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) =>
                      _BrandMotionScene(progress: _controller.value),
                ),
              ),
              _BrandMotionControls(
                progress: _controller,
                durationMs: _durationMs,
                darkMode: _darkMode,
                onDurationChanged: _selectDuration,
                onDarkModeChanged: (value) => setState(() => _darkMode = value),
                onProgressChanged: (value) {
                  _controller
                    ..stop()
                    ..value = value;
                },
                onReplay: _replay,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _BrandMotionScene extends StatelessWidget {
  const _BrandMotionScene({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final startSize = width < 380 ? 72.0 : 76.0;
        const endSize = 52.0;
        final startRect = Rect.fromLTWH(
          (width - startSize) / 2,
          math.min(64, constraints.maxHeight * 0.1),
          startSize,
          startSize,
        );
        final endRect = Rect.fromLTWH(
          appStyle.spaceLg,
          appStyle.spaceLg,
          endSize,
          endSize,
        );
        final dockProgress = _emphasizedInterval(progress, 0.595, 0.929);
        final markRect = Rect.lerp(startRect, endRect, dockProgress)!;
        final ribbonProgress = _linearInterval(progress, 0, 0.667);
        final chineseProgress = _emphasizedInterval(progress, 0.774, 0.952);
        final englishProgress = _emphasizedInterval(progress, 0.857, 1);

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    appStyle.spaceLg,
                    152,
                    appStyle.spaceLg,
                    appStyle.spaceLg,
                  ),
                  child: const _StartupPreviewFacts(),
                ),
              ),
              Positioned.fromRect(
                rect: markRect,
                child: MeetTraceRibbonRevealMark(
                  progress: ribbonProgress,
                  size: markRect.width,
                ),
              ),
              Positioned(
                left: endRect.right + appStyle.spaceSm,
                top: endRect.top - appStyle.spaceXs,
                right: appStyle.spaceLg,
                height: endRect.height + appStyle.spaceMd,
                child: _RevealedWordmark(
                  chineseProgress: chineseProgress,
                  englishProgress: englishProgress,
                ),
              ),
            ],
          ),
        );
      },
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
    return Semantics(
      label: '会迹，MeetTrace',
      header: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRect(
              child: Align(
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
        ),
      ),
    );
  }
}

final class _StartupPreviewFacts extends StatelessWidget {
  const _StartupPreviewFacts();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('正在准备会迹', style: theme.typography.display.md),
          SizedBox(height: appStyle.spaceXs),
          Text(
            '恢复本地会议并检查离线转录资源，完成后自动进入首页。',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.app.inkSecondary,
            ),
          ),
          SizedBox(height: appStyle.spaceLg),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.card,
              border: Border.all(
                color: theme.colors.border,
                width: appStyle.dividerWidth,
              ),
              borderRadius: BorderRadius.circular(appStyle.cardRadius),
            ),
            child: Padding(
              padding: EdgeInsets.all(appStyle.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colors.foreground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SizedBox.square(
                          dimension: 24,
                          child: Icon(
                            FLucideIcons.loaderCircle,
                            size: 14,
                            color: theme.colors.background,
                          ),
                        ),
                      ),
                      SizedBox(width: appStyle.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '检查离线转录资源',
                              style: theme.typography.display.sm,
                            ),
                            SizedBox(height: appStyle.space2Xs),
                            Text(
                              '步骤 2 / 4',
                              style: theme.typography.body.xs.copyWith(
                                color: theme.colors.app.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: appStyle.spaceMd),
                  Text(
                    '正在核对本机模型文件与完整性。',
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.app.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: appStyle.spaceSm),
          Text(
            '会议记录与事实音频仍保存在本机',
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.app.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

final class _BrandMotionControls extends StatelessWidget {
  const _BrandMotionControls({
    required this.progress,
    required this.durationMs,
    required this.darkMode,
    required this.onDurationChanged,
    required this.onDarkModeChanged,
    required this.onProgressChanged,
    required this.onReplay,
  });

  final Animation<double> progress;
  final int durationMs;
  final bool darkMode;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<double> onProgressChanged;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final writeEndMs = (durationMs * 0.667).round();
    final dockStartMs = (durationMs * 0.595).round();
    final dockEndMs = (durationMs * 0.929).round();
    final wordmarkStartMs = (durationMs * 0.774).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.card,
        border: Border(
          top: BorderSide(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          appStyle.spaceLg,
          appStyle.spaceMd,
          appStyle.spaceLg,
          appStyle.spaceLg,
        ),
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '轨迹归位',
                    style: theme.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress.value * durationMs).round()} / $durationMs ms',
                    key: const ValueKey('brand-motion-time-label'),
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.app.inkSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Slider(
                key: const ValueKey('brand-motion-progress-slider'),
                value: progress.value,
                onChanged: onProgressChanged,
              ),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        for (final duration in _brandMotionDurations)
                          ButtonSegment<int>(
                            value: duration,
                            label: Text(
                              '$duration',
                              key: ValueKey('brand-motion-duration-$duration'),
                            ),
                          ),
                      ],
                      selected: {durationMs},
                      onSelectionChanged: (selection) =>
                          onDurationChanged(selection.single),
                    ),
                  ),
                  SizedBox(width: appStyle.spaceSm),
                  IconButton(
                    key: const ValueKey('brand-motion-replay'),
                    tooltip: '重新播放',
                    onPressed: onReplay,
                    icon: const Icon(Icons.replay_rounded),
                  ),
                  Switch(
                    key: const ValueKey('brand-motion-theme-switch'),
                    value: darkMode,
                    onChanged: onDarkModeChanged,
                  ),
                ],
              ),
              SizedBox(height: appStyle.spaceXs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('写入 0–$writeEndMs', style: theme.typography.body.xs),
                  Text(
                    '归位 $dockStartMs–$dockEndMs',
                    style: theme.typography.body.xs,
                  ),
                  Text(
                    '字标 $wordmarkStartMs–$durationMs',
                    style: theme.typography.body.xs,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _linearInterval(double value, double begin, double end) =>
    ((value - begin) / (end - begin)).clamp(0, 1);

double _emphasizedInterval(double value, double begin, double end) =>
    const Cubic(0.16, 1, 0.3, 1).transform(_linearInterval(value, begin, end));
