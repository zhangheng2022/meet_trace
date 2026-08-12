import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/workflow_states.dart';
import '../../../../../../keys.dart';
import '../../../../../../theme/theme.dart';
import '../../../view_models/recording/recording_session_view_model.dart';

final class RecordingBottomBar extends StatelessWidget {
  const RecordingBottomBar({
    required this.viewModel,
    required this.onEnd,
    super.key,
  });

  final RecordingSessionViewModel viewModel;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(color: theme.colors.card),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            appStyle.spaceMd,
            appStyle.spaceSm,
            appStyle.spaceMd,
            appStyle.spaceMd,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: appStyle.wideContentMaxWidth,
              ),
              child: SizedBox(
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final actions = KeyedSubtree(
                      key: const ValueKey('recording-bottom-actions'),
                      child: _RecordingActions(
                        viewModel: viewModel,
                        onEnd: onEnd,
                      ),
                    );
                    if (constraints.maxWidth < appStyle.wideLayoutMinWidth) {
                      return actions;
                    }
                    return Row(
                      children: [
                        const Spacer(),
                        SizedBox(
                          width: appStyle.factRailWidth + appStyle.spaceXl,
                          child: actions,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _RecordingActions extends StatelessWidget {
  const _RecordingActions({required this.viewModel, required this.onEnd});

  final RecordingSessionViewModel viewModel;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    final paused = viewModel.recordingState == RecordingState.paused;
    final pauseButton = FButton(
      variant: FButtonVariant.outline,
      size: FButtonSizeVariant.lg,
      prefix: Icon(paused ? FLucideIcons.mic : FLucideIcons.pause),
      onPress: paused
          ? (viewModel.canResume ? () => unawaited(viewModel.resume()) : null)
          : (viewModel.canPause ? () => unawaited(viewModel.pause()) : null),
      child: KeyedSubtree(
        key: paused
            ? (viewModel.canResume ? keys.meetings.recordingResumeReady : null)
            : (viewModel.canPause ? keys.meetings.recordingPauseReady : null),
        child: Text(paused ? '继续' : '暂停', maxLines: 1),
      ),
    );
    final endButton = _RecordingEndButton(
      finalizing: viewModel.isFinalizing,
      enabled: viewModel.canStop,
      onEnd: onEnd,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
        if (constraints.maxWidth < appStyle.dualActionMinWidth || largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pauseButton,
              SizedBox(height: appStyle.spaceSm),
              endButton,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: pauseButton),
            SizedBox(width: appStyle.spaceSm),
            Expanded(child: endButton),
          ],
        );
      },
    );
  }
}

final class _RecordingEndButton extends StatelessWidget {
  const _RecordingEndButton({
    required this.finalizing,
    required this.enabled,
    required this.onEnd,
  });

  final bool finalizing;
  final bool enabled;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return FButton(
      key: keys.meetings.recordingEndButton,
      size: FButtonSizeVariant.lg,
      onPress: enabled && !finalizing ? onEnd : null,
      child: KeyedSubtree(
        key: enabled && !finalizing ? keys.meetings.recordingEndReady : null,
        child: _RecordingEndButtonContent(finalizing: finalizing),
      ),
    );
  }
}

final class _RecordingEndButtonContent extends StatelessWidget {
  const _RecordingEndButtonContent({required this.finalizing});

  final bool finalizing;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 160),
      reverseDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 100),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Row(
        key: ValueKey(
          finalizing ? 'recording-end-finalizing' : 'recording-end-available',
        ),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (finalizing)
            ExcludeSemantics(
              child: FCircularProgress(
                size: FCircularProgressSizeVariant.lg,
                style: FCircularProgressStyleDelta.delta(
                  iconStyle: IconThemeDataDelta.delta(
                    color: IconTheme.of(context).color,
                  ),
                ),
              ),
            )
          else
            const Icon(FLucideIcons.square),
          SizedBox(width: appStyle.spaceSm),
          Text(finalizing ? '正在封存音频' : '结束会议', maxLines: 1),
        ],
      ),
    );
  }
}
