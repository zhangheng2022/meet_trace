// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Impeccable · page: recording-workbench · world: Evidence Ledger
// Composition B: the stable recorder instrument owns the first viewport.
// States: starting · recording · paused · backlogged · recording-only · finalizing · failed

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/asr_preview.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../theme/theme.dart';
import '../../../core/app_back_icon.dart';
import '../../../core/app_page_body.dart';
import '../../../core/app_status_notice.dart';
import '../view_models/recording_session_view_model.dart';
import 'recording_audio_waveform.dart';

final class RecordingSessionView extends StatefulWidget {
  const RecordingSessionView({
    required this.viewModel,
    required this.onFinished,
    super.key,
  });

  final RecordingSessionViewModel viewModel;
  final ValueChanged<Meeting> onFinished;

  @override
  State<RecordingSessionView> createState() => _RecordingSessionViewState();
}

final class _RecordingSessionViewState extends State<RecordingSessionView> {
  bool _endDialogOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.start());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final active =
            _isActive(widget.viewModel.recordingState) ||
            widget.viewModel.canStop;
        return PopScope(
          canPop: !active,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && active) {
              unawaited(_requestEnd());
            }
          },
          child: FScaffold(
            childPad: false,
            header: FHeader.nested(
              title: const Text('会迹'),
              prefixes: [
                FHeaderAction(
                  icon: const AppBackIcon(semanticsLabel: '结束会议并返回'),
                  onPress: active ? () => unawaited(_requestEnd()) : null,
                ),
              ],
            ),
            footer: _RecordingBottomBar(
              viewModel: widget.viewModel,
              onEnd: () => unawaited(_requestEnd()),
            ),
            child: _body(context),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final appStyle = context.theme.style.app;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= appStyle.wideLayoutMinWidth;
        final facts = _RecordingFactsPanel(
          viewModel: widget.viewModel,
          wide: wide,
        );
        final transcript = _LiveTranscriptPanel(
          viewModel: widget.viewModel,
          outlined: wide,
        );
        final content = wide
            ? Row(
                key: const ValueKey('recording-wide-layout'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 8, child: facts),
                  SizedBox(width: appStyle.spaceXl),
                  Expanded(flex: 12, child: transcript),
                ],
              )
            : Column(
                key: const ValueKey('recording-compact-layout'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  facts,
                  SizedBox(height: appStyle.spaceXl),
                  transcript,
                ],
              );
        return SingleChildScrollView(
          child: AppPageBody(width: AppPageWidth.wide, child: content),
        );
      },
    );
  }

  Future<void> _requestEnd() async {
    if (_endDialogOpen ||
        (!_isActive(widget.viewModel.recordingState) &&
            !widget.viewModel.canStop)) {
      return;
    }
    _endDialogOpen = true;
    final confirmed = await showFDialog<bool>(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      builder: (context, style, animation) => FDialog(
        animation: animation,
        semanticsLabel: '结束并保存会议',
        builder: (context, style) {
          final appStyle = context.theme.style.app;
          return Padding(
            padding: EdgeInsets.all(appStyle.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('结束并保存会议？', style: style.titleTextStyle),
                SizedBox(height: appStyle.spaceSm),
                Text(
                  '结束后会先封存本机事实音频，再进入最终转录。当前实时转录仅供预览。',
                  style: context.theme.typography.body.md,
                ),
                SizedBox(height: appStyle.spaceLg),
                FButton(
                  variant: FButtonVariant.outline,
                  size: FButtonSizeVariant.lg,
                  onPress: () => Navigator.of(context).pop(false),
                  child: const Text('继续录音', maxLines: 1),
                ),
                SizedBox(height: appStyle.spaceSm),
                FButton(
                  size: FButtonSizeVariant.lg,
                  autofocus: true,
                  onPress: () => Navigator.of(context).pop(true),
                  child: const Text('结束并保存', maxLines: 1),
                ),
              ],
            ),
          );
        },
      ),
    );
    _endDialogOpen = false;
    if (confirmed == true && mounted) {
      await _stop();
    }
  }

  Future<void> _stop() async {
    final meeting = await widget.viewModel.stop();
    if (meeting != null && mounted) {
      widget.onFinished(meeting);
    }
  }
}

final class _RecordingFactsPanel extends StatelessWidget {
  const _RecordingFactsPanel({required this.viewModel, required this.wide});

