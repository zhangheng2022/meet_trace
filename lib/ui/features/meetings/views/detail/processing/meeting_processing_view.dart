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
            Text(viewModel.meeting.title, style: theme.typography.display.lg),
            SizedBox(height: appStyle.spaceSm),
            Text(
              '正在整理会议结果',
              style: theme.typography.body.md.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            SizedBox(height: appStyle.spaceLg),
            _ProcessingCard(viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

final class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppStatusNotice(
          tone: AppStatusTone.info,
          title: '正在生成联合最终结果',
          message: '事实音频已经安全保存在本机。最终转录与说话人整理并行运行，全部结束后才会发布结果。',
        ),
        SizedBox(height: appStyle.spaceMd),
        FCard(
          child: Padding(
            padding: EdgeInsets.all(appStyle.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProcessingStage(title: '最终转录', detail: '使用本场锁定模型完整读取事实录音'),
                SizedBox(height: appStyle.spaceMd),
                _ProcessingStage(
                  title: '说话人整理',
                  detail: viewModel.diarizationAvailable
                      ? '从同一份完整事实音频区分说话人'
                      : '当前自动分离不可用，将按单一说话人发布最终文本',
                ),
                SizedBox(height: appStyle.spaceLg),
                Text(
                  '来源模型：${viewModel.sourceModel.displayName}',
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _ProcessingStage extends StatelessWidget {
  const _ProcessingStage({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: appStyle.minimumTouchTarget,
          child: Center(
            child: const SizedBox.square(
              dimension: 24,
              child: FProgress(semanticsLabel: '正在处理'),
            ),
          ),
        ),
        SizedBox(width: appStyle.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.typography.body.lg),
              SizedBox(height: appStyle.space2Xs),
              Text(
                detail,
                style: theme.typography.body.sm.copyWith(
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
