import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../domain/models/meeting.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../theme/theme.dart';
import '../../../../core/app_ledger.dart';
import '../../../../core/app_responsive.dart';
import '../../../../core/app_state_panel.dart';
import '../../../../core/app_swipe_action_row.dart';
import '../../../../core/view_state.dart';
import '../../view_models/list/meeting_list_view_model.dart';
import 'widgets/meeting_ledger_row.dart';
import 'widgets/meeting_list_chrome.dart';
import 'widgets/meeting_preview_pane.dart';

final class MeetingListContent extends StatefulWidget {
  const MeetingListContent({
    required this.state,
    required this.readiness,
    this.startingMeeting = false,
    required this.onStartMeeting,
    required this.onOpenMeeting,
    this.onOpenRecordingConditions,
    this.onRetryReadiness,
    this.deletingMeetingIds = const <String>{},
    this.renamingMeetingIds = const <String>{},
    this.canDeleteMeeting,
    this.canRenameMeeting,
    this.onDeleteMeeting,
    this.onRenameMeeting,
    this.now,
    super.key,
  });

  final ViewState<List<Meeting>> state;
  final MeetingReadinessViewState readiness;
  final bool startingMeeting;
  final VoidCallback? onStartMeeting;
  final ValueChanged<Meeting>? onOpenMeeting;
  final VoidCallback? onOpenRecordingConditions;
  final Future<void> Function()? onRetryReadiness;
  final Set<String> deletingMeetingIds;
  final Set<String> renamingMeetingIds;
  final bool Function(Meeting)? canDeleteMeeting;
  final bool Function(Meeting)? canRenameMeeting;
  final Future<void> Function(Meeting)? onDeleteMeeting;
  final Future<void> Function(Meeting)? onRenameMeeting;
  final DateTime Function()? now;

  @override
  State<MeetingListContent> createState() => _MeetingListContentState();
}

final class _MeetingListContentState extends State<MeetingListContent> {
  String? _selectedMeetingId;
  String? _revealedMeetingId;

  @override
  void didUpdateWidget(covariant MeetingListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedId = _selectedMeetingId;
    if (selectedId == null) {
      return;
    }
    final previous = _meetingsFrom(oldWidget.state);
    final current = _meetingsFrom(widget.state);
    if (current.any((meeting) => meeting.id == selectedId)) {
      return;
    }
    final previousIndex = previous.indexWhere(
      (meeting) => meeting.id == selectedId,
    );
    if (current.isEmpty) {
      _selectedMeetingId = null;
      return;
    }
    final nextIndex = previousIndex < 0
        ? 0
        : previousIndex.clamp(0, current.length - 1);
    _selectedMeetingId = current[nextIndex].id;
  }

