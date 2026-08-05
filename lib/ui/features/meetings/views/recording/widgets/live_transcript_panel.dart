import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/asr_preview.dart';
import '../../../../../../domain/models/transcript.dart';
import '../../../../../../domain/models/workflow_states.dart';
import '../../../../../../theme/theme.dart';
import '../../../../../core/app_status_notice.dart';
import '../../../view_models/recording/recording_session_view_model.dart';

final class LiveTranscriptPanel extends StatelessWidget {
  const LiveTranscriptPanel({
    required this.viewModel,
    required this.outlined,
    super.key,
  });

  final RecordingSessionViewModel viewModel;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final segments = viewModel.segments;
    final displaySegments = segments.reversed.toList(growable: false);
    final sectionPadding = outlined ? appStyle.spaceMd : appStyle.spaceSm;
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
              padding: EdgeInsets.all(sectionPadding),
              child: Semantics(
                key: const ValueKey('live-transcript-heading'),
                container: true,
                header: true,
                label: [
                  '实时转录',
                  _previewLabel(viewModel),
                  if (segments.isNotEmpty) '${segments.length} 段',
                ].join('，'),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Text('实时转录', style: theme.typography.display.md),
                      SizedBox(width: appStyle.spaceSm),
                      Expanded(
                        child: _PreviewStatusOverview(viewModel: viewModel),
                      ),
                      if (segments.isNotEmpty) ...[
                        SizedBox(width: appStyle.spaceSm),
                        Text(
                          '${segments.length} 段',
                          key: const ValueKey('live-transcript-count'),
                          style: theme.typography.body.sm.copyWith(
                            color: theme.colors.mutedForeground,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(sectionPadding),
            child: segments.isEmpty
                ? _LiveTranscriptEmptyState(
                    viewModel: viewModel,
                    compact: !outlined,
                  )
                : Column(
                    children: [
                      for (
                        var index = 0;
                        index < displaySegments.length;
                        index++
                      )
                        _TranscriptRow(
                          segment: displaySegments[index],
                          showDivider: index != displaySegments.length - 1,
                          compact: !outlined,
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
              padding: EdgeInsets.all(sectionPadding),
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
  const _LiveTranscriptEmptyState({
    required this.viewModel,
    required this.compact,
  });

  final RecordingSessionViewModel viewModel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final stopped =
        viewModel.previewMetrics.state == AsrPreviewState.recordingOnly;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? appStyle.spaceXs : appStyle.spaceMd,
      ),
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

final class _PreviewStatusOverview extends StatelessWidget {
  const _PreviewStatusOverview({required this.viewModel});

  final RecordingSessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final warning = _previewTone(viewModel) == AppStatusTone.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          warning ? FLucideIcons.triangleAlert : FLucideIcons.radio,
          size: 18,
        ),
        SizedBox(width: appStyle.spaceXs),
        Expanded(
          child: Text(
            _previewLabel(viewModel),
            style: theme.typography.body.sm.copyWith(
              color: warning ? null : theme.colors.mutedForeground,
              fontWeight: warning ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}

final class _TranscriptRow extends StatelessWidget {
  const _TranscriptRow({
    required this.segment,
    required this.showDivider,
    required this.compact,
  });

  final TranscriptSegmentEvent segment;
  final bool showDivider;
  final bool compact;

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
        padding: EdgeInsets.symmetric(
          vertical: compact ? appStyle.spaceXs : appStyle.spaceSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width:
                  appStyle.ledgerTimeColumnWidth +
                  (compact ? 0 : appStyle.spaceXs),
              child: Text(
                _timestamp(segment.startMs),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style:
                    (compact
                            ? theme.typography.body.xs
                            : theme.typography.body.sm)
                        .copyWith(
                          color: theme.colors.mutedForeground,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
              ),
            ),
            SizedBox(width: compact ? appStyle.spaceXs : appStyle.spaceSm),
            Expanded(
              child: Text(
                segment.text,
                key: ValueKey('transcript-${segment.segmentId}'),
                style: compact
                    ? theme.typography.body.sm
                    : theme.typography.body.md,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return '已随录音暂停';
  }
  return switch (viewModel.previewMetrics.state) {
    AsrPreviewState.ready => '正常',
    AsrPreviewState.backlogged => '积压，录音仍在继续',
    AsrPreviewState.recordingOnly => '已停止，录音仍在继续',
    AsrPreviewState.disposed => '已结束',
  };
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
