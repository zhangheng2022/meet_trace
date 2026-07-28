// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Impeccable · page: meeting-list · world: Evidence Ledger
// THESIS: the home is a live local-recording desk, not a dashboard of cards.
// OWN-WORLD: white sheets, black ink, hairline rules, a dated ledger timeline.
// STORY: confirm local recording rules, scan meetings, select one, then start.
// FIRST VIEWPORT: recording setup, meeting count, ledger, fixed black action.
// FORM: reference-pinned phone ledger + tablet master-detail composition.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../theme/theme.dart';
import '../../../core/app_ledger.dart';
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
      child: MeetingListContent(
        state: state,
        readiness:
            widget.viewModel?.readiness ??
            const MeetingReadinessViewState.unchecked(),
        onStartMeeting: widget.onStartMeeting,
        onOpenMeeting: widget.onOpenMeeting,
        onOpenSettings: widget.onOpenSettings,
        onRetryReadiness: widget.viewModel?.refreshReadiness,
      ),
    );
  }
}

/// 会议列表的纯展示内容，供页面和组件预览复用。
final class MeetingListContent extends StatefulWidget {
  const MeetingListContent({
    required this.state,
    required this.readiness,
    required this.onStartMeeting,
    required this.onOpenMeeting,
    this.onOpenSettings,
    this.onRetryReadiness,
    super.key,
  });

  final ViewState<List<Meeting>> state;
  final MeetingReadinessViewState readiness;
  final VoidCallback? onStartMeeting;
  final ValueChanged<Meeting>? onOpenMeeting;
  final VoidCallback? onOpenSettings;
  final Future<void> Function()? onRetryReadiness;

  @override
  State<MeetingListContent> createState() => _MeetingListContentState();
}

final class _MeetingListContentState extends State<MeetingListContent> {
  String? _selectedMeetingId;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveBuilder(
      builder: (context, sizeClass, constraints) {
        final meetings = switch (widget.state) {
          ViewData(:final value) => value,
          _ => const <Meeting>[],
        };
        final selected = _selectedMeeting(meetings);
        final listBody = _listBody(meetings, sizeClass);
        final homePane = _MeetingHomePane(
          total: widget.state is ViewData<List<Meeting>>
              ? meetings.length
              : null,
          readiness: widget.readiness,
          onOpenSettings: widget.onOpenSettings,
          onRetryReadiness: widget.onRetryReadiness,
          onStartMeeting: widget.onStartMeeting,
          body: listBody,
        );

        if (sizeClass != AppWindowSizeClass.expanded) {
          return homePane;
        }

        final appStyle = context.theme.style.app;
        final listWidth = (constraints.maxWidth * 0.42)
            .clamp(400.0, 480.0)
            .toDouble();
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: appStyle.wideContentMaxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.theme.colors.card,
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: context.theme.colors.border,
                    width: appStyle.dividerWidth,
                  ),
                ),
              ),
              child: Row(
                key: const ValueKey('meeting-home-master-detail'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: listWidth, child: homePane),
                  ColoredBox(
                    color: context.theme.colors.border,
                    child: SizedBox(width: appStyle.dividerWidth),
                  ),
                  Expanded(
                    child: selected == null
                        ? const _MeetingPreviewPlaceholder()
                        : _MeetingPreviewPane(
                            key: ValueKey('meeting-preview-${selected.id}'),
                            meeting: selected,
                            onOpenMeeting: widget.onOpenMeeting,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Meeting? _selectedMeeting(List<Meeting> meetings) {
    if (meetings.isEmpty) {
      return null;
    }
    final selectedId = _selectedMeetingId;
    if (selectedId == null) {
      return meetings.first;
    }
    for (final meeting in meetings) {
      if (meeting.id == selectedId) {
        return meeting;
      }
    }
    return meetings.first;
  }

  Widget _listBody(List<Meeting> meetings, AppWindowSizeClass sizeClass) {
    return switch (widget.state) {
      ViewLoading() => const AppStatePanel.loading(label: '正在加载会议'),
      ViewError(:final retry) => AppStatePanel.error(
        title: '会议加载失败',
        message: '本地数据仍保留在设备上，请重试。',
        actionLabel: retry == null ? null : '重试加载',
        onAction: retry,
      ),
      ViewData(:final value) when value.isEmpty => const AppStatePanel.empty(
        icon: FLucideIcons.calendar,
        title: '还没有会议',
        message: '开始录音后，会议会安全地保存在这台设备上。',
      ),
      ViewData() => ListView(
        key: const ValueKey('meeting-ledger'),
        padding: EdgeInsets.zero,
        children: [
          AppLedgerSurface(
            framed: false,
            children: [
              for (var index = 0; index < meetings.length; index++)
                _MeetingLedgerRow(
                  meeting: meetings[index],
                  selected:
                      sizeClass == AppWindowSizeClass.expanded &&
                      meetings[index].id == _selectedMeeting(meetings)?.id,
                  onPress: sizeClass == AppWindowSizeClass.expanded
                      ? () => setState(
                          () => _selectedMeetingId = meetings[index].id,
                        )
                      : widget.onOpenMeeting == null
                      ? null
                      : () => widget.onOpenMeeting!(meetings[index]),
                  showDivider: index < meetings.length - 1,
                ),
            ],
          ),
        ],
      ),
    };
  }
}

final class _MeetingHomePane extends StatelessWidget {
  const _MeetingHomePane({
    required this.body,
    required this.total,
    required this.readiness,
    required this.onOpenSettings,
    required this.onRetryReadiness,
    required this.onStartMeeting,
  });

  final Widget body;
  final int? total;
  final MeetingReadinessViewState readiness;
  final VoidCallback? onOpenSettings;
  final Future<void> Function()? onRetryReadiness;
  final VoidCallback? onStartMeeting;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecordingSetupStrip(
            readiness: readiness,
            onOpenSettings: onOpenSettings,
            onRetry: onRetryReadiness,
          ),
          _MeetingSectionHeader(total: total),
          Expanded(child: body),
          if (onStartMeeting != null)
            _StartMeetingControl(onPress: onStartMeeting!),
        ],
      ),
    );
  }
}