  final RecordingSessionViewModel viewModel;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
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
                    _RecordingStateLabel(state: viewModel.recordingState),
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
                  state: switch (viewModel.recordingState) {
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
                  state: viewModel.recordingState,
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

final class _RecordingBottomBar extends StatelessWidget {
  const _RecordingBottomBar({required this.viewModel, required this.onEnd});

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
      child: Text(paused ? '继续' : '暂停', maxLines: 1),
    );
    final endButton = FButton(
      size: FButtonSizeVariant.lg,
      prefix: const Icon(FLucideIcons.square),
      onPress: viewModel.canStop ? onEnd : null,
      child: Text(
        viewModel.recordingState == RecordingState.finalizing ? '正在保存' : '结束会议',
        maxLines: 1,
      ),
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

final class _LiveTranscriptPanel extends StatelessWidget {
  const _LiveTranscriptPanel({required this.viewModel, required this.outlined});

  final RecordingSessionViewModel viewModel;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final segments = viewModel.segments;
    return DecoratedBox(
      key: const ValueKey('live-transcript-ledger'),
      decoration: BoxDecoration(
        color: theme.colors.card,
        border: outlined
            ? Border.all(
                color: theme.colors.app.borderStrong,
                width: appStyle.dividerWidth,
              )
            : null,
        borderRadius: outlined
            ? BorderRadius.circular(appStyle.panelRadius)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colors.border,
                  width: appStyle.dividerWidth,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(appStyle.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('实时转录', style: theme.typography.display.md),
                      ),
                      if (segments.isNotEmpty)
                        Text(
                          '${segments.length} 段',
                          key: const ValueKey('live-transcript-count'),
                          style: theme.typography.body.sm.copyWith(
                            color: theme.colors.mutedForeground,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: appStyle.spaceXs),
                  _PreviewStatusSummary(viewModel: viewModel),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(appStyle.spaceMd),
            child: segments.isEmpty
                ? _LiveTranscriptEmptyState(viewModel: viewModel)
                : Column(
                    children: [
                      for (var index = 0; index < segments.length; index++)
                        _TranscriptRow(
                          segment: segments[index],
                          showDivider: index != segments.length - 1,
                        ),
                    ],
                  ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colors.border,
                  width: appStyle.dividerWidth,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(appStyle.spaceMd),
              child: Row(
                children: [
                  Icon(
                    FLucideIcons.info,
                    size: 17,
                    color: theme.colors.mutedForeground,
                  ),
                  SizedBox(width: appStyle.spaceXs),
                  Expanded(
                    child: Text(
                      '仅供参考，结束后生成最终转录。',
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _LiveTranscriptEmptyState extends StatelessWidget {
  const _LiveTranscriptEmptyState({required this.viewModel});

  final RecordingSessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final stopped =
        viewModel.previewMetrics.state == AsrPreviewState.recordingOnly;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: appStyle.spaceMd),
      child: Text(
        stopped ? '结束后仍会基于完整音频生成最终转录。' : '检测到语音后在这里显示文字。',
        textAlign: TextAlign.center,
        style: theme.typography.body.sm.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
    );
  }
}

final class _TranscriptRow extends StatelessWidget {
  const _TranscriptRow({required this.segment, required this.showDivider});

  final TranscriptSegmentEvent segment;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: theme.colors.border,
                  width: appStyle.dividerWidth,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: appStyle.spaceSm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: appStyle.ledgerTimeColumnWidth + appStyle.spaceXs,
              child: Text(
                _timestamp(segment.startMs),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            SizedBox(width: appStyle.spaceSm),
            Expanded(
              child: Text(
                segment.text,
                key: ValueKey('transcript-${segment.segmentId}'),
                style: theme.typography.body.md,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isActive(RecordingState state) => {
  RecordingState.starting,
  RecordingState.recording,
  RecordingState.paused,
  RecordingState.finalizing,
}.contains(state);

String _recordingShortLabel(RecordingState state) => switch (state) {
  RecordingState.idle || RecordingState.starting => '准备录音',
  RecordingState.recording => '录音中',
  RecordingState.paused => '已暂停',
  RecordingState.finalizing => '正在保存',
  RecordingState.completed => '已保存',
  RecordingState.failed => '录音异常',
};

String _recordingLabel(RecordingState state) => switch (state) {
  RecordingState.idle || RecordingState.starting => '正在启动事实录音',
  RecordingState.recording => '事实音频正在安全写入',
  RecordingState.paused => '事实录音已暂停',
  RecordingState.finalizing => '正在封存事实音频',
  RecordingState.completed => '事实音频已保存',
  RecordingState.failed => '事实录音发生错误',
};

AppStatusTone _previewTone(RecordingSessionViewModel viewModel) {
  if (viewModel.recordingState == RecordingState.paused) {
    return AppStatusTone.info;
  }
  return switch (viewModel.previewMetrics.state) {
    AsrPreviewState.ready || AsrPreviewState.disposed => AppStatusTone.info,
    AsrPreviewState.backlogged ||
    AsrPreviewState.recordingOnly => AppStatusTone.warning,
  };
}

String _previewLabel(RecordingSessionViewModel viewModel) {
  if (viewModel.recordingState == RecordingState.paused) {
    return '实时转录已随录音暂停';
  }
  return switch (viewModel.previewMetrics.state) {
    AsrPreviewState.ready => '实时转录正常',
    AsrPreviewState.backlogged => '实时转录积压，录音仍在继续',
    AsrPreviewState.recordingOnly => '实时转录已停止，录音仍在继续',
    AsrPreviewState.disposed => '实时转录已结束',
  };
}

String _durationLabel(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _timestamp(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours == 0) {
    return '$minutes:$seconds';
  }
  return '${duration.inHours}:$minutes:$seconds';
}
