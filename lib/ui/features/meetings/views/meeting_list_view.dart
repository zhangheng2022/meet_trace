// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · page: meeting-list · macrostructure: Workbench · theme: Shadcn Neutral
// States: loading · empty · error · list · two-column-expanded

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../theme/theme.dart';
import '../../../core/app_bottom_action_bar.dart';
import '../../../core/app_page_body.dart';
import '../../../core/app_responsive.dart';
import '../../../core/app_state_panel.dart';
import '../../../core/view_state.dart';
import '../view_models/meeting_list_view_model.dart';

final class MeetingListView extends StatefulWidget {
  const MeetingListView({
    this.viewModel,
    this.onStartMeeting,
    this.onOpenMeeting,
    this.onOpenSettings,
    super.key,
  });

  final MeetingListViewModel? viewModel;
  final VoidCallback? onStartMeeting;
  final ValueChanged<Meeting>? onOpenMeeting;
  final VoidCallback? onOpenSettings;

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
    if (viewModel == null) {
      return _page(const ViewData(value: <Meeting>[]));
    }
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => _page(viewModel.state),
    );
  }

  Widget _page(ViewState<List<Meeting>> state) {
    final showFooter =
        widget.onStartMeeting != null &&
        switch (state) {
          ViewData(:final value) when value.isEmpty => false,
          _ => true,
        };

    return FScaffold(
      childPad: false,
      header: FHeader(
        title: const Text('会议'),
        suffixes: [
          if (widget.onOpenSettings != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.settings, semanticLabel: '打开设置'),
              onPress: widget.onOpenSettings,
            ),
        ],
      ),
      footer: showFooter
          ? AppBottomActionBar(
              child: FButton(
                size: FButtonSizeVariant.lg,
                prefix: const Icon(FLucideIcons.calendarPlus),
                onPress: widget.onStartMeeting,
                child: const Text('开始会议', maxLines: 1),
              ),
            )
          : null,
      child: MeetingListContent(
        state: state,
        onStartMeeting: widget.onStartMeeting,
        onOpenMeeting: widget.onOpenMeeting,
      ),
    );
  }
}

/// 会议列表的纯展示内容，供页面和组件预览复用。
final class MeetingListContent extends StatelessWidget {
  const MeetingListContent({
    required this.state,
    required this.onStartMeeting,
    required this.onOpenMeeting,
    super.key,
  });

  final ViewState<List<Meeting>> state;
  final VoidCallback? onStartMeeting;
  final ValueChanged<Meeting>? onOpenMeeting;

  @override
  Widget build(BuildContext context) => switch (state) {
    ViewLoading() => const AppStatePanel.loading(label: '正在加载会议'),
    ViewError(:final retry) => AppStatePanel.error(
      title: '会议加载失败',
      message: '本地数据仍保留在设备上，请重试。',
      actionLabel: retry == null ? null : '重试加载',
      onAction: retry,
    ),
    ViewData(:final value) when value.isEmpty => AppStatePanel.empty(
      icon: FLucideIcons.calendar,
      title: '还没有会议',
      message: '开始录音后，会议会安全地保存在这台设备上。',
      actionLabel: onStartMeeting == null ? null : '开始会议',
      onAction: onStartMeeting,
    ),
    ViewData(:final value) => _MeetingCollection(
      meetings: value,
      onOpenMeeting: onOpenMeeting,
    ),
  };
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
    return AppPageBody(
      width: AppPageWidth.wide,
      child: AppResponsiveBuilder(
        builder: (context, sizeClass, constraints) =>
            sizeClass == AppWindowSizeClass.expanded
            ? _MeetingGrid(meetings: meetings, onOpenMeeting: onOpenMeeting)
            : ListView.separated(
                key: const ValueKey('meeting-list'),
                itemCount: meetings.length,
                separatorBuilder: (_, _) => SizedBox(height: appStyle.spaceMd),
                itemBuilder: (_, index) => _MeetingCard(
                  meeting: meetings[index],
                  onPress: onOpenMeeting,
                ),
              ),
      ),
    );
  }
}