  @override
  Widget build(BuildContext context) {
    return AppResponsiveBuilder(
      builder: (context, sizeClass, constraints) {
        final meetings = _meetingsFrom(widget.state);
        final selected = _selectedMeeting(meetings);
        final referenceTime = widget.now?.call() ?? DateTime.now();
        final listBody = _listBody(context, meetings, sizeClass, referenceTime);
        final homePane = MeetingHomePane(
          total: widget.state is ViewData<List<Meeting>>
              ? meetings.length
              : null,
          readiness: widget.readiness,
          startingMeeting: widget.startingMeeting,
          onOpenRecordingConditions: widget.onOpenRecordingConditions,
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
                        ? const MeetingPreviewPlaceholder()
                        : MeetingPreviewPane(
                            key: ValueKey('meeting-preview-${selected.id}'),
                            meeting: selected,
                            referenceTime: referenceTime,
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

  Widget _listBody(
    BuildContext context,
    List<Meeting> meetings,
    AppWindowSizeClass sizeClass,
    DateTime referenceTime,
  ) {
    final l10n = context.l10n;
    return switch (widget.state) {
      ViewLoading() => AppStatePanel.loading(label: l10n.loadingMeetings),
      ViewError(:final retry) => AppStatePanel.error(
        title: l10n.meetingLoadFailed,
        message: l10n.localDataPreservedRetry,
        actionLabel: retry == null ? null : l10n.retryLoading,
        onAction: retry,
      ),
      ViewData(:final value) when value.isEmpty => AppStatePanel.empty(
        icon: FLucideIcons.calendar,
        title: l10n.noMeetings,
        message: l10n.noMeetingsDescription,
      ),
      ViewData() => NotificationListener<ScrollStartNotification>(
        onNotification: (_) {
          if (_revealedMeetingId != null) {
            setState(() => _revealedMeetingId = null);
          }
          return false;
        },
        child: ListView(
          key: const ValueKey('meeting-ledger'),
          padding: EdgeInsets.zero,
          children: [
            AppLedgerSurface(
              framed: false,
              children: [
                for (var index = 0; index < meetings.length; index++)
                  _swipeRow(meetings, index, sizeClass, referenceTime),
              ],
            ),
          ],
        ),
      ),
    };
  }

  Widget _swipeRow(
    List<Meeting> meetings,
    int index,
    AppWindowSizeClass sizeClass,
    DateTime referenceTime,
  ) {
    final l10n = context.l10n;
    final meeting = meetings[index];
    final deleting = widget.deletingMeetingIds.contains(meeting.id);
    final renaming = widget.renamingMeetingIds.contains(meeting.id);
    final canDelete =
        !deleting && (widget.canDeleteMeeting?.call(meeting) ?? false);
    final canRename =
        !renaming && (widget.canRenameMeeting?.call(meeting) ?? false);
    void requestRename() {
      setState(() => _revealedMeetingId = null);
      unawaited(widget.onRenameMeeting?.call(meeting));
    }

    void requestDelete() {
      setState(() => _revealedMeetingId = null);
      unawaited(widget.onDeleteMeeting?.call(meeting));
    }

    final actions = [
      if (canRename)
        AppSwipeAction(
          key: ValueKey('rename-meeting-${meeting.id}'),
          label: l10n.rename,
          icon: FLucideIcons.pencil,
          semanticsHint: l10n.renameMeetingHint,
          onPress: requestRename,
        ),
      if (canDelete)
        AppSwipeAction(
          key: ValueKey('delete-meeting-${meeting.id}'),
          label: l10n.delete,
          icon: FLucideIcons.trash2,
          tone: AppSwipeActionTone.destructive,
          semanticsHint: l10n.deleteMeetingHint,
          onPress: requestDelete,
        ),
    ];
    final revealed = actions.isNotEmpty && _revealedMeetingId == meeting.id;
    return AppSwipeActionRow(
      key: ValueKey('swipe-meeting-${meeting.id}'),
      revealed: revealed,
      enabled: actions.isNotEmpty,
      onSwipeStart: () {
        final revealedId = _revealedMeetingId;
        if (revealedId != null && revealedId != meeting.id) {
          setState(() => _revealedMeetingId = null);
        }
      },
      onRevealChanged: (value) =>
          setState(() => _revealedMeetingId = value ? meeting.id : null),
      actions: actions,
      child: MeetingLedgerRow(
        meeting: meeting,
        referenceTime: referenceTime,
        deleting: deleting,
        renaming: renaming,
        deletable: canDelete,
        renameable: canRename,
        selected:
            sizeClass == AppWindowSizeClass.expanded &&
            meeting.id == _selectedMeeting(meetings)?.id,
        onPress: () {
          if (_revealedMeetingId != null) {
            setState(() => _revealedMeetingId = null);
            return;
          }
          if (sizeClass == AppWindowSizeClass.expanded) {
            setState(() => _selectedMeetingId = meeting.id);
          } else {
            widget.onOpenMeeting?.call(meeting);
          }
        },
        onRename: canRename ? requestRename : null,
        onDelete: canDelete ? requestDelete : null,
        showDivider: index < meetings.length - 1,
      ),
    );
  }
}

List<Meeting> _meetingsFrom(ViewState<List<Meeting>> state) => switch (state) {
  ViewData(:final value) => value,
  _ => const <Meeting>[],
};
