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
          title: '正在生成最终转录',
          message: '录音已经安全保存在本机。处理变慢或失败都不会影响事实音频。',
        ),
        SizedBox(height: appStyle.spaceMd),
        FCard(
          child: Padding(
            padding: EdgeInsets.all(appStyle.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProcessingStage(
                  status: _ProcessingStageStatus.running,
                  title: '最终转录',
                  detail: '使用本场锁定模型完整读取事实录音',
                ),
                SizedBox(height: appStyle.spaceMd),
                _ProcessingStage(
                  status: _ProcessingStageStatus.waiting,
                  title: '说话人整理',
                  detail: viewModel.diarizationAvailable
                      ? '最终转录完成后尝试区分说话人'
                      : '当前未配置本地分离模型，可稍后手工标注',
                ),
                SizedBox(height: appStyle.spaceMd),
                _ProcessingStage(
                  status: _ProcessingStageStatus.waiting,
                  title: 'AI 总结',
                  detail: viewModel.summaryAvailable
                      ? '最终转录完成后可由你主动生成'
                      : '当前未配置安全总结网关',
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

enum _ProcessingStageStatus { waiting, running }

final class _ProcessingStage extends StatelessWidget {
  const _ProcessingStage({
    required this.status,
    required this.title,
    required this.detail,
  });

  final _ProcessingStageStatus status;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final running = status == _ProcessingStageStatus.running;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: appStyle.minimumTouchTarget,
          child: Center(
            child: running
                ? const SizedBox.square(
                    dimension: 24,
                    child: FProgress(semanticsLabel: '正在处理'),
                  )
                : Icon(
                    FLucideIcons.circle,
                    size: 20,
                    color: theme.colors.mutedForeground,
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