final class _RecordingSetupStrip extends StatelessWidget {
  const _RecordingSetupStrip({
    required this.readiness,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final MeetingReadinessViewState readiness;
  final VoidCallback? onOpenSettings;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final presentation = _readinessPresentation(readiness);
    final retry = readiness.status == MeetingReadinessStatus.failed
        ? onRetry
        : null;
    final VoidCallback? onPress = retry == null
        ? onOpenSettings
        : () => unawaited(retry());
    final content = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: appStyle.spaceMd,
          vertical: appStyle.spaceXs,
        ),
        child: Row(
          children: [
            Icon(presentation.icon, size: 19),
            SizedBox(width: appStyle.spaceSm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.title,
                    key: const ValueKey('recording-setup-title'),
                    style: theme.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: appStyle.space2Xs),
                  Text(
                    presentation.detail,
                    key: const ValueKey('recording-setup-detail'),
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (onPress != null) ...[
              SizedBox(width: appStyle.spaceXs),
              Icon(
                FLucideIcons.chevronRight,
                size: 18,
                color: theme.colors.mutedForeground,
              ),
            ],
          ],
        ),
      ),
    );
    if (onPress == null) {
      return content;
    }
    return FTappable(
      semanticsLabel: retry == null ? '查看录音条件和默认模型设置' : '重新检查录音条件',
      onPress: onPress,
      child: content,
    );
  }
}

({IconData icon, String title, String detail}) _readinessPresentation(
  MeetingReadinessViewState readiness,
) => switch (readiness.status) {
  MeetingReadinessStatus.unchecked => (
    icon: FLucideIcons.fileAudio,
    title: '本地录音',
    detail: '使用默认模型',
  ),
  MeetingReadinessStatus.checking => (
    icon: FLucideIcons.fileAudio,
    title: '正在检查录音条件',
    detail: '麦克风、存储与默认模型',
  ),
  MeetingReadinessStatus.ready => (
    icon: FLucideIcons.circleCheck,
    title: '录音条件已就绪',
    detail: '音频仅保存在本机 · ${readiness.defaultModelName ?? '默认模型'}可用',
  ),
  MeetingReadinessStatus.microphonePermissionRequired => (
    icon: FLucideIcons.circleAlert,
    title: '需要麦克风权限',
    detail: _readinessDetail('开始会议时授权', readiness.issueCount),
  ),
  MeetingReadinessStatus.storageInsufficient => (
    icon: FLucideIcons.circleAlert,
    title: '存储空间不足',
    detail: _readinessDetail('至少保留 128 MB', readiness.issueCount),
  ),
  MeetingReadinessStatus.defaultModelUnavailable => (
    icon: FLucideIcons.circleAlert,
    title: '默认模型不可用',
    detail: '${readiness.defaultModelName ?? '当前模型'}需要处理',
  ),
  MeetingReadinessStatus.failed => (
    icon: FLucideIcons.circleAlert,
    title: '无法检查录音条件',
    detail: '点按重新检查',
  ),
};

String _readinessDetail(String primary, int issueCount) =>
    issueCount > 1 ? '$primary，另有 ${issueCount - 1} 项' : primary;

final class _MeetingSectionHeader extends StatelessWidget {
  const _MeetingSectionHeader({required this.total});

