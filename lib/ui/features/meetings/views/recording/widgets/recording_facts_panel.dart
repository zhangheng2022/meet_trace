import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/asr_model_registry.dart';
import '../../../../../../domain/models/workflow_states.dart';
import '../../../../../../keys.dart';
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
                  modelName: model?.displayName ?? '本场模型',
                  spacing: wide ? appStyle.spaceSm : appStyle.spaceXs,
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
            label: _recordingLabel(state),
            emphasized: true,
          ),
          SizedBox(height: spacing),
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

String _recordingShortLabel(RecordingState state) => switch (state) {
  RecordingState.idle || RecordingState.starting => '准备录音',
  RecordingState.recording => '录音中',
  RecordingState.recovering => '正在恢复',
  RecordingState.interrupted => '录音已中断',
  RecordingState.paused => '已暂停',
  RecordingState.finalizing => '正在保存',
  RecordingState.completed => '已保存',
  RecordingState.failed => '录音异常',
};

String _recordingLabel(RecordingState state) => switch (state) {
  RecordingState.idle || RecordingState.starting => '正在启动事实录音',
  RecordingState.recording => '事实音频正在安全写入',
  RecordingState.recovering => '输入中断，正在切换系统默认麦克风',
  RecordingState.interrupted => '事实录音已中断，可结束会议以保存已有音频',
  RecordingState.paused => '事实录音已暂停',
  RecordingState.finalizing => '正在封存事实音频',
  RecordingState.completed => '事实音频已保存',
  RecordingState.failed => '事实录音发生错误',
};
