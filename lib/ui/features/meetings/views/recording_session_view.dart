// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · page: recording-workbench · macrostructure: Workbench · theme: Cobalt
// States: starting · recording · paused · backlogged · recording-only · finalizing · failed

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/asr_preview.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../theme/theme.dart';
import '../../../core/app_bottom_action_bar.dart';
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
        final active = _isActive(widget.viewModel.recordingState);
        return PopScope(
          canPop: !active,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && active) {
              unawaited(_requestEnd());
            }
          },
          child: FScaffold(
            header: FHeader.nested(
              title: const Text('会议录音'),
              prefixes: [
                FHeaderAction.back(
                  semanticsLabel: '结束会议并返回',
                  onPress: active ? () => unawaited(_requestEnd()) : null,
                ),
              ],
            ),
            footer: active
                ? _RecordingActionBar(
                    viewModel: widget.viewModel,
                    onEnd: () => unawaited(_requestEnd()),
                  )
                : null,
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
        final facts = _RecordingFactsPanel(viewModel: widget.viewModel);
        final transcript = _LiveTranscriptPanel(viewModel: widget.viewModel);
        final content = wide
            ? Row(
                key: const ValueKey('recording-wide-layout'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: facts),
                  SizedBox(width: appStyle.spaceXl),
                  Expanded(child: transcript),
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
    if (_endDialogOpen || !_isActive(widget.viewModel.recordingState)) {
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
  const _RecordingFactsPanel({required this.viewModel});

  final RecordingSessionViewModel viewModel;

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
        Text(viewModel.meeting.title, style: theme.typography.display.lg),
        SizedBox(height: appStyle.spaceMd),
        Text(
          _durationLabel(viewModel.duration),
          key: const ValueKey('recording-duration'),
          style: theme.typography.display.xl.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        SizedBox(height: appStyle.spaceXs),
        Row(
          children: [
            Icon(FLucideIcons.lockKeyhole, color: theme.colors.mutedForeground),
            SizedBox(width: appStyle.spaceXs),
            Expanded(
              child: Text(
                '${model?.displayName ?? '本场模型'} · 本场已锁定',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: appStyle.spaceLg),
        AppStatusNotice(
          tone: _recordingTone(viewModel.recordingState),
          title: _recordingLabel(viewModel.recordingState),
          message: _recordingDescription(viewModel.recordingState),
        ),
        SizedBox(height: appStyle.spaceMd),
        AppStatusNotice(
          tone: _previewTone(viewModel),
          title: _previewLabel(viewModel),
          message: _previewDescription(viewModel),
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
    );
  }
}

final class _RecordingActionBar extends StatelessWidget {
  const _RecordingActionBar({required this.viewModel, required this.onEnd});

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
      child: Text(paused ? '恢复录音' : '暂停录音', maxLines: 1),
    );
    final endButton = FButton(
      size: FButtonSizeVariant.lg,
      prefix: const Icon(FLucideIcons.square),
      onPress: viewModel.canStop ? onEnd : null,
      child: Text(
        viewModel.recordingState == RecordingState.finalizing
            ? '正在保存'
            : '结束并保存',
        maxLines: 1,
      ),
    );
    return AppBottomActionBar(
      width: AppPageWidth.wide,
      supportingText: paused
          ? '录音已暂停；恢复后继续写入同一份事实音频。'
          : '结束前录音会持续写入本机；实时转录变慢不会影响事实音频。',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < appStyle.mediumLayoutMinWidth) {
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
      ),
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
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('实时转录', style: theme.typography.display.md),
            SizedBox(height: appStyle.spaceXs),
            Text(
              '仅供会中参考，结束后会基于本场锁定模型生成最终转录。',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            SizedBox(height: appStyle.spaceLg),
            if (segments.isEmpty)
              Text(
                viewModel.previewMetrics.state == AsrPreviewState.recordingOnly
                    ? '实时转录已停止，录音仍在继续。'
                    : '等待检测到语音…',
                style: theme.typography.body.md.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              )
            else
              for (final segment in segments) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: appStyle.space2Xl,
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
                SizedBox(height: appStyle.spaceMd),
              ],
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

AppStatusTone _recordingTone(RecordingState state) => switch (state) {
  RecordingState.recording => AppStatusTone.recording,
  RecordingState.paused => AppStatusTone.warning,
  RecordingState.completed => AppStatusTone.success,
  RecordingState.failed => AppStatusTone.error,
  RecordingState.idle ||
  RecordingState.starting ||
  RecordingState.finalizing => AppStatusTone.info,
};

String _recordingLabel(RecordingState state) => switch (state) {
  RecordingState.idle || RecordingState.starting => '正在启动事实录音',
  RecordingState.recording => '事实音频正在安全写入',
  RecordingState.paused => '事实录音已暂停',
  RecordingState.finalizing => '正在封存事实音频',
  RecordingState.completed => '事实音频已保存',
  RecordingState.failed => '事实录音发生错误',
};

String _recordingDescription(RecordingState state) => switch (state) {
  RecordingState.idle || RecordingState.starting => '正在检查并启动本机音频写入。',
  RecordingState.recording => '锁屏或切到后台后录音仍会继续。',
  RecordingState.paused => '当前没有写入新音频；已有事实音频仍保存在本机。',
  RecordingState.finalizing => '正在完成本机写入，完成前请勿关闭应用。',
  RecordingState.completed => '本机事实音频已完成封存。',
  RecordingState.failed => '请保留应用数据并按错误提示处理。',
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
  final value = Duration(milliseconds: milliseconds);
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
