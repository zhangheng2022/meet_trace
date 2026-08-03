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

import '../../../../../domain/models/asr_model_registry.dart';
import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/models/workflow_states.dart';
import '../../../../../theme/theme.dart';
import '../../../../core/app_ledger.dart';
import '../../../../core/app_dialog.dart';
import '../../../../core/app_responsive.dart';
import '../../../../core/app_state_panel.dart';
import '../../../../core/app_swipe_action_row.dart';
import '../../../../core/semantic_date_time.dart';
import '../../../../core/view_state.dart';
import '../../view_models/list/meeting_list_view_model.dart';

part 'meeting_list_content.dart';
part 'widgets/meeting_list_chrome.dart';
part 'widgets/meeting_ledger_row.dart';
part 'widgets/meeting_preview_pane.dart';

final class MeetingListView extends StatefulWidget {
  const MeetingListView({
    this.viewModel,
    this.startingMeeting = false,
    this.onStartMeeting,
    this.onOpenMeeting,
    this.onOpenSettings,
    this.now,
    super.key,
  });

  final MeetingListViewModel? viewModel;
  final bool startingMeeting;
  final VoidCallback? onStartMeeting;
  final ValueChanged<Meeting>? onOpenMeeting;
  final VoidCallback? onOpenSettings;
  final DateTime Function()? now;

  @override
  State<MeetingListView> createState() => _MeetingListViewState();
}

final class _MeetingListViewState extends State<MeetingListView> {
  bool _deleteDialogOpen = false;

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
        startingMeeting: widget.startingMeeting,
        onStartMeeting: widget.onStartMeeting,
        onOpenMeeting: widget.onOpenMeeting,
        onOpenSettings: widget.onOpenSettings,
        onRetryReadiness: widget.viewModel?.refreshReadiness,
        deletingMeetingIds:
            widget.viewModel?.deletingMeetingIds ?? const <String>{},
        canDeleteMeeting: widget.viewModel?.canDeleteMeeting,
        now: widget.now,
        onDeleteMeeting: widget.viewModel == null
            ? null
            : _requestDeleteMeeting,
      ),
    );
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
      message: '将删除本场事实音频、转录、AI 总结、证据索引及处理记录。此操作无法撤销。',
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
}

/// 会议列表的纯展示内容，供页面和组件预览复用。
