import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/asr_preview.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../theme/theme.dart';
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
        final active = {
          RecordingState.starting,
          RecordingState.recording,
          RecordingState.paused,
          RecordingState.finalizing,
        }.contains(widget.viewModel.recordingState);
        return PopScope(
          canPop: !active,
          child: FScaffold(
            header: const FHeader.nested(title: Text('会议录音')),
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
        final status = _RecordingStatusPanel(
          viewModel: widget.viewModel,
          onStop: _stop,
        );
        final transcript = _LiveTranscriptPanel(viewModel: widget.viewModel);
        final content = wide
            ? Row(
                key: const ValueKey('recording-wide-layout'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: status),
                  SizedBox(width: appStyle.spaceLg),
                  Expanded(child: transcript),
                ],
              )
            : Column(
                key: const ValueKey('recording-compact-layout'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  status,
                  SizedBox(height: appStyle.spaceLg),
                  transcript,
                ],
              );
        return SingleChildScrollView(
          padding: EdgeInsets.all(appStyle.spaceMd),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: appStyle.wideContentMaxWidth,
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }

  Future<void> _stop() async {
    final meeting = await widget.viewModel.stop();
    if (meeting != null) {
      widget.onFinished(meeting);
    }
  }
}

final class _RecordingStatusPanel extends StatelessWidget {
  const _RecordingStatusPanel({required this.viewModel, required this.onStop});

  final RecordingSessionViewModel viewModel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(viewModel.meeting.title, style: theme.typography.display.lg),
        SizedBox(height: appStyle.spaceSm),
        Text(
          _durationLabel(viewModel.duration),
          key: const ValueKey('recording-duration'),
          style: theme.typography.display.xl,
        ),
        SizedBox(height: appStyle.spaceMd),
        FAlert(
          title: Text(_recordingLabel(viewModel.recordingState)),
          subtitle: const Text('录音期间不能离开此页面；锁屏或切到后台后录音仍会继续。'),
        ),
        SizedBox(height: appStyle.spaceMd),
        FAlert(
          variant:
              viewModel.previewMetrics.state == AsrPreviewState.recordingOnly
              ? FAlertVariant.destructive
              : FAlertVariant.primary,
          title: Text(_previewLabel(viewModel)),
          subtitle: Text(_previewDescription(viewModel)),
        ),
        if (viewModel.errorMessage case final message?) ...[
          SizedBox(height: appStyle.spaceMd),
          FAlert(variant: FAlertVariant.destructive, title: Text(message)),
        ],
        SizedBox(height: appStyle.spaceLg),
        Wrap(
          spacing: appStyle.spaceSm,
          runSpacing: appStyle.spaceSm,
          children: [
            if (viewModel.recordingState == RecordingState.paused)
              FButton(
                onPress: viewModel.canResume
                    ? () => unawaited(viewModel.resume())
                    : null,
                child: const Text('恢复录音'),
              )
            else
              FButton(
                onPress: viewModel.canPause
                    ? () => unawaited(viewModel.pause())
                    : null,
                child: const Text('暂停录音'),
              ),
            FButton(
              onPress: viewModel.canStop ? onStop : null,
              child: Text(
                viewModel.recordingState == RecordingState.finalizing
                    ? '正在保存…'
                    : '结束会议',
              ),
            ),
          ],
        ),
      ],
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
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('实时转录', style: theme.typography.display.md),
            SizedBox(height: appStyle.spaceMd),
            if (segments.isEmpty)
              Text(
                viewModel.previewMetrics.state == AsrPreviewState.recordingOnly
                    ? '实时转录已停止，事实音频仍在安全写入。'
                    : '等待检测到语音…',
                style: theme.typography.body.md.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              )
            else
              for (final segment in segments) ...[
                Text(
                  '${_timestamp(segment.startMs)}  ${segment.text}',
                  key: ValueKey('transcript-${segment.segmentId}'),
                  style: theme.typography.body.md,
                ),
                SizedBox(height: appStyle.spaceSm),
              ],
          ],
        ),
      ),
    );
  }
}

String _recordingLabel(RecordingState state) => switch (state) {
  RecordingState.idle || RecordingState.starting => '正在启动录音',
  RecordingState.recording => '录音持续进行中',
  RecordingState.paused => '录音已暂停',
  RecordingState.finalizing => '正在封存事实音频',
  RecordingState.completed => '录音已保存',
  RecordingState.failed => '录音失败',
};

String _previewLabel(RecordingSessionViewModel viewModel) {
  if (viewModel.recordingState == RecordingState.paused) {
    return '转录已暂停';
  }
  return switch (viewModel.previewMetrics.state) {
    AsrPreviewState.ready => '实时转录正常',
    AsrPreviewState.backlogged => '实时转录积压',
    AsrPreviewState.recordingOnly => '仅录音模式',
    AsrPreviewState.disposed => '实时转录已结束',
  };
}

String _previewDescription(RecordingSessionViewModel viewModel) =>
    switch (viewModel.previewMetrics.state) {
      AsrPreviewState.ready =>
        '当前积压 ${viewModel.previewMetrics.queuedAudioMs} 毫秒。',
      AsrPreviewState.backlogged =>
        '录音不会受影响，系统正在追赶 '
            '${viewModel.previewMetrics.previewLagMs} 毫秒转录。',
      AsrPreviewState.recordingOnly => '转录失败不会中断录音，结束后仍可基于事实音频重试。',
      AsrPreviewState.disposed => '事实音频已进入最终处理。',
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
