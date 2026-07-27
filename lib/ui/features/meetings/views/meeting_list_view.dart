// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Impeccable · page: meeting-list · world: Evidence Ledger
// Composition A: continuous chronological ledger on phone and tablet.

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../theme/theme.dart';
import '../../../core/app_bottom_action_bar.dart';
import '../../../core/app_ledger.dart';
import '../../../core/app_page_body.dart';
import '../../../core/app_state_panel.dart';
import '../../../core/app_status_notice.dart';
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
        title: const Text('会迹'),
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
    ViewData(:final value) when value.isEmpty => _EmptyMeetingLedger(
      onStartMeeting: onStartMeeting,
    ),
    ViewData(:final value) => _MeetingCollection(
      meetings: value,
      onOpenMeeting: onOpenMeeting,
    ),
  };
}

final class _EmptyMeetingLedger extends StatelessWidget {
  const _EmptyMeetingLedger({required this.onStartMeeting});

  final VoidCallback? onStartMeeting;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return AppPageBody(
      width: AppPageWidth.wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppStatusNotice(
            tone: AppStatusTone.info,
            title: '本地事实记录',
            message: '会议与事实音频只保存在这台设备上。',
            liveRegion: false,
          ),
          SizedBox(height: appStyle.spaceLg),
          Expanded(
            child: AppStatePanel.empty(
              icon: FLucideIcons.calendar,
              title: '还没有会议',
              message: '开始录音后，会议会安全地保存在这台设备上。',
              actionLabel: onStartMeeting == null ? null : '开始会议',
              onAction: onStartMeeting,
            ),
          ),
        ],
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
    return AppPageBody(
      width: AppPageWidth.wide,
      child: ListView(
        key: const ValueKey('meeting-ledger'),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('会议', style: context.theme.typography.display.lg),
              ),
              Text(
                '共 ${meetings.length} 场',
                style: context.theme.typography.body.xs.copyWith(
                  color: context.theme.colors.mutedForeground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SizedBox(height: appStyle.spaceMd),
          AppLedgerSurface(
            children: [
              for (var index = 0; index < meetings.length; index++)
                _MeetingLedgerRow(
                  meeting: meetings[index],
                  onPress: onOpenMeeting,
                  showDivider: index < meetings.length - 1,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _MeetingLedgerRow extends StatelessWidget {
  const _MeetingLedgerRow({
    required this.meeting,
    required this.onPress,
    required this.showDivider,
  });

  final Meeting meeting;
  final ValueChanged<Meeting>? onPress;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return AppLedgerRow(
      key: ValueKey('meeting-${meeting.id}'),
      dateLabel: _dateLabel(meeting.createdAt),
      timeLabel: _timeLabel(meeting.createdAt),
      title: meeting.title,
      metaLabel:
          '时长 ${_durationLabel(Duration(milliseconds: meeting.audioDurationMs))}',
      statusIcon: _meetingStatusIcon(meeting.status),
      statusLabel: meeting.status == MeetingState.failed
          ? '失败 · 打开查看原因和事实音频状态'
          : _meetingStatusLabel(meeting.status),
      emphasized: meeting.status == MeetingState.recording,
      showDivider: showDivider,
      semanticsLabel:
          '打开会议：${meeting.title}，${_meetingStatusLabel(meeting.status)}',
      semanticsHint: meeting.status == MeetingState.failed
          ? '查看失败原因和事实音频状态'
          : '查看会议详情',
      onPress: onPress == null ? null : () => onPress!(meeting),
    );
  }
}

IconData _meetingStatusIcon(MeetingState state) => switch (state) {
  MeetingState.created => FLucideIcons.circleDashed,
  MeetingState.recording => FLucideIcons.square,
  MeetingState.processing => FLucideIcons.audioLines,
  MeetingState.completed => FLucideIcons.circleCheck,
  MeetingState.failed => FLucideIcons.circleAlert,
};

String _meetingStatusLabel(MeetingState state) => switch (state) {
  MeetingState.created => '准备中',
  MeetingState.recording => '录音中',
  MeetingState.processing => '处理中',
  MeetingState.completed => '已完成',
  MeetingState.failed => '失败',
};

String _dateLabel(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _timeLabel(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}

String _durationLabel(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
