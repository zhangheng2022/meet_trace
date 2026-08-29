// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Impeccable · page: startup · world: Evidence Ledger
// THESIS: startup is a short, trustworthy local preparation state, not a blank
// app shell or a decorative brand animation.
// STORY: identify MeetTrace, then explain the real local preparation work.

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/runtime_initialization.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/ui_message_localizations.dart';
import '../../../../theme/theme.dart';
import '../../../core/app_responsive.dart';
import '../../../core/branding/meettrace_brand_mark.dart';
import '../view_models/runtime_initialization_view_model.dart';

/// 会迹的本地能力加载页。
final class MeetTraceStartupView extends StatelessWidget {
  const MeetTraceStartupView({
    this.viewModel,
    this.onBrandMotionCompleted,
    super.key,
  });

  final RuntimeInitializationViewModel? viewModel;
  final VoidCallback? onBrandMotionCompleted;

  @override
  Widget build(BuildContext context) {
    final model = viewModel;
    if (model == null) {
      return _StartupFrame(
        body: _StartupProgressContent(
          onBrandMotionCompleted: onBrandMotionCompleted,
        ),
      );
    }
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => _StartupFrame(
        body: _StartupProgressContent(
          viewModel: model,
          onBrandMotionCompleted: onBrandMotionCompleted,
        ),
      ),
    );
  }
}

/// 在快速本地检查、资源准备和应用首页之间提供平滑过渡。
final class MeetTraceRuntimeInitializationTransition extends StatefulWidget {
  const MeetTraceRuntimeInitializationTransition({
    required this.viewModel,
    required this.ready,
    super.key,
  });

  final RuntimeInitializationViewModel viewModel;
  final Widget ready;

  @override
  State<MeetTraceRuntimeInitializationTransition> createState() =>
      _MeetTraceRuntimeInitializationTransitionState();
}