  final int? total;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: appStyle.spaceMd,
          vertical: appStyle.spaceSm,
        ),
        child: Row(
          children: [
            Expanded(child: Text('会议', style: theme.typography.display.lg)),
            if (total case final count?)
              Text(
                '共 $count 场',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _StartMeetingControl extends StatelessWidget {
  const _StartMeetingControl({required this.onPress});

  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return FTappable(
      key: const ValueKey('start-meeting-control'),
      style: const FTappableStyleDelta.delta(
        pressedEnterDuration: Duration.zero,
        pressedExitDuration: Duration.zero,
        motion: FTappableMotion.none,
      ),
      semanticsLabel: '开始会议',
      onPress: onPress,
      builder: (context, variants, child) {
        final pressed = variants.contains(FTappableVariant.pressed);
        return AnimatedContainer(
          key: const ValueKey('start-meeting-control-surface'),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          color: Color.lerp(
            theme.colors.primary,
            theme.colors.primaryForeground,
            pressed ? 0.12 : 0,
          ),
          child: child,
        );
      },
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: appStyle.controlHeight + appStyle.spaceMd,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FLucideIcons.mic, color: theme.colors.primaryForeground),
                SizedBox(width: appStyle.spaceSm),
                Text(
                  '开始会议',
                  style: theme.typography.body.lg.copyWith(
                    color: theme.colors.primaryForeground,
                    fontWeight: FontWeight.w600,
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

final class _MeetingLedgerRow extends StatelessWidget {
  const _MeetingLedgerRow({
    required this.meeting,
    required this.selected,
    required this.onPress,
    required this.showDivider,
  });

  final Meeting meeting;
  final bool selected;
  final VoidCallback? onPress;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return AppLedgerRow(
      key: ValueKey('meeting-${meeting.id}'),
      dateLabel: _dateLabel(meeting.createdAt),
      timeLabel: _timeLabel(meeting.createdAt),
      title: meeting.title,
      metaLabel: _durationLabel(
        Duration(milliseconds: meeting.audioDurationMs),
      ),
      statusIcon: _meetingStatusIcon(meeting.status),
      statusLabel: _meetingLedgerStatus(meeting),
      emphasized: meeting.status == MeetingState.recording,
      selected: selected,
      showDivider: showDivider,
      semanticsLabel:
          '打开会议：${meeting.title}，${_meetingStatusLabel(meeting.status)}',
      semanticsHint: meeting.status == MeetingState.failed
          ? '查看失败原因和事实音频状态'
          : '查看会议详情',
      onPress: onPress,
    );
  }
}

final class _MeetingPreviewPlaceholder extends StatelessWidget {
  const _MeetingPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const AppStatePanel.empty(
      icon: FLucideIcons.fileAudio,
      title: '选择一场会议',
      message: '会议事实、录音状态和模型来源会显示在这里。',
    );
  }
}

final class _MeetingPreviewPane extends StatelessWidget {
  const _MeetingPreviewPane({
    required this.meeting,
    required this.onOpenMeeting,
    super.key,
  });

  final Meeting meeting;
  final ValueChanged<Meeting>? onOpenMeeting;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return ColoredBox(
      color: theme.colors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(appStyle.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    meeting.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.display.xl,
                  ),
                  SizedBox(height: appStyle.spaceMd),
                  _MeetingPreviewStatus(meeting: meeting),
                  SizedBox(height: appStyle.spaceLg),
                  _MeetingFactRow(
                    icon: FLucideIcons.calendar,
                    label: '开始时间',
                    value: _fullDateTimeLabel(meeting.createdAt),
                  ),
                  _MeetingFactRow(
                    icon: FLucideIcons.clock4,
                    label: '录音时长',
                    value: _durationLabel(
                      Duration(milliseconds: meeting.audioDurationMs),
                    ),
                  ),
                  _MeetingFactRow(
                    icon: FLucideIcons.fileAudio,
                    label: '事实音频',
                    value: _audioFactLabel(meeting),
                  ),
                  _MeetingFactRow(
                    icon: FLucideIcons.settings,
                    label: '本场模型',
                    value: _modelDisplayLabel(meeting),
                  ),
                  SizedBox(height: appStyle.spaceLg),
                  Text('会议事实', style: theme.typography.display.lg),
                  SizedBox(height: appStyle.spaceSm),
                  Text(
                    _meetingFactDescription(meeting),
                    style: theme.typography.body.md.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  SizedBox(height: appStyle.spaceLg),
                  _OpenMeetingRow(
                    enabled: onOpenMeeting != null,
                    onPress: onOpenMeeting == null
                        ? null
                        : () => onOpenMeeting!(meeting),
                  ),
                ],
              ),
            ),
          ),
          _PreviewBottomStatus(
            recording: meeting.status == MeetingState.recording,
          ),
        ],
      ),
    );
  }
}

