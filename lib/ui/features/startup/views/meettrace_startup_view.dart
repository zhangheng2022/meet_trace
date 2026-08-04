// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Impeccable · page: startup · world: Evidence Ledger
// THESIS: startup is a short, trustworthy local preparation state, not a blank
// app shell or a decorative brand animation.
// STORY: identify MeetTrace, then explain the real local preparation work.

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/runtime_initialization.dart';
import '../../../../theme/theme.dart';
import '../../../core/app_responsive.dart';
import '../../../core/branding/meettrace_brand_mark.dart';
import '../view_models/runtime_initialization_view_model.dart';

/// 会迹的本地能力加载页。
final class MeetTraceStartupView extends StatelessWidget {
  const MeetTraceStartupView({this.viewModel, super.key});

  final RuntimeInitializationViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final model = viewModel;
    if (model == null) {
      return const _StartupFrame(body: _StartupProgressContent());
    }
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) =>
          _StartupFrame(body: _StartupProgressContent(viewModel: model)),
    );
  }
}

/// 在快速本地检查、资源准备和应用首页之间提供平滑过渡。
final class MeetTraceRuntimeInitializationTransition extends StatelessWidget {
  const MeetTraceRuntimeInitializationTransition({
    required this.viewModel,
    required this.ready,
    super.key,
  });

  final RuntimeInitializationViewModel viewModel;
  final Widget ready;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final phase = viewModel.state.phase;
        final child = phase == RuntimeInitializationPhase.ready
            ? KeyedSubtree(
                key: const ValueKey('runtime-initialization-ready'),
                child: ready,
              )
            : KeyedSubtree(
                key: const ValueKey('runtime-initialization-progress'),
                child: MeetTraceStartupView(viewModel: viewModel),
              );
        return AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 280),
          reverseDuration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: child,
        );
      },
    );
  }
}

/// 数据代标记无法读取时的保护性阻断页。
final class MeetTraceDataReadBlockedView extends StatelessWidget {
  const MeetTraceDataReadBlockedView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _StartupFrame(
    body: _StartupBlockedContent(
      onRetry: onRetry,
      lead: '为保护本地数据，启动已停止。',
      title: '无法读取本地数据',
      message: '自动清理未执行。请检查设备存储状态后重试。',
    ),
  );
}

/// 依赖或本地运行能力初始化失败时的阻断页。
final class MeetTraceInitializationBlockedView extends StatelessWidget {
  const MeetTraceInitializationBlockedView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _StartupFrame(
    body: _StartupBlockedContent(
      onRetry: onRetry,
      lead: '本地能力未完成初始化。',
      title: '本地能力准备未完成',
      message: '请确认设备空间充足后重试。',
    ),
  );
}

