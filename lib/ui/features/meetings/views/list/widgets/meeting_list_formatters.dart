import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/meeting.dart';
import '../../../../../../domain/models/workflow_states.dart';

IconData meetingStatusIcon(MeetingState state) => switch (state) {
  MeetingState.created => FLucideIcons.circleDashed,
  MeetingState.recording => FLucideIcons.square,
  MeetingState.processing => FLucideIcons.audioLines,
  MeetingState.completed => FLucideIcons.circleCheck,
  MeetingState.failed => FLucideIcons.circleAlert,
};

String meetingStatusLabel(MeetingState state) => switch (state) {
  MeetingState.created => '准备中',
  MeetingState.recording => '录音中',
  MeetingState.processing => '处理中',
  MeetingState.completed => '已完成',
  MeetingState.failed => '失败',
};

String meetingLedgerStatus(Meeting meeting) => switch (meeting.status) {
  MeetingState.created => '准备中',
  MeetingState.recording => '录音中',
  MeetingState.processing => '正在生成最终转录',
  MeetingState.completed => '已完成',
  MeetingState.failed when meeting.audioPath?.isNotEmpty == true => '处理失败',
  MeetingState.failed => '失败 · 打开查看事实音频状态',
};

String meetingDurationLabel(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
