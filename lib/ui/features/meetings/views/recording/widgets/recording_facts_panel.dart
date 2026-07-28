part of '../recording_session_view.dart';

final class _RecordingFactsPanel extends StatelessWidget {
  const _RecordingFactsPanel({required this.viewModel, required this.wide});

  final RecordingSessionViewModel viewModel;
  final bool wide;

  @override
  Widget build(BuildContext context) {
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
            padding: EdgeInsets.all(wide ? appStyle.spaceLg : appStyle.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: appStyle.spaceSm,
                  runSpacing: appStyle.spaceXs,
                  children: [
                    _RecordingStateLabel(state: recordingState),
                    Text(
                      viewModel.meeting.title,
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: appStyle.spaceLg),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _durationLabel(viewModel.duration),
                      key: const ValueKey('recording-duration'),
                      style: theme.typography.display.xl4.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: appStyle.spaceMd),
                RecordingAudioWaveform(
                  levels: viewModel.audioLevels,
                  state: switch (recordingState) {
                    RecordingState.idle || RecordingState.starting =>
                      RecordingAudioWaveformState.waiting,
                    RecordingState.recording =>
                      RecordingAudioWaveformState.live,
                    RecordingState.paused => RecordingAudioWaveformState.paused,
                    RecordingState.finalizing ||
                    RecordingState.completed ||
                    RecordingState.failed =>
                      RecordingAudioWaveformState.stopped,
                  },
                ),
                SizedBox(height: appStyle.spaceLg),
                _RecordingFactLedger(
                  state: recordingState,
                  modelName: model?.displayName ?? '本场模型',
                ),
                if (viewModel.errorMessage case final message?) ...[
                  SizedBox(height: appStyle.spaceMd),
                  AppStatusNotice(
                    tone: AppStatusTone.error,
                    title: message,
                    message: '请保留应用数据，并按当前可用操作继续。事实音频状态以上方提示为准。',
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
          _recordingShortLabel(state),
          style: theme.typography.body.md.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

final class _RecordingFactLedger extends StatelessWidget {
  const _RecordingFactLedger({required this.state, required this.modelName});

  final RecordingState state;
  final String modelName;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return KeyedSubtree(
      key: const ValueKey('recording-fact-ledger'),
      child: Column(
        children: [
          _RecordingFactRow(
            icon: FLucideIcons.archive,
            label: _recordingLabel(state),
            emphasized: true,
          ),
          SizedBox(height: appStyle.spaceSm),
          _RecordingFactRow(
            icon: FLucideIcons.lockKeyhole,
            label: '$modelName · 本场锁定',
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

final class _PreviewStatusSummary extends StatelessWidget {
  const _PreviewStatusSummary({required this.viewModel});

  final RecordingSessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          _previewTone(viewModel) == AppStatusTone.warning
              ? FLucideIcons.triangleAlert
              : FLucideIcons.radio,
          size: 18,
        ),
        SizedBox(width: appStyle.spaceXs),
        Expanded(
          child: Text(
            _previewLabel(viewModel),
            style: theme.typography.body.sm.copyWith(
              color: _previewTone(viewModel) == AppStatusTone.warning
                  ? null
                  : theme.colors.mutedForeground,
              fontWeight: _previewTone(viewModel) == AppStatusTone.warning
                  ? FontWeight.w600
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
