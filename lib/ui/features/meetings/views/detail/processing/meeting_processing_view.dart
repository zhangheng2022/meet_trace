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
    final diarizationDetail = viewModel.diarizationAvailable
        ? '同时整理说话人，全部完成后一次发布结果。'
        : '自动说话人整理不可用，将按单一说话人发布结果。';
    return AppStatusNotice(
      tone: AppStatusTone.info,
      title: '正在生成最终结果',
      message:
          '事实音频已经安全保存在本机。正在使用 '
          '${viewModel.sourceModel.displayName} 生成最终转录；$diarizationDetail',
    );
  }
}
