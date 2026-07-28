part of '../meeting_detail_view.dart';

final class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.viewModel,
    required this.section,
    required this.editingTranscript,
    required this.onSectionChanged,
    required this.onEditingChanged,
    required this.onEvidence,
    required this.onDeleted,
  });

  final MeetingDetailViewModel viewModel;
  final MeetingResultSection section;
  final bool editingTranscript;
  final ValueChanged<MeetingResultSection> onSectionChanged;
  final ValueChanged<bool> onEditingChanged;
  final ValueChanged<SummaryEvidence> onEvidence;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final snapshot = viewModel.snapshot!;
    final resultContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(viewModel.meeting.title, style: theme.typography.display.lg),
        SizedBox(height: appStyle.spaceSm),
        Text(
          '来源模型：${viewModel.sourceModel.displayName} · '
          '${_duration(viewModel.meeting.audioDurationMs)}',
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        SizedBox(height: appStyle.spaceLg),
        if (viewModel.errorMessage case final message?) ...[
          AppStatusNotice(
            tone: AppStatusTone.error,
            title: '最近一次处理未完成',
            message: message,
          ),
          SizedBox(height: appStyle.spaceMd),
        ],
        FTabs(
          key: const ValueKey('meeting-result-tabs'),
          control: FTabControl.lifted(
            index: section.index,
            onChange: (index) =>
                onSectionChanged(MeetingResultSection.values[index]),
          ),
          children: [
            FTabEntry(
              label: const Text('转录'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TranscriptCard(
                    key: ValueKey('transcript-${snapshot.id}'),
                    snapshot: snapshot,
                    viewModel: viewModel,
                    editing: editingTranscript,
                    onEditingChanged: onEditingChanged,
                  ),
                  SizedBox(height: appStyle.spaceMd),
                  _DiarizationCard(
                    viewModel: viewModel,
                    editing: editingTranscript,
                  ),
                ],
              ),
            ),
            FTabEntry(
              label: const Text('总结'),
              child: _SummaryCard(viewModel: viewModel, onEvidence: onEvidence),
            ),
            FTabEntry(
              label: const Text('录音'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AudioCard(viewModel: viewModel),
                  SizedBox(height: appStyle.spaceMd),
                  _ResultActionsCard(
                    viewModel: viewModel,
                    onDeleted: onDeleted,
                  ),
                  if (viewModel.canRetranscribe) ...[
                    SizedBox(height: appStyle.spaceMd),
                    _RetranscriptionCard(viewModel: viewModel),
                  ],
                ],
              ),
            ),
          ],
        ),
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
                child: resultContent,
              );
            }
            return Row(
              key: const ValueKey('meeting-detail-evidence-workbench'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: appStyle.factRailWidth,
                  child: _MeetingFactRail(viewModel: viewModel),
                ),
                SizedBox(width: appStyle.spaceXl),
                Expanded(child: resultContent),
              ],
            );
          },
        ),
      ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.card,
        border: Border.all(
          color: theme.colors.border,
          width: appStyle.dividerWidth,
        ),
        borderRadius: BorderRadius.circular(appStyle.panelRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('事实记录', style: theme.typography.body.xs),
            SizedBox(height: appStyle.spaceLg),
            Text(viewModel.meeting.title, style: theme.typography.display.lg),
            SizedBox(height: appStyle.spaceLg),
            _FactLine(
              icon: FLucideIcons.clock3,
              label: '会议时长',
              value: _duration(viewModel.meeting.audioDurationMs),
            ),
            SizedBox(height: appStyle.spaceMd),
            _FactLine(
              icon: FLucideIcons.lockKeyhole,
              label: '来源模型',
              value: viewModel.sourceModel.displayName,
            ),
            SizedBox(height: appStyle.spaceLg),
            const AppStatusNotice(
              tone: AppStatusTone.success,
              title: '事实音频已保存',
              message: '最终转录与证据均可回到本机原音频核对。',
            ),
          ],
        ),
      ),
    );
  }
}

final class _FactLine extends StatelessWidget {
  const _FactLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colors.mutedForeground),
        SizedBox(width: appStyle.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              SizedBox(height: appStyle.space2Xs),
              Text(value, style: theme.typography.body.sm),
            ],
          ),
        ),
      ],
    );
  }
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
