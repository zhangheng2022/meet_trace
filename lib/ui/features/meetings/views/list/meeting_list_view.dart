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
    final viewModel = widget.viewModel;
    return FScaffold(
      childPad: false,
      header: FHeader(
        title: const _MeetingListBrandTitle(),
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
      barrierLabel: '关闭录音条件面板',
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
    final confirmed = await showAppConfirmDialog(
      context: context,
      semanticsLabel: '永久删除${meeting.title}',
      title: '永久删除「${meeting.title}」？',
      message: '将删除本场事实音频、转录、说话人标签及处理记录。此操作无法撤销。',
      cancelLabel: '取消',
      confirmLabel: '永久删除',
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
      title: Text(deleted ? '会议及本地数据已删除' : '删除失败'),
      description: deleted
          ? Text(meeting.title)
          : Text(viewModel.deleteErrorMessage ?? '会议正在录音或处理中，暂时不能删除'),
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
        barrierLabel: '关闭重命名会议面板',
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
      title: const Text('会议标题已更新'),
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
    try {
      final confirmed = await showAppConfirmDialog(
        context: context,
        semanticsLabel: resetsData ? '更新会清除本地数据' : '发现会迹新版本',
        title: resetsData ? '更新前必须确认本地数据风险' : '新版本已通过公开发布门禁',
        message: resetsData
            ? '版本 ${candidate.versionName}（构建 ${candidate.buildNumber}）提高了数据代。安装后首次启动会清除本机会议音频、转录、模型和设置，并重新初始化。请先分享或导出需要保留的内容。'
            : '版本 ${candidate.versionName}（构建 ${candidate.buildNumber}）已准备好。继续后将交给系统安装器、TestFlight 或 Microsoft Store，系统仍可能要求你的确认。',
        cancelLabel: '稍后处理',
        confirmLabel: resetsData ? '确认风险并继续' : '继续更新',
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
            title: const Text('已交给系统更新'),
            description: const Text('录音和本地数据不会在应用内被强制中断'),
          );
          break;
        case AppUpdateDecisionKind.deferred:
          _promptedUpdateReleaseIds.remove(candidate.releaseId);
          showFToast(
            context: context,
            variant: FToastVariant.primary,
            icon: const Icon(FLucideIcons.clock),
            title: const Text('更新已延后'),
            description: const Text('会议录音或最终处理结束后再提示'),
          );
          break;
        case AppUpdateDecisionKind.installHandoffFailed:
          _promptedUpdateReleaseIds.remove(candidate.releaseId);
          showFToast(
            context: context,
            variant: FToastVariant.destructive,
            icon: const Icon(FLucideIcons.circleAlert),
            title: const Text('暂时无法打开系统更新'),
            description: const Text('请检查系统安装授权后重试'),
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
      label: '会迹，MeetTrace',
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
