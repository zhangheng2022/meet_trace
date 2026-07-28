part of '../meeting_detail_view.dart';

final class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.viewModel, required this.onEvidence});

  final MeetingDetailViewModel viewModel;
  final ValueChanged<SummaryEvidence> onEvidence;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final summary = viewModel.summary;
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('AI 总结', style: theme.typography.display.md),
            SizedBox(height: appStyle.spaceSm),
            Text(
              '只基于当前最终转录生成；不会上传音频或会中临时文本。',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            if (!viewModel.summaryAvailable && summary == null) ...[
              SizedBox(height: appStyle.spaceMd),
              const FAlert(
                title: Text('安全总结网关未配置'),
                subtitle: Text('当前构建已关闭云端总结，最终转录仍保留在本机且可正常查看。'),
              ),
            ],
            if (viewModel.isGeneratingSummary ||
                summary?.status == SummaryStatus.processing) ...[
              SizedBox(height: appStyle.spaceMd),
              const FProgress(semanticsLabel: 'AI 总结生成中'),
            ],
            if (viewModel.summaryMessage case final message?) ...[
              SizedBox(height: appStyle.spaceMd),
              FAlert(
                variant: summary?.status == SummaryStatus.failed
                    ? FAlertVariant.destructive
                    : FAlertVariant.primary,
                title: Text(
                  summary?.status == SummaryStatus.failed
                      ? 'AI 总结生成失败'
                      : 'AI 总结状态',
                ),
                subtitle: Text(message),
              ),
            ],
            if (summary?.status == SummaryStatus.stale) ...[
              SizedBox(height: appStyle.spaceMd),
              const FAlert(
                variant: FAlertVariant.destructive,
                title: Text('AI 总结已过期'),
                subtitle: Text('最终转录版本已变化，请基于当前版本重新生成总结。'),
              ),
            ],
            if (summary?.status == SummaryStatus.complete) ...[
              SizedBox(height: appStyle.spaceMd),
              Text('概览', style: theme.typography.display.sm),
              SizedBox(height: appStyle.spaceSm),
              Text(summary!.overview, style: theme.typography.body.md),
              if (summary.keyPoints.isNotEmpty)
                _SummarySection(
                  title: '关键结论',
                  items: summary.keyPoints,
                  onEvidence: onEvidence,
                ),
              if (summary.actionItems.isNotEmpty)
                _SummarySection(
                  title: '行动项',
                  items: summary.actionItems,
                  onEvidence: onEvidence,
                ),
            ],
            if (viewModel.canGenerateSummary) ...[
              SizedBox(height: appStyle.spaceMd),
              FButton(
                key: const ValueKey('generate-summary'),
                onPress: () => unawaited(viewModel.generateSummary()),
                child: Text(
                  summary == null
                      ? '生成 AI 总结'
                      : summary.status == SummaryStatus.failed
                      ? '重试 AI 总结'
                      : '重新生成 AI 总结',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.items,
    required this.onEvidence,
  });

  final String title;
  final List<SummaryItem> items;
  final ValueChanged<SummaryEvidence> onEvidence;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Padding(
      padding: EdgeInsets.only(top: appStyle.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.typography.display.sm),
          SizedBox(height: appStyle.spaceSm),
          for (final item in items)
            Padding(
              padding: EdgeInsets.only(bottom: appStyle.spaceMd),
              child: _SummaryItemView(item: item, onEvidence: onEvidence),
            ),
        ],
      ),
    );
  }
}

final class _SummaryItemView extends StatelessWidget {
  const _SummaryItemView({required this.item, required this.onEvidence});

  final SummaryItem item;
  final ValueChanged<SummaryEvidence> onEvidence;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('• ${item.text}', style: theme.typography.body.md),
        if (item.isPendingReview) ...[
          SizedBox(height: appStyle.spaceSm),
          Text(
            '待核对：未找到有效原文证据',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.destructive,
            ),
          ),
        ] else
          for (final evidence in item.evidence) ...[
            SizedBox(height: appStyle.spaceSm),
            Semantics(
              button: true,
              label:
                  '播放证据 ${_timestamp(evidence.startMs)} 到 '
                  '${_timestamp(evidence.endMs)}',
              child: GestureDetector(
                key: ValueKey(
                  'play-evidence-${evidence.segmentId}-${evidence.startMs}',
                ),
                behavior: HitTestBehavior.opaque,
                onTap: () => onEvidence(evidence),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: appStyle.minimumTouchTarget,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        FLucideIcons.play,
                        size: 18,
                        color: theme.colors.primary,
                      ),
                      SizedBox(width: appStyle.spaceXs),
                      Expanded(
                        child: Text(
                          '证据 ${_timestamp(evidence.startMs)}–'
                          '${_timestamp(evidence.endMs)}：${evidence.quote}',
                          style: theme.typography.body.sm.copyWith(
                            color: theme.colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
      ],
    );
  }
}