final class _MeetTraceRuntimeInitializationTransitionState
    extends State<MeetTraceRuntimeInitializationTransition> {
  bool _brandMotionCompleted = false;

  @override
  void didUpdateWidget(MeetTraceRuntimeInitializationTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      _brandMotionCompleted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final phase = widget.viewModel.state.phase;
        final canEnterReady =
            phase == RuntimeInitializationPhase.ready && _brandMotionCompleted;
        final child = canEnterReady
            ? KeyedSubtree(
                key: const ValueKey('runtime-initialization-ready'),
                child: widget.ready,
              )
            : KeyedSubtree(
                key: const ValueKey('runtime-initialization-progress'),
                child: MeetTraceStartupView(
                  key: ObjectKey(widget.viewModel),
                  viewModel: widget.viewModel,
                  onBrandMotionCompleted: _handleBrandMotionCompleted,
                ),
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

  void _handleBrandMotionCompleted() {
    if (!_brandMotionCompleted && mounted) {
      setState(() => _brandMotionCompleted = true);
    }
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
      lead: context.l10n.startupStoppedForData,
      title: context.l10n.cannotReadLocalData,
      message: context.l10n.cleanupNotRun,
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
      lead: context.l10n.localInitializationIncomplete,
      title: context.l10n.localCapabilitiesNotReady,
      message: context.l10n.ensureStorageRetry,
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
  const _StartupProgressContent({this.viewModel, this.onBrandMotionCompleted});

  final RuntimeInitializationViewModel? viewModel;
  final VoidCallback? onBrandMotionCompleted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final appStyle = theme.style.app;
    final model = viewModel;
    final state = model?.state;
    final stage = _stageForProgress(l10n, state);
    final percentage = state == null ? 0 : _progressPercentage(state);
    final description = state?.message == null
        ? stage.description
        : l10n.localizeRuntimeMessage(state!.messageCode, state.message!);
    return Semantics(
      container: true,
      label: l10n.preparingMeetTraceStage(stage.title),
      child: Column(
        key: const ValueKey('meettrace-startup-progress-content'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MeetTraceAnimatedWordmark(onCompleted: onBrandMotionCompleted),
          SizedBox(height: appStyle.spaceXl),
          Text(l10n.preparingMeetTrace, style: theme.typography.display.md),
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
                              l10n.stepOfFour(stage.step),
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
                            l10n.localizeRuntimeResourceName(
                              state.resourceName,
                            ),
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
                      semanticsLabel: l10n.offlineResourcePreparationProgress,
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
            l10n.localEvidencePreserved,
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
                  child: Text(l10n.agreeAndDownload),
                ),
                SizedBox(height: appStyle.spaceSm),
                FButton(
                  key: const ValueKey('decline-mobile-download'),
                  variant: FButtonVariant.outline,
                  size: FButtonSizeVariant.lg,
                  onPress: model?.declineMobileDownload,
                  child: Text(l10n.avoidMobileNetwork),
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
                child: Text(l10n.pauseDownload),
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
                      ? l10n.continueDownload
                      : l10n.retry,
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
_stageForProgress(
  AppLocalizations l10n,
  RuntimeInitializationProgress? state,
) => state == null
    ? (
        title: l10n.openLocalWorkspace,
        description: l10n.openLocalWorkspaceDescription,
        step: 1,
        icon: FLucideIcons.fileAudio,
        active: true,
      )
    : _stageFor(l10n, state.phase);

({String title, String description, int step, IconData icon, bool active})
_stageFor(AppLocalizations l10n, RuntimeInitializationPhase phase) =>
    switch (phase) {
      RuntimeInitializationPhase.checking => (
        title: l10n.checkOfflineResources,
        description: l10n.checkOfflineResourcesDescription,
        step: 2,
        icon: FLucideIcons.fileAudio,
        active: true,
      ),
      RuntimeInitializationPhase.awaitingMobileConsent => (
        title: l10n.awaitNetworkConfirmation,
        description: l10n.awaitNetworkConfirmationDescription,
        step: 2,
        icon: FLucideIcons.triangleAlert,
        active: false,
      ),
      RuntimeInitializationPhase.insufficientSpace => (
        title: l10n.freeDeviceSpace,
        description: l10n.freeDeviceSpaceDescription,
        step: 2,
        icon: FLucideIcons.circleAlert,
        active: false,
      ),
      RuntimeInitializationPhase.downloading => (
        title: l10n.downloadOfflineResources,
        description: l10n.downloadOfflineResourcesDescription,
        step: 2,
        icon: FLucideIcons.fileAudio,
        active: false,
      ),
      RuntimeInitializationPhase.paused => (
        title: l10n.downloadPaused,
        description: l10n.downloadPausedDescription,
        step: 2,
        icon: FLucideIcons.pause,
        active: false,
      ),
      RuntimeInitializationPhase.verifying => (
        title: l10n.verifyResourceIntegrity,
        description: l10n.verifyResourceIntegrityDescription,
        step: 3,
        icon: FLucideIcons.shieldCheck,
        active: true,
      ),
      RuntimeInitializationPhase.activating => (
        title: l10n.enableOfflineTranscription,
        description: l10n.enableOfflineTranscriptionDescription,
        step: 4,
        icon: FLucideIcons.fileAudio,
        active: true,
      ),
      RuntimeInitializationPhase.failed => (
        title: l10n.resourcePreparationIncomplete,
        description: l10n.resourcePreparationIncompleteDescription,
        step: 2,
        icon: FLucideIcons.circleAlert,
        active: false,
      ),
      RuntimeInitializationPhase.ready => (
        title: l10n.offlineTranscriptionReady,
        description: l10n.offlineTranscriptionReadyDescription,
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
      label: context.l10n.startupLocalCapabilitiesIncomplete,
      child: Column(
        key: const ValueKey('meettrace-startup-error'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MeetTraceAnimatedWordmark(),
          SizedBox(height: appStyle.spaceXl),
          Text(
            context.l10n.startupNeedsAttention,
            style: theme.typography.display.md,
          ),
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
              child: Text(context.l10n.retry),
            ),
          ),
        ],
      ),
    );
  }
}
