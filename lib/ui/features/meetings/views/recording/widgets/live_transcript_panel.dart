part of '../recording_session_view.dart';

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
