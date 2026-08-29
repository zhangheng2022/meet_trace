import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/asr_model_registry.dart';
import '../../../../../../domain/models/workflow_states.dart';
import '../../../../../../keys.dart';
import '../../../../../../l10n/l10n.dart';
import '../../../../../../l10n/ui_message_localizations.dart';
import '../../../../../../theme/theme.dart';
import '../../../../../core/app_status_notice.dart';
import '../../../../../core/app_value_formatters.dart';
import '../../../view_models/recording/recording_session_view_model.dart';
import 'recording_audio_waveform.dart';

final class RecordingFactsPanel extends StatelessWidget {
  const RecordingFactsPanel({
    required this.viewModel,
    required this.wide,
    super.key,
  });

  final RecordingSessionViewModel viewModel;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final appStyle = theme.style.app;
    final recordingState = viewModel.isFinalizing
        ? RecordingState.finalizing
        : viewModel.recordingState;
    final model = AsrModelRegistry.alpha.findById(
      viewModel.meeting.recordingModelId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          key: const ValueKey('recording-control-console'),
          decoration: BoxDecoration(
            color: theme.colors.card,
            border: Border.all(
              color: theme.colors.app.borderStrong,
              width: appStyle.dividerWidth,
            ),
            borderRadius: BorderRadius.circular(appStyle.panelRadius),
          ),
          child: Padding(
            padding: EdgeInsets.all(wide ? appStyle.spaceLg : appStyle.spaceSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RecordingStateLabel(state: recordingState),
                SizedBox(height: wide ? appStyle.spaceLg : appStyle.spaceSm),
                ValueListenableBuilder<Duration>(
                  valueListenable: viewModel.durationListenable,
                  builder: (context, duration, _) => Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatClockDuration(duration, alwaysShowHours: true),
                        key: keys.meetings.recordingElapsedDuration,
                        style:
                            (wide
                                    ? theme.typography.display.xl4
                                    : theme.typography.body.xl4)
                                .copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: wide ? appStyle.spaceMd : appStyle.spaceSm),
                ValueListenableBuilder<List<double>>(
                  valueListenable: viewModel.audioLevelsListenable,
                  builder: (context, levels, _) => RecordingAudioWaveform(
                    levels: levels,
                    height: wide ? 64 : 52,
                    state: switch (recordingState) {
                      RecordingState.idle || RecordingState.starting =>
                        RecordingAudioWaveformState.waiting,
                      RecordingState.recording =>
                        RecordingAudioWaveformState.live,
                      RecordingState.recovering || RecordingState.interrupted =>
                        RecordingAudioWaveformState.stopped,
                      RecordingState.paused =>
                        RecordingAudioWaveformState.paused,
                      RecordingState.finalizing ||
                      RecordingState.completed ||
                      RecordingState.failed =>
                        RecordingAudioWaveformState.stopped,
                    },
                  ),
                ),
                SizedBox(height: wide ? appStyle.spaceLg : appStyle.spaceMd),
                _RecordingFactLedger(
                  state: recordingState,
                  modelName:
                      model?.displayName ?? l10n.meetingLockedModelFallback,
                  spacing: wide ? appStyle.spaceSm : appStyle.spaceXs,
                ),
                if (viewModel.errorMessage case final message?) ...[
                  SizedBox(height: appStyle.spaceMd),
                  AppStatusNotice(
                    tone: AppStatusTone.error,
                    title: l10n.localizeUiMessage(message),
                    message: l10n.recordingErrorGuidance,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _RecordingStateLabel extends StatelessWidget {
  const _RecordingStateLabel({required this.state});

  final RecordingState state;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          state == RecordingState.paused
              ? FLucideIcons.pause
              : FLucideIcons.square,
          size: 18,
        ),
        SizedBox(width: appStyle.spaceXs),
        Text(
          _recordingShortLabel(context.l10n, state),
          style: theme.typography.body.md.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

final class _RecordingFactLedger extends StatelessWidget {
  const _RecordingFactLedger({
    required this.state,
    required this.modelName,
    required this.spacing,
  });

  final RecordingState state;
  final String modelName;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('recording-fact-ledger'),
      child: Column(
        children: [
          _RecordingFactRow(
            icon: FLucideIcons.archive,
            label: _recordingLabel(context.l10n, state),
            emphasized: true,
          ),
          SizedBox(height: spacing),
          _RecordingFactRow(
            icon: FLucideIcons.lockKeyhole,
            label: context.l10n.meetingModelLocked(modelName),
          ),
        ],
      ),
    );
  }
}

final class _RecordingFactRow extends StatelessWidget {
  const _RecordingFactRow({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: emphasized ? null : theme.colors.mutedForeground,
        ),
        SizedBox(width: appStyle.spaceXs),
        Expanded(
          child: Text(
            label,
            style: theme.typography.body.sm.copyWith(
              color: emphasized ? null : theme.colors.mutedForeground,
              fontWeight: emphasized ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}

String _recordingShortLabel(AppLocalizations l10n, RecordingState state) =>
    switch (state) {
      RecordingState.idle ||
      RecordingState.starting => l10n.recordingStatePreparing,
      RecordingState.recording => l10n.meetingStatusRecording,
      RecordingState.recovering => l10n.recordingStateRecovering,
      RecordingState.interrupted => l10n.recordingStateInterrupted,
      RecordingState.paused => l10n.recordingStatePaused,
      RecordingState.finalizing => l10n.recordingStateSaving,
      RecordingState.completed => l10n.recordingStateSaved,
      RecordingState.failed => l10n.recordingStateError,
    };

String _recordingLabel(AppLocalizations l10n, RecordingState state) =>
    switch (state) {
      RecordingState.idle ||
      RecordingState.starting => l10n.recordingFactStarting,
      RecordingState.recording => l10n.recordingFactWriting,
      RecordingState.recovering => l10n.recordingFactRecovering,
      RecordingState.interrupted => l10n.recordingFactInterrupted,
      RecordingState.paused => l10n.recordingFactPaused,
      RecordingState.finalizing => l10n.recordingFactSealing,
      RecordingState.completed => l10n.recordingFactSaved,
      RecordingState.failed => l10n.recordingFactError,
    };