final class _MeetingGrid extends StatelessWidget {
  const _MeetingGrid({required this.meetings, required this.onOpenMeeting});

  final List<Meeting> meetings;
  final ValueChanged<Meeting>? onOpenMeeting;

  @override
  Widget build(BuildContext context) {
    final gap = context.theme.style.app.spaceMd;
    return ListView.separated(
      key: const ValueKey('meeting-grid'),
      itemCount: (meetings.length / 2).ceil(),
      separatorBuilder: (_, _) => SizedBox(height: gap),
      itemBuilder: (context, rowIndex) {
        final firstIndex = rowIndex * 2;
        final secondIndex = firstIndex + 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MeetingCard(
                  meeting: meetings[firstIndex],
                  onPress: onOpenMeeting,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: secondIndex < meetings.length
                    ? _MeetingCard(
                        meeting: meetings[secondIndex],
                        onPress: onOpenMeeting,
                      )
                    : const SizedBox(),
              ),
            ],
          ),
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
    final status = _meetingStatusVisual(theme, meeting.status);
    final card = FCard(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              meeting.title,
              style: theme.typography.display.md,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: appStyle.spaceSm),
            Row(
              children: [
                Icon(status.icon, color: status.color),
                SizedBox(width: appStyle.spaceXs),
                Expanded(
                  child: Text(
                    _meetingStatusLabel(meeting.status),
                    style: theme.typography.body.md.copyWith(
                      color: status.color,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: appStyle.spaceSm),
            Column(
              children: [
                _MeetingMetadata(
                  icon: FLucideIcons.calendarDays,
                  label: _dateTimeLabel(meeting.createdAt),
                ),
                SizedBox(height: appStyle.spaceXs),
                _MeetingMetadata(
                  icon: FLucideIcons.clock3,
                  label:
                      '时长 ${_durationLabel(Duration(milliseconds: meeting.audioDurationMs))}',
                ),
              ],
            ),
            if (meeting.status == MeetingState.failed) ...[
              SizedBox(height: appStyle.spaceSm),
              Text(
                '打开会议查看失败原因',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onPress == null) {
      return KeyedSubtree(key: ValueKey('meeting-${meeting.id}'), child: card);
    }
    return FTappable(
      key: ValueKey('meeting-${meeting.id}'),
      semanticsLabel:
          '打开会议：${meeting.title}，${_meetingStatusLabel(meeting.status)}',
      semanticsHint: meeting.status == MeetingState.failed
          ? '查看失败原因和事实音频状态'
          : '查看会议详情',
      excludeSemantics: true,
      onPress: () => onPress!(meeting),
      child: card,
    );
  }
}

final class _MeetingMetadata extends StatelessWidget {
  const _MeetingMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final style = theme.typography.body.sm.copyWith(
      color: theme.colors.mutedForeground,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        Icon(icon, color: theme.colors.mutedForeground),
        SizedBox(width: appStyle.spaceXs),
        Expanded(child: Text(label, style: style)),
      ],
    );
  }
}

_MeetingStatusVisual _meetingStatusVisual(
  FThemeData theme,
  MeetingState state,
) => switch (state) {
  MeetingState.created => _MeetingStatusVisual(
    icon: FLucideIcons.circleDashed,
    color: theme.colors.mutedForeground,
  ),
  MeetingState.recording => _MeetingStatusVisual(
    icon: FLucideIcons.radio,
    color: theme.colors.app.recording,
  ),
  MeetingState.processing => _MeetingStatusVisual(
    icon: FLucideIcons.audioLines,
    color: theme.colors.primary,
  ),
  MeetingState.completed => _MeetingStatusVisual(
    icon: FLucideIcons.circleCheck,
    color: theme.colors.app.success,
  ),
  MeetingState.failed => _MeetingStatusVisual(
    icon: FLucideIcons.circleAlert,
    color: theme.colors.error,
  ),
};

final class _MeetingStatusVisual {
  const _MeetingStatusVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
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
  return '${value.year}年${value.month}月${value.day}日 '
      '${two(value.hour)}:${two(value.minute)}';
}

String _durationLabel(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