final class _MeetingPreviewStatus extends StatelessWidget {
  const _MeetingPreviewStatus({required this.meeting});

  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colors.border,
          width: appStyle.dividerWidth,
        ),
        borderRadius: BorderRadius.circular(appStyle.cardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: appStyle.spaceSm,
          vertical: appStyle.spaceXs,
        ),
        child: Row(
          children: [
            if (meeting.status == MeetingState.recording)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colors.foreground,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 8),
              )
            else
              Icon(_meetingStatusIcon(meeting.status), size: 16),
            SizedBox(width: appStyle.spaceXs),
            Text(
              _meetingStatusLabel(meeting.status),
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: appStyle.spaceSm),
            Container(
              width: appStyle.dividerWidth,
              height: 16,
              color: theme.colors.border,
            ),
            SizedBox(width: appStyle.spaceSm),
            Text(
              _durationLabel(Duration(milliseconds: meeting.audioDurationMs)),
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                meeting.status == MeetingState.recording
                    ? '实时转录仅供参考'
                    : '事实音频本地优先',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _MeetingFactRow extends StatelessWidget {
  const _MeetingFactRow({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: appStyle.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19),
            SizedBox(width: appStyle.spaceMd),
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: theme.typography.body.sm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: appStyle.spaceSm),
            Expanded(child: Text(value, style: theme.typography.body.sm)),
          ],
        ),
      ),
    );
  }
}

final class _OpenMeetingRow extends StatelessWidget {
  const _OpenMeetingRow({required this.enabled, required this.onPress});

  final bool enabled;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: appStyle.spaceMd),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '打开完整记录',
                style: theme.typography.body.md.copyWith(
                  color: enabled
                      ? theme.colors.foreground
                      : theme.colors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              FLucideIcons.chevronRight,
              size: 19,
              color: theme.colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
    if (!enabled) {
      return content;
    }
    return FTappable(
      key: const ValueKey('open-selected-meeting'),
      semanticsLabel: '打开完整会议记录',
      onPress: onPress,
      child: content,
    );
  }
}

final class _PreviewBottomStatus extends StatelessWidget {
  const _PreviewBottomStatus({required this.recording});

  final bool recording;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: appStyle.spaceLg,
            vertical: appStyle.spaceSm,
          ),
          child: Row(
            children: [
              const Icon(FLucideIcons.shieldCheck, size: 17),
              SizedBox(width: appStyle.spaceXs),
              const Expanded(child: Text('事实音频本地优先')),
              if (recording)
                Text(
                  '录音不中断',
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
      ),
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

String _meetingLedgerStatus(Meeting meeting) => switch (meeting.status) {
  MeetingState.created => '准备中',
  MeetingState.recording => '录音中',
  MeetingState.processing => '正在生成最终转录',
  MeetingState.completed when meeting.audioPath?.isNotEmpty == true =>
    '事实音频已保存',
  MeetingState.completed => '已完成',
  MeetingState.failed when meeting.audioPath?.isNotEmpty == true =>
    '处理失败 · 事实音频已保存',
  MeetingState.failed => '失败 · 打开查看事实音频状态',
};

String _audioFactLabel(Meeting meeting) => switch (meeting.status) {
  MeetingState.created => '录音尚未开始',
  MeetingState.recording => '正在本机持续写入',
  _ when meeting.audioPath?.isNotEmpty == true => '已保存在本机',
  MeetingState.processing => '正在封存',
  MeetingState.completed => '会议处理已完成',
  MeetingState.failed => '打开会议查看保存状态',
};

String _meetingFactDescription(Meeting meeting) => switch (meeting.status) {
  MeetingState.created => '录音尚未开始。本场模型会在开始后锁定。',
  MeetingState.recording => '事实音频正在本机持续写入。推理变慢或失败不会中断录音。',
  MeetingState.processing => '事实音频已经封存，当前正在使用本场锁定模型生成最终转录。',
  MeetingState.completed when meeting.activeTranscriptSnapshotId != null =>
    '最终转录已经就绪。打开完整记录可查看转录、总结与带时间戳的原文证据。',
  MeetingState.completed => '会议处理已经完成。打开完整记录可查看当前可用结果。',
  MeetingState.failed when meeting.audioPath?.isNotEmpty == true =>
    '派生处理失败，但事实音频仍保存在本机。打开完整记录可查看原因并重试。',
  MeetingState.failed => '会议处理失败。打开完整记录可核对原因和事实音频状态。',
};

String _modelDisplayLabel(Meeting meeting) {
  final descriptor = AsrModelRegistry.alpha.findById(meeting.recordingModelId);
  final displayName = descriptor?.displayName ?? '本地模型';
  return '$displayName · ${meeting.recordingModelVersion}';
}

String _dateLabel(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _fullDateTimeLabel(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}  '
      '${two(value.hour)}:${two(value.minute)}';
}

String _timeLabel(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}

String _durationLabel(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
