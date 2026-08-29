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

import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/models/app_update.dart';
import '../../../../../keys.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../l10n/ui_message_localizations.dart';
import '../../../../core/app_dialog.dart';
import '../../../../core/branding/meettrace_brand_mark.dart';
import '../../../../core/view_state.dart';
import '../../view_models/list/meeting_list_view_model.dart';
import '../../../updates/view_models/app_update_view_model.dart';
import 'meeting_list_content.dart';
import 'widgets/recording_conditions_sheet.dart';
import 'widgets/rename_meeting_sheet.dart';

final class MeetingListView extends StatefulWidget {
  const MeetingListView({
    this.viewModel,
    this.updateViewModel,
    this.startingMeeting = false,
    this.onStartMeeting,
    this.onOpenMeeting,
    this.onOpenSettings,
    this.onRepairRuntime,
    this.now,
    super.key,
  });

  final MeetingListViewModel? viewModel;
  final AppUpdateViewModel? updateViewModel;
  final bool startingMeeting;
  final VoidCallback? onStartMeeting;
  final ValueChanged<Meeting>? onOpenMeeting;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRepairRuntime;
  final DateTime Function()? now;

  @override
  State<MeetingListView> createState() => _MeetingListViewState();
}

final class _MeetingListViewState extends State<MeetingListView> {
  bool _deleteDialogOpen = false;
  bool _renameSheetOpen = false;
  bool _updateDialogOpen = false;
  final Set<String> _promptedUpdateReleaseIds = {};

  @override
  void initState() {
    super.initState();
    widget.viewModel?.load();
    widget.updateViewModel?.addListener(_handleUpdateState);
    widget.updateViewModel?.start();
  }

