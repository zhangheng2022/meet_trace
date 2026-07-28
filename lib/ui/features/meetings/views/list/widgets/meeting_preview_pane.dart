part of '../meeting_list_view.dart';

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
    required this.referenceTime,
    required this.onOpenMeeting,
    super.key,
  });

  final Meeting meeting;
  final DateTime referenceTime;
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
                    value: semanticDateTimeLabel(
                      meeting.createdAt,
                      reference: referenceTime,
                    ),
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

String _durationLabel(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
