import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/meeting.dart';
import '../../../../../../domain/models/workflow_states.dart';
import '../../../../../core/app_ledger.dart';
import '../../../../../core/semantic_date_time.dart';
import 'meeting_list_formatters.dart';

final class MeetingLedgerRow extends StatelessWidget {
  const MeetingLedgerRow({
    required this.meeting,
    required this.referenceTime,
    required this.deleting,
    required this.deletable,
    required this.selected,
    required this.onPress,
    required this.showDivider,
    super.key,
  });

  final Meeting meeting;
  final DateTime referenceTime;
  final bool deleting;
  final bool deletable;
  final bool selected;
  final VoidCallback? onPress;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return AppLedgerRow(
      key: ValueKey('meeting-${meeting.id}'),
      dateLabel: semanticCompactDateLabel(
        meeting.createdAt,
        reference: referenceTime,
      ),
      timeLabel: clockTimeLabel(meeting.createdAt),
      title: meeting.title,
      metaLabel: meetingDurationLabel(
        Duration(milliseconds: meeting.audioDurationMs),
      ),
      statusIcon: deleting
          ? FLucideIcons.loaderCircle
          : meetingStatusIcon(meeting.status),
      statusLabel: deleting ? '正在删除' : meetingLedgerStatus(meeting),
      emphasized: meeting.status == MeetingState.recording,
      selected: selected,
      showDivider: showDivider,
      semanticsLabel:
          '打开会议：${meeting.title}，'
          '${semanticDateTimeLabel(meeting.createdAt, reference: referenceTime)}，'
          '${meetingStatusLabel(meeting.status)}',
      semanticsHint: deleting
          ? '正在删除本机会议数据'
          : [
              if (meeting.status == MeetingState.failed)
                '查看失败原因和事实音频状态'
              else
                '查看会议详情',
              if (deletable) '向左滑动显示删除操作',
            ].join('；'),
      onPress: onPress,
    );
  }
}
