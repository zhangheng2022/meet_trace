part of '../meeting_detail_view.dart';

final class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.viewModel,
    required this.transcriptKey,
    required this.editingTranscript,
    required this.onEditingChanged,
  });

  final MeetingDetailViewModel viewModel;
  final GlobalKey<_TranscriptSectionState> transcriptKey;
  final bool editingTranscript;
  final ValueChanged<bool> onEditingChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final snapshot = viewModel.snapshot!;
    final workbench = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.errorMessage case final message?) ...[
          AppStatusNotice(
            tone: AppStatusTone.error,
            title: '最近一次处理未完成',
            message: message,
          ),
          SizedBox(height: appStyle.spaceMd),
        ],
        _TranscriptSection(
          key: transcriptKey,
          snapshot: snapshot,
          viewModel: viewModel,
          editing: editingTranscript,
          onEditingChanged: onEditingChanged,
        ),
        if (viewModel.resultMessage case final message?) ...[
          SizedBox(height: appStyle.spaceLg),
          AppStatusNotice(
            tone: AppStatusTone.info,
            title: '操作状态',
            message: message,
          ),
        ],
        SizedBox(height: appStyle.spaceXl),
        _DiarizationSection(viewModel: viewModel, editing: editingTranscript),
      ],
    );
    return SingleChildScrollView(
      child: AppPageBody(
        width: AppPageWidth.wide,
        child: AppResponsiveBuilder(
          builder: (context, sizeClass, constraints) {
            if (sizeClass != AppWindowSizeClass.expanded) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: appStyle.readingContentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MeetingIdentity(viewModel: viewModel),
                    SizedBox(height: appStyle.spaceLg),
                    _AudioEvidenceStrip(viewModel: viewModel),
                    SizedBox(height: appStyle.spaceXl),
                    workbench,
                  ],
                ),
              );
            }
            return Row(
              key: const ValueKey('meeting-detail-audio-workbench'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: appStyle.factRailWidth,
                  child: _MeetingFactRail(viewModel: viewModel),
                ),
                SizedBox(width: appStyle.spaceXl),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: appStyle.readingContentMaxWidth,
                    ),
                    child: workbench,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _MeetingIdentity extends StatelessWidget {
  const _MeetingIdentity({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(viewModel.meeting.title, style: theme.typography.display.lg),
        SizedBox(height: appStyle.spaceSm),
        Text(
          '${_dateLabel(viewModel.meeting.createdAt)} · '
          '${_duration(viewModel.meeting.audioDurationMs)} · '
          '${viewModel.sourceModel.displayName}',
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

final class _MeetingFactRail extends StatelessWidget {
  const _MeetingFactRail({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('事实记录', style: theme.typography.body.xs),
        SizedBox(height: appStyle.spaceLg),
        _MeetingIdentity(viewModel: viewModel),
        SizedBox(height: appStyle.spaceLg),
        _AudioEvidenceStrip(viewModel: viewModel, compact: true),
        SizedBox(height: appStyle.spaceLg),
        const AppStatusNotice(
          tone: AppStatusTone.success,
          title: '事实音频已保存',
          message: '最终转录带有时间戳，可回到本机原音频核对。',
        ),
      ],
    );
  }
}

final class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.viewModel});

  final String message;
  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
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
            _FailureCard(message: message, viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

final class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.message, required this.viewModel});

  final String message;
  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return FAlert(
      variant: FAlertVariant.destructive,
      title: const Text('最终转录未完成'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message),
          if (viewModel.canRetry) ...[
            SizedBox(height: appStyle.spaceMd),
            FButton(
              onPress: () => unawaited(viewModel.retry()),
              child: const Text('重试最终转录'),
            ),
          ],
        ],
      ),
    );
  }
}