final class _StartupFrame extends StatelessWidget {
  const _StartupFrame({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      child: SafeArea(
        child: AppResponsiveBuilder(
          builder: (context, sizeClass, _) {
            final appStyle = context.theme.style.app;
            final horizontalPadding = switch (sizeClass) {
              AppWindowSizeClass.compact => appStyle.spaceLg,
              AppWindowSizeClass.medium => appStyle.spaceXl,
              AppWindowSizeClass.expanded => appStyle.space2Xl,
            };
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: appStyle.contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    appStyle.spaceLg,
                    horizontalPadding,
                    appStyle.spaceLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, bodyConstraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: bodyConstraints.maxHeight,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: body,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _StartupProgressContent extends StatelessWidget {
  const _StartupProgressContent({this.viewModel});

  final RuntimeInitializationViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final model = viewModel;
    final state = model?.state;
    final stage = _stageForProgress(state);
    final percentage = state == null ? 0 : _progressPercentage(state);
    final description = state?.message ?? stage.description;
    return Semantics(
      container: true,
      label: '正在准备会迹，${stage.title}',
      child: Column(
        key: const ValueKey('meettrace-startup-progress-content'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MeetTraceAnimatedWordmark(),
          SizedBox(height: appStyle.spaceXl),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StartupStageMark(stage: stage),
                      SizedBox(width: appStyle.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stage.title,
                              key: const ValueKey('runtime-stage-title'),
                              style: theme.typography.display.sm,
                            ),
                            SizedBox(height: appStyle.space2Xs),
                            Text(
                              '步骤 ${stage.step} / 4',
                              key: const ValueKey('runtime-stage-step'),
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
                    description,
                    key: const ValueKey('runtime-stage-description'),
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.app.inkSecondary,
                    ),
                  ),
                  if (state != null && state.totalBytes > 0) ...[
                    SizedBox(height: appStyle.spaceLg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            state.resourceName ?? 'SenseVoice + Silero VAD',
                            key: const ValueKey('runtime-resource-name'),
                            style: theme.typography.body.sm,
                          ),
                        ),
                        SizedBox(width: appStyle.spaceSm),
                        Text(
                          '$percentage%',
                          key: const ValueKey('runtime-download-percentage'),
                          style: theme.typography.display.md,
                        ),
                      ],
                    ),
                    SizedBox(height: appStyle.spaceSm),
                    FDeterminateProgress(
                      key: const ValueKey('runtime-download-progress-bar'),
                      value: state.fraction,
                      semanticsLabel: '离线转录资源准备进度',
                    ),
                    SizedBox(height: appStyle.spaceSm),
                    Text(
                      _progressLabel(state),
                      key: const ValueKey('runtime-download-progress'),
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.app.inkSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: appStyle.spaceSm),
          Text(
            '会议记录与事实音频仍保存在本机',
            key: const ValueKey('meettrace-startup-local-evidence'),
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.app.inkSecondary,
            ),
          ),
          SizedBox(height: appStyle.spaceLg),
          if (state?.phase == RuntimeInitializationPhase.awaitingMobileConsent)
            Column(
              key: const ValueKey('runtime-mobile-actions'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FButton(
                  key: const ValueKey('confirm-mobile-download'),
                  size: FButtonSizeVariant.lg,
                  onPress: () => model?.confirmMobileDownload(),
                  child: const Text('同意并下载'),
                ),
                SizedBox(height: appStyle.spaceSm),
                FButton(
                  key: const ValueKey('decline-mobile-download'),
                  variant: FButtonVariant.outline,
                  size: FButtonSizeVariant.lg,
                  onPress: model?.declineMobileDownload,
                  child: const Text('暂不使用移动网络'),
                ),
              ],
            )
          else if (state?.phase == RuntimeInitializationPhase.downloading)
            SizedBox(
              width: double.infinity,
              child: FButton(
                key: const ValueKey('pause-runtime-download'),
                variant: FButtonVariant.outline,
                size: FButtonSizeVariant.lg,
                onPress: model?.pause,
                child: const Text('暂停下载'),
              ),
            )
          else if (state?.phase == RuntimeInitializationPhase.paused ||
              state?.phase == RuntimeInitializationPhase.failed ||
              state?.phase == RuntimeInitializationPhase.insufficientSpace)
            SizedBox(
              width: double.infinity,
              child: FButton(
                key: const ValueKey('resume-runtime-download'),
                size: FButtonSizeVariant.lg,
                onPress: () => model?.resume(),
                child: Text(
                  state?.phase == RuntimeInitializationPhase.paused
                      ? '继续下载'
                      : '重试',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _progressLabel(RuntimeInitializationProgress state) {
  final completedMb = (state.completedBytes / 1000000).toStringAsFixed(1);
  final totalMb = (state.totalBytes / 1000000).toStringAsFixed(1);
  return '$completedMb MB / $totalMb MB';
}

int _progressPercentage(RuntimeInitializationProgress state) {
  if (state.totalBytes <= 0) {
    return 0;
  }
  if (state.completedBytes >= state.totalBytes) {
    return 100;
  }
  return (state.fraction * 100).floor();
}

({String title, String description, int step, IconData icon, bool active})
_stageForProgress(RuntimeInitializationProgress? state) => state == null
    ? (
        title: '打开本地工作区',
        description: '正在恢复会议记录并确认本地数据可用。',
        step: 1,
        icon: FLucideIcons.fileAudio,
        active: true,
      )
    : _stageFor(state.phase);

({String title, String description, int step, IconData icon, bool active})
_stageFor(RuntimeInitializationPhase phase) => switch (phase) {
  RuntimeInitializationPhase.checking => (
    title: '检查离线资源',
    description: '正在核对本地文件与固定资源清单。',
    step: 2,
    icon: FLucideIcons.fileAudio,
    active: true,
  ),
  RuntimeInitializationPhase.awaitingMobileConsent => (
    title: '等待网络确认',
    description: '确认网络后即可开始下载。',
    step: 2,
    icon: FLucideIcons.triangleAlert,
    active: false,
  ),
  RuntimeInitializationPhase.insufficientSpace => (
    title: '需要释放设备空间',
    description: '释放足够空间后可以重新检查。',
    step: 2,
    icon: FLucideIcons.circleAlert,
    active: false,
  ),
  RuntimeInitializationPhase.downloading => (
    title: '下载离线资源',
    description: '下载可暂停，已完成的部分会保留。',
    step: 2,
    icon: FLucideIcons.fileAudio,
    active: false,
  ),
  RuntimeInitializationPhase.paused => (
    title: '下载已暂停',
    description: '继续后将从当前进度恢复。',
    step: 2,
    icon: FLucideIcons.pause,
    active: false,
  ),
  RuntimeInitializationPhase.verifying => (
    title: '校验资源完整性',
    description: '正在确认文件大小与完整性。',
    step: 3,
    icon: FLucideIcons.shieldCheck,
    active: true,
  ),
  RuntimeInitializationPhase.activating => (
    title: '启用离线转录',
    description: '正在加载本地推理能力。',
    step: 4,
    icon: FLucideIcons.fileAudio,
    active: true,
  ),
  RuntimeInitializationPhase.failed => (
    title: '资源准备未完成',
    description: '请检查提示后重试。',
    step: 2,
    icon: FLucideIcons.circleAlert,
    active: false,
  ),
  RuntimeInitializationPhase.ready => (
    title: '离线转录已就绪',
    description: '正在进入会迹。',
    step: 4,
    icon: FLucideIcons.circleCheck,
    active: false,
  ),
};

final class _StartupStageMark extends StatelessWidget {
  const _StartupStageMark({required this.stage});

  final ({
    String title,
    String description,
    int step,
    IconData icon,
    bool active,
  })
  stage;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Container(
      width: appStyle.minimumTouchTarget,
      height: appStyle.minimumTouchTarget,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colors.muted,
        borderRadius: BorderRadius.circular(appStyle.cardRadius),
      ),
      child: stage.active
          ? FCircularProgress(
              size: FCircularProgressSizeVariant.sm,
              semanticsLabel: stage.title,
            )
          : Icon(stage.icon, size: 20),
    );
  }
}

final class _StartupBlockedContent extends StatelessWidget {
  const _StartupBlockedContent({
    required this.onRetry,
    required this.lead,
    required this.title,
    required this.message,
  });

  final VoidCallback onRetry;
  final String lead;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Semantics(
      container: true,
      label: '会迹本地能力准备未完成',
      child: Column(
        key: const ValueKey('meettrace-startup-error'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MeetTraceAnimatedWordmark(),
          SizedBox(height: appStyle.spaceXl),
          Text('启动需要你的处理', style: theme.typography.display.md),
          SizedBox(height: appStyle.spaceXs),
          Text(
            lead,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.app.inkSecondary,
            ),
          ),
          SizedBox(height: appStyle.spaceLg),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.card,
              border: Border.all(
                color: theme.colors.foreground,
                width: appStyle.strongBorderWidth,
              ),
              borderRadius: BorderRadius.circular(appStyle.cardRadius),
            ),
            child: Padding(
              padding: EdgeInsets.all(appStyle.spaceMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: appStyle.minimumTouchTarget,
                    height: appStyle.minimumTouchTarget,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colors.muted,
                      borderRadius: BorderRadius.circular(appStyle.cardRadius),
                    ),
                    child: const Icon(FLucideIcons.circleAlert, size: 20),
                  ),
                  SizedBox(width: appStyle.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.typography.display.sm),
                        SizedBox(height: appStyle.spaceXs),
                        Text(
                          message,
                          style: theme.typography.body.sm.copyWith(
                            color: theme.colors.app.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: appStyle.spaceLg),
          SizedBox(
            width: double.infinity,
            child: FButton(
              size: FButtonSizeVariant.lg,
              onPress: onRetry,
              child: const Text('重试'),
            ),
          ),
        ],
      ),
    );
  }
}
