import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../theme/theme.dart';
import '../../../core/view_state.dart';
import '../view_models/meeting_list_view_model.dart';

final class MeetingListView extends StatefulWidget {
  const MeetingListView({
    this.viewModel,
    this.onStartMeeting,
    this.onOpenMeeting,
    super.key,
  });

  final MeetingListViewModel? viewModel;
  final VoidCallback? onStartMeeting;
  final ValueChanged<Meeting>? onOpenMeeting;

  @override
  State<MeetingListView> createState() => _MeetingListViewState();
}

final class _MeetingListViewState extends State<MeetingListView> {
  @override
  void initState() {
    super.initState();
    widget.viewModel?.load();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return FScaffold(
      header: FHeader(
        title: const Text('会议'),
        suffixes: [
          FHeaderAction(
            icon: context.theme.icons.calendar(context, semanticsLabel: '开始会议'),
            onPress: widget.onStartMeeting,
          ),
        ],
      ),
      child: viewModel == null
          ? _MeetingListBody(
              state: const ViewData(value: <Meeting>[]),
              onStartMeeting: widget.onStartMeeting,
              onOpenMeeting: widget.onOpenMeeting,
            )
          : ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) => _MeetingListBody(
                state: viewModel.state,
                onStartMeeting: widget.onStartMeeting,
                onOpenMeeting: widget.onOpenMeeting,
              ),
            ),
    );
  }
}

final class _MeetingListBody extends StatelessWidget {
  const _MeetingListBody({
    required this.state,
    required this.onStartMeeting,
    required this.onOpenMeeting,
  });

  final ViewState<List<Meeting>> state;
  final VoidCallback? onStartMeeting;
  final ValueChanged<Meeting>? onOpenMeeting;

  @override
  Widget build(BuildContext context) => switch (state) {
    ViewLoading() => const Center(child: FProgress(semanticsLabel: '正在加载会议')),
    ViewError(:final retry) => _MeetingListError(onRetry: retry),
    ViewData(:final value) when value.isEmpty => _MeetingListEmpty(
      onStartMeeting: onStartMeeting,
    ),
    ViewData(:final value) => _MeetingCollection(
      meetings: value,
      onOpenMeeting: onOpenMeeting,
    ),
  };
}

final class _MeetingListEmpty extends StatelessWidget {
  const _MeetingListEmpty({required this.onStartMeeting});

  final VoidCallback? onStartMeeting;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: appStyle.contentMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: theme.style.iconStyle.copyWith(
                color: theme.colors.mutedForeground,
                size: appStyle.emptyIconSize,
              ),
              child: theme.icons.calendar(context, semanticsLabel: '会议日历'),
            ),
            SizedBox(height: appStyle.spaceLg),
            Text(
              '还没有会议',
              style: theme.typography.display.lg,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: appStyle.spaceSm),
            Text(
              '开始录音后，会议会安全地保存在这台设备上。',
              style: theme.typography.body.md.copyWith(
                color: theme.colors.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: appStyle.spaceLg),
            FButton(
              onPress: onStartMeeting,
              mainAxisSize: MainAxisSize.min,
              child: const Text('开始会议'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _MeetingListError extends StatelessWidget {
  const _MeetingListError({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: FAlert(
          variant: FAlertVariant.destructive,
          title: const Text('会议加载失败'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('本地数据仍保留在设备上，请重试。'),
              SizedBox(height: appStyle.spaceMd),
              FButton(onPress: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

final class _MeetingCollection extends StatelessWidget {
  const _MeetingCollection({
    required this.meetings,
    required this.onOpenMeeting,
  });

  final List<Meeting> meetings;
  final ValueChanged<Meeting>? onOpenMeeting;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= appStyle.wideLayoutMinWidth;
        final padding = EdgeInsets.all(appStyle.spaceMd);
        if (wide) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: appStyle.wideContentMaxWidth,
              ),
              child: GridView.builder(
                key: const ValueKey('meeting-grid'),
                padding: padding,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: appStyle.contentMaxWidth,
                  mainAxisExtent: 144,
                  crossAxisSpacing: appStyle.spaceMd,
                  mainAxisSpacing: appStyle.spaceMd,
                ),
                itemCount: meetings.length,
                itemBuilder: (_, index) => _MeetingCard(
                  meeting: meetings[index],
                  onPress: onOpenMeeting,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          key: const ValueKey('meeting-list'),
          padding: padding,
          itemCount: meetings.length,
          separatorBuilder: (_, _) => SizedBox(height: appStyle.spaceMd),
          itemBuilder: (_, index) =>
              _MeetingCard(meeting: meetings[index], onPress: onOpenMeeting),
        );
      },
    );
  }
}

final class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.onPress});

  final Meeting meeting;
  final ValueChanged<Meeting>? onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return GestureDetector(
      key: ValueKey('meeting-${meeting.id}'),
      onTap: onPress == null ? null : () => onPress!(meeting),
      child: FCard(
        child: Padding(
          padding: EdgeInsets.all(appStyle.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: theme.typography.display.md,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: appStyle.spaceSm),
                  FBadge(
                    variant: meeting.status == MeetingState.failed
                        ? FBadgeVariant.destructive
                        : FBadgeVariant.secondary,
                    child: Text(_meetingStatusLabel(meeting.status)),
                  ),
                ],
              ),
              SizedBox(height: appStyle.spaceSm),
              Text(
                _dateTimeLabel(meeting.createdAt),
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              SizedBox(height: appStyle.spaceSm),
              Text(
                _durationLabel(Duration(milliseconds: meeting.audioDurationMs)),
                style: theme.typography.body.md,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _meetingStatusLabel(MeetingState state) => switch (state) {
  MeetingState.created => '准备中',
  MeetingState.recording => '录音中',
  MeetingState.processing => '处理中',
  MeetingState.completed => '已完成',
  MeetingState.failed => '失败',
};

String _dateTimeLabel(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _durationLabel(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
