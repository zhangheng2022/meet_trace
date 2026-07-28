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
import '../../../core/app_ledger.dart';
import '../../../core/app_page_body.dart';
import '../../../core/app_status_notice.dart';
import '../view_models/recording_session_view_model.dart';

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
          onEnd: () => unawaited(_requestEnd()),
          wide: wide,
        );
        final transcript = _LiveTranscriptPanel(viewModel: widget.viewModel);
        final content = wide
            ? Row(
                key: const ValueKey('recording-wide-layout'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 9, child: facts),
                  SizedBox(width: appStyle.spaceXl),
                  Expanded(flex: 11, child: transcript),
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
  const _RecordingFactsPanel({
    required this.viewModel,
    required this.onEnd,
    required this.wide,
  });

  final RecordingSessionViewModel viewModel;
  final VoidCallback onEnd;
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
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: appStyle.spaceSm,
          runSpacing: appStyle.space2Xs,
          children: [
            Text('录音', style: theme.typography.display.md),
            Text(
              viewModel.meeting.title,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
        SizedBox(height: appStyle.spaceSm),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '实时转录仅供参考',
                          style: theme.typography.body.xs.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                        SizedBox(width: appStyle.space2Xs),
                        Icon(
                          FLucideIcons.info,
                          size: 16,
                          color: theme.colors.mutedForeground,
                        ),
                      ],
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
                SizedBox(height: appStyle.space2Xs),
                const _DurationUnits(),
                SizedBox(height: appStyle.spaceMd),
                AppTimeRuler(elapsed: viewModel.duration),
                SizedBox(height: appStyle.space2Xs),
                _TimeRulerLabels(elapsed: viewModel.duration),
                SizedBox(height: appStyle.spaceLg),
                _AudioFactRow(
                  state: viewModel.recordingState,
                  modelName: model?.displayName ?? '本场模型',
                ),
                SizedBox(height: appStyle.spaceSm),
                _PreviewStatusRow(viewModel: viewModel),
                if (viewModel.errorMessage case final message?) ...[
                  SizedBox(height: appStyle.spaceMd),
                  AppStatusNotice(
                    tone: AppStatusTone.error,
                    title: message,
                    message: '请保留应用数据，并按当前可用操作继续。事实音频状态以上方提示为准。',
                  ),
                ],
                SizedBox(height: appStyle.spaceLg),
                _RecordingActions(viewModel: viewModel, onEnd: onEnd),
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

final class _DurationUnits extends StatelessWidget {
  const _DurationUnits();

  @override
  Widget build(BuildContext context) {
    final style = context.theme.typography.body.xs.copyWith(
      color: context.theme.colors.mutedForeground,
    );
    return Row(
      children: [
        for (final unit in const ['时', '分', '秒'])
          Expanded(
            child: Text(unit, textAlign: TextAlign.center, style: style),
          ),
      ],
    );
  }
}

final class _TimeRulerLabels extends StatelessWidget {
  const _TimeRulerLabels({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final startSeconds = (elapsed.inSeconds - 15).clamp(0, 1 << 30);
    final style = context.theme.typography.body.xs.copyWith(
      color: context.theme.colors.mutedForeground,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
        final compactLabels = largeText || constraints.maxWidth < 300;
        final offsets = compactLabels
            ? const [0, 30]
            : constraints.maxWidth < 430
            ? const [0, 15, 30]
            : const [0, 10, 20, 30];
        return Row(
          children: [
            for (var index = 0; index < offsets.length; index++)
              Expanded(
                child: Align(
                  alignment: switch (index) {
                    0 => Alignment.centerLeft,
                    _ when index == offsets.length - 1 => Alignment.centerRight,
                    _ => Alignment.center,
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _rulerLabel(
                        Duration(seconds: startSeconds + offsets[index]),
                        compact: compactLabels,
                      ),
                      maxLines: 1,
                      style: style,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _AudioFactRow extends StatelessWidget {
  const _AudioFactRow({required this.state, required this.modelName});

  final RecordingState state;
  final String modelName;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colors.border,
          width: appStyle.dividerWidth,
        ),
        borderRadius: BorderRadius.circular(appStyle.cardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceSm),
        child: Row(
          children: [
            const Icon(FLucideIcons.archive, size: 20),
            SizedBox(width: appStyle.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recordingLabel(state),
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: appStyle.space2Xs),
                  Text(
                    '本地存储 · 单一事实来源\n$modelName · 本场已锁定',
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PreviewStatusRow extends StatelessWidget {
  const _PreviewStatusRow({required this.viewModel});

  final RecordingSessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _previewTone(viewModel) == AppStatusTone.warning
              ? FLucideIcons.triangleAlert
              : FLucideIcons.info,
          size: 17,
          color: theme.colors.mutedForeground,
        ),
        SizedBox(width: appStyle.spaceXs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_previewLabel(viewModel), style: theme.typography.body.sm),
              SizedBox(height: appStyle.space2Xs),
              Text(
                _previewDescription(viewModel),
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
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
  const _LiveTranscriptPanel({required this.viewModel});

  final RecordingSessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final segments = viewModel.segments;
    return DecoratedBox(
      key: const ValueKey('live-transcript-ledger'),
      decoration: BoxDecoration(
        color: theme.colors.card,
        border: Border.all(
          color: theme.colors.app.borderStrong,
          width: appStyle.dividerWidth,
        ),
        borderRadius: BorderRadius.circular(appStyle.panelRadius),
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
              child: Row(
                children: [
                  Expanded(
                    child: Text('实时转录', style: theme.typography.display.md),
                  ),
                  Text(
                    '仅供参考',
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(appStyle.spaceMd),
            child: segments.isEmpty
                ? Text(
                    viewModel.previewMetrics.state ==
                            AsrPreviewState.recordingOnly
                        ? '实时转录已停止，录音仍在继续。'
                        : '等待检测到语音…',
                    style: theme.typography.body.md.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  )
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
                      '实时转录仅供参考，结束后基于本场锁定模型生成最终转录。',
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
              width: appStyle.ledgerTimeColumnWidth,
              child: Text(
                _timestamp(segment.startMs),
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

String _previewDescription(RecordingSessionViewModel viewModel) =>
    switch (viewModel.previewMetrics.state) {
      AsrPreviewState.ready =>
        viewModel.previewMetrics.queuedAudioMs == 0
            ? '当前没有待处理音频。'
            : '当前待处理 ${viewModel.previewMetrics.queuedAudioMs} 毫秒音频。',
      AsrPreviewState.backlogged =>
        '事实音频不受影响，系统正在追赶 '
            '${viewModel.previewMetrics.previewLagMs} 毫秒转录。',
      AsrPreviewState.recordingOnly => '事实音频仍在安全写入；结束后可基于完整音频继续处理。',
      AsrPreviewState.disposed => '事实音频将进入最终处理。',
    };

String _durationLabel(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _timestamp(int milliseconds) {
  return _durationLabel(Duration(milliseconds: milliseconds));
}

String _rulerLabel(Duration value, {required bool compact}) {
  if (!compact) {
    return _durationLabel(value);
  }
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
