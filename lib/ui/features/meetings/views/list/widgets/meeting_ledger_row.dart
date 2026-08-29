import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/meeting.dart';
import '../../../../../../domain/models/workflow_states.dart';
import '../../../../../../l10n/l10n.dart';
import '../../../../../core/app_ledger.dart';
import '../../../../../core/semantic_date_time.dart';
import 'meeting_list_formatters.dart';

final class MeetingLedgerRow extends StatelessWidget {
  const MeetingLedgerRow({
    required this.meeting,
    required this.referenceTime,
    required this.deleting,
    required this.renaming,
    required this.deletable,
    required this.renameable,
    required this.selected,
    required this.onPress,
    this.onRename,
    this.onDelete,
    required this.showDivider,
    super.key,
  });

  final Meeting meeting;
  final DateTime referenceTime;
  final bool deleting;
  final bool renaming;
  final bool deletable;
  final bool renameable;
  final bool selected;
  final VoidCallback? onPress;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppLedgerRow(
      key: ValueKey('meeting-${meeting.id}'),
      dateLabel: semanticCompactDateLabel(
        meeting.createdAt,
        reference: referenceTime,
        l10n: l10n,
      ),
      timeLabel: clockTimeLabel(meeting.createdAt, locale: l10n.localeName),
      title: meeting.title,
      metaLabel: meetingDurationLabel(
        Duration(milliseconds: meeting.audioDurationMs),
      ),
      statusIcon: deleting || renaming
          ? FLucideIcons.loaderCircle
          : meetingStatusIcon(meeting.status),
      statusLabel: deleting
          ? l10n.deleting
          : renaming
          ? l10n.renaming
          : meetingLedgerStatus(l10n, meeting),
      emphasized: meeting.status == MeetingState.recording,
      selected: selected,
      showDivider: showDivider,
      semanticsLabel: l10n.openMeetingSemantics(
        meeting.title,
        semanticDateTimeLabel(
          meeting.createdAt,
          reference: referenceTime,
          l10n: l10n,
        ),
        meetingStatusLabel(l10n, meeting.status),
      ),
      semanticsHint: deleting || renaming
          ? deleting
                ? l10n.deletingLocalMeetingData
                : l10n.savingMeetingTitle
          : [
              if (meeting.status == MeetingState.failed)
                l10n.viewFailureAndAudio
              else
                l10n.viewMeetingDetails,
              if (renameable && deletable) l10n.swipeRenameDelete,
              if (renameable && !deletable) l10n.swipeRename,
            ].join(l10n.semanticSentenceSeparator),
      customSemanticsActions: _customSemanticsActions(l10n),
      onPress: onPress,
    );
  }

  Map<CustomSemanticsAction, VoidCallback> _customSemanticsActions(
    AppLocalizations l10n,
  ) {
    final actions = <CustomSemanticsAction, VoidCallback>{};
    final rename = onRename;
    final delete = onDelete;
    if (rename != null) {
      actions[CustomSemanticsAction(label: l10n.renameMeetingAction)] = rename;
    }
    if (delete != null) {
      actions[CustomSemanticsAction(label: l10n.deleteMeetingAction)] = delete;
    }
    return actions;
  }
}