  @override
  void didUpdateWidget(MeetingListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.updateViewModel, widget.updateViewModel)) {
      oldWidget.updateViewModel?.removeListener(_handleUpdateState);
      widget.updateViewModel?.addListener(_handleUpdateState);
      widget.updateViewModel?.start();
    }
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
    final l10n = context.l10n;
    final viewModel = widget.viewModel;
    return FScaffold(
      childPad: false,
      header: FHeader(
        title: const _MeetingListBrandTitle(),
        suffixes: [
          if (widget.onOpenSettings != null)
            FHeaderAction(
              icon: Icon(
                FLucideIcons.settings,
                semanticLabel: l10n.openSettings,
              ),
              onPress: widget.onOpenSettings,
            ),
        ],
      ),
      child: MeetingListContent(
        state: state,
        readiness:
            widget.viewModel?.readiness ??
            const MeetingReadinessViewState.unchecked(),
        startingMeeting: widget.startingMeeting,
        onStartMeeting: widget.onStartMeeting,
        onOpenMeeting: widget.onOpenMeeting,
        onOpenRecordingConditions: viewModel == null
            ? null
            : () => unawaited(_showRecordingConditions(viewModel)),
        onRetryReadiness: widget.viewModel?.refreshReadiness,
        deletingMeetingIds:
            widget.viewModel?.deletingMeetingIds ?? const <String>{},
        renamingMeetingIds:
            widget.viewModel?.renamingMeetingIds ?? const <String>{},
        canDeleteMeeting: widget.viewModel?.canDeleteMeeting,
        canRenameMeeting: widget.viewModel?.canRenameMeeting,
        now: widget.now,
        onDeleteMeeting: widget.viewModel == null
            ? null
            : _requestDeleteMeeting,
        onRenameMeeting: widget.viewModel == null
            ? null
            : _requestRenameMeeting,
      ),
    );
  }

  Future<void> _showRecordingConditions(MeetingListViewModel viewModel) async {
    final action = await showFSheet<RecordingConditionsAction>(
      context: context,
      side: FLayout.btt,
      useSafeArea: true,
      mainAxisMaxRatio: 0.72,
      barrierLabel: context.l10n.closeRecordingConditions,
      builder: (context) => RecordingConditionsSheet(
        readiness: viewModel.readiness,
        canRepairRuntime: widget.onRepairRuntime != null,
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case RecordingConditionsAction.requestMicrophonePermission:
        await viewModel.requestMicrophonePermission();
        return;
      case RecordingConditionsAction.recheck:
        await viewModel.refreshReadiness();
        return;
      case RecordingConditionsAction.repairRuntime:
        widget.onRepairRuntime?.call();
        return;
    }
  }

  Future<void> _requestDeleteMeeting(Meeting meeting) async {
    final viewModel = widget.viewModel;
    if (_deleteDialogOpen ||
        viewModel == null ||
        !viewModel.canDeleteMeeting(meeting)) {
      return;
    }
    _deleteDialogOpen = true;
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context: context,
      semanticsLabel: l10n.permanentlyDeleteMeetingSemantics(meeting.title),
      title: l10n.permanentlyDeleteMeetingQuestion(meeting.title),
      message: l10n.permanentlyDeleteMeetingMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.permanentlyDelete,
      destructive: true,
      cancelAutofocus: true,
      confirmKey: ValueKey('confirm-delete-meeting-${meeting.id}'),
    );
    _deleteDialogOpen = false;
    if (confirmed != true || !mounted) {
      return;
    }

    final deleted = await viewModel.deleteMeeting(meeting);
    if (!mounted) {
      return;
    }
    showFToast(
      context: context,
      variant: deleted ? FToastVariant.primary : FToastVariant.destructive,
      icon: Icon(deleted ? FLucideIcons.circleCheck : FLucideIcons.circleAlert),
      title: Text(deleted ? l10n.meetingLocalDataDeleted : l10n.deleteFailed),
      description: deleted
          ? Text(meeting.title)
          : Text(
              viewModel.deleteErrorMessage == null
                  ? l10n.meetingCannotDeleteNow
                  : l10n.localizeUiMessage(viewModel.deleteErrorMessage!),
            ),
    );
  }

  Future<void> _requestRenameMeeting(Meeting meeting) async {
    final viewModel = widget.viewModel;
    if (_renameSheetOpen ||
        viewModel == null ||
        !viewModel.canRenameMeeting(meeting)) {
      return;
    }
    _renameSheetOpen = true;
    String? renamedTitle;
    try {
      renamedTitle = await showFSheet<String>(
        context: context,
        side: FLayout.btt,
        useSafeArea: true,
        mainAxisMaxRatio: 0.72,
        barrierLabel: context.l10n.closeRenameMeeting,
        builder: (context) => RenameMeetingSheet(
          meeting: meeting,
          onSave: (title) => viewModel.renameMeeting(meeting, title),
        ),
      );
    } finally {
      _renameSheetOpen = false;
    }
    if (renamedTitle == null || !mounted) {
      return;
    }
    showFToast(
      context: context,
      variant: FToastVariant.primary,
      icon: const Icon(FLucideIcons.circleCheck),
      title: Text(context.l10n.meetingTitleUpdated),
      description: Text(renamedTitle),
    );
  }

  void _handleUpdateState() {
    final decision = widget.updateViewModel?.decision;
    final candidate = decision?.candidate;
    if (candidate == null) {
      return;
    }
    if (decision!.kind == AppUpdateDecisionKind.deferred ||
        decision.kind == AppUpdateDecisionKind.installHandoffFailed) {
      _promptedUpdateReleaseIds.remove(candidate.releaseId);
      return;
    }
    if (_updateDialogOpen ||
        _promptedUpdateReleaseIds.contains(candidate.releaseId) ||
        (decision.kind != AppUpdateDecisionKind.readyToInstall &&
            decision.kind != AppUpdateDecisionKind.dataResetWarningRequired)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_promptUpdate(candidate, decision.kind));
      }
    });
  }

  Future<void> _promptUpdate(
    AppUpdateCandidate candidate,
    AppUpdateDecisionKind kind,
  ) async {
    final viewModel = widget.updateViewModel;
    if (_updateDialogOpen ||
        viewModel == null ||
        _promptedUpdateReleaseIds.contains(candidate.releaseId)) {
      return;
    }
    _updateDialogOpen = true;
    _promptedUpdateReleaseIds.add(candidate.releaseId);
    final resetsData = kind == AppUpdateDecisionKind.dataResetWarningRequired;
    final l10n = context.l10n;
    try {
      final confirmed = await showAppConfirmDialog(
        context: context,
        semanticsLabel: resetsData
            ? l10n.updateClearsLocalData
            : l10n.newVersionFound,
        title: resetsData
            ? l10n.confirmUpdateDataRisk
            : l10n.newVersionPassedReleaseGate,
        message: resetsData
            ? l10n.destructiveUpdateMessage(
                candidate.versionName,
                candidate.buildNumber,
              )
            : l10n.updateReadyMessage(
                candidate.versionName,
                candidate.buildNumber,
              ),
        cancelLabel: l10n.handleLater,
        confirmLabel: resetsData
            ? l10n.confirmRiskContinue
            : l10n.continueUpdate,
        destructive: resetsData,
        cancelAutofocus: true,
        confirmKey: const ValueKey('confirm-app-update'),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      final decision = await viewModel.install(
        dataResetAcknowledged: resetsData,
      );
      if (!mounted) {
        return;
      }
      switch (decision.kind) {
        case AppUpdateDecisionKind.installHandedOff:
          showFToast(
            context: context,
            variant: FToastVariant.primary,
            icon: const Icon(FLucideIcons.externalLink),
            title: Text(l10n.updateHandedToSystem),
            description: Text(l10n.updateDoesNotForceInterrupt),
          );
          break;
        case AppUpdateDecisionKind.deferred:
          _promptedUpdateReleaseIds.remove(candidate.releaseId);
          showFToast(
            context: context,
            variant: FToastVariant.primary,
            icon: const Icon(FLucideIcons.clock),
            title: Text(l10n.updateDeferred),
            description: Text(l10n.updateDeferredDescription),
          );
          break;
        case AppUpdateDecisionKind.installHandoffFailed:
          _promptedUpdateReleaseIds.remove(candidate.releaseId);
          showFToast(
            context: context,
            variant: FToastVariant.destructive,
            icon: const Icon(FLucideIcons.circleAlert),
            title: Text(l10n.cannotOpenSystemUpdate),
            description: Text(l10n.checkSystemInstallAuthorization),
          );
          break;
        default:
          break;
      }
    } finally {
      _updateDialogOpen = false;
    }
  }

  @override
  void dispose() {
    widget.updateViewModel?.removeListener(_handleUpdateState);
    super.dispose();
  }
}

final class _MeetingListBrandTitle extends StatelessWidget {
  const _MeetingListBrandTitle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: keys.meetings.listBrandTitle,
      container: true,
      header: true,
      label: context.l10n.brandSemantics,
      child: ExcludeSemantics(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: MeetTraceBrandMark(key: keys.meetings.listBrandMark, size: 28),
        ),
      ),
    );
  }
}

/// 会议列表的纯展示内容，供页面和组件预览复用。
