part of '../meeting_detail_view.dart';

final class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return SingleChildScrollView(
      child: AppPageBody(
        width: AppPageWidth.reading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MeetingIdentity(viewModel: viewModel),
            SizedBox(height: appStyle.spaceLg),
            _AudioEvidenceStrip(viewModel: viewModel),
            SizedBox(height: appStyle.spaceXl),
            _ProcessingLedger(viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

final class _ProcessingLedger extends StatelessWidget {
  const _ProcessingLedger({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final modelName = viewModel.sourceModel.displayName;
    final outcome = viewModel.diarizationAvailable
        ? '完成后将一次显示最终转录和说话人标签。'
        : '说话人区分当前不可用；完成后将按单一说话人显示。';
    return Semantics(
      key: const ValueKey('meeting-processing-ledger'),
      container: true,
      liveRegion: true,
      label:
          '正在生成最终结果。$modelName 正在处理完整录音。'
          '$outcome事实录音已保存在本机，处理不会改写原始音频。',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.card,
            border: Border.symmetric(
              horizontal: BorderSide(
                color: theme.colors.border,
                width: appStyle.dividerWidth,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: appStyle.spaceMd,
              vertical: appStyle.spaceLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FProgress(semanticsLabel: '正在生成最终结果'),
                SizedBox(height: appStyle.spaceLg),
                Text('正在生成最终结果', style: theme.typography.display.lg),
                SizedBox(height: appStyle.spaceXs),
                Text('$modelName 正在处理完整录音。', style: theme.typography.body.md),
                SizedBox(height: appStyle.spaceSm),
                Text(
                  outcome,
                  key: const ValueKey('meeting-processing-outcome'),
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                SizedBox(height: appStyle.spaceLg),
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
                    padding: EdgeInsets.only(top: appStyle.spaceSm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          FLucideIcons.fileAudio,
                          size: 20,
                          color: theme.colors.mutedForeground,
                        ),
                        SizedBox(width: appStyle.spaceSm),
                        Expanded(
                          child: Text(
                            '事实录音已保存在本机，处理不会改写原始音频。',
                            key: const ValueKey(
                              'meeting-processing-audio-safety',
                            ),
                            style: theme.typography.body.sm.copyWith(
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
          ),
        ),
      ),
    );
  }
}
