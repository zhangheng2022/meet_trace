// THESIS: 会议详情是一张可核对的事实工作台，不是转录与录音分离的卡片仪表盘。
// OWN-WORLD: 暖灰账本纸、连续时间轨、细边界、低曲率与零静止阴影。
// STORY: 用户先确认本地事实音频，再沿时间轨阅读、修订并分享最终结果。
// FIRST VIEWPORT: 标题与录音证据在上，紧凑最终转录直接展开，分享收进标题栏。
// FORM: 已确认的 Evidence Ledger 单列阅读稿；宽屏转为 280px 事实栏与转录工作区。

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../keys.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../core/app_back_icon.dart';
import '../../../../core/app_state_panel.dart';
import '../../view_models/detail/meeting_detail_view_model.dart';
import 'audio/meeting_audio_actions.dart';
import 'processing/meeting_processing_view.dart';
import 'transcript/meeting_transcript_section.dart';
import 'widgets/meeting_result_layout.dart';

final class MeetingDetailView extends StatefulWidget {
  const MeetingDetailView({
    required this.viewModel,
    required this.onBack,
    this.onDeleted,
    super.key,
  });

  final MeetingDetailViewModel viewModel;
  final VoidCallback onBack;
  final VoidCallback? onDeleted;

  @override
  State<MeetingDetailView> createState() => _MeetingDetailViewState();
}

final class _MeetingDetailViewState extends State<MeetingDetailView> {
  final GlobalKey<TranscriptSectionState> _transcriptKey = GlobalKey();
  bool _editingTranscript = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        return FScaffold(
          childPad: false,
          header: FHeader.nested(
            title: Text(
              context.l10n.meetingDetailsTitle,
              key: keys.meetings.detailTitle,
            ),
            prefixes: [
              FHeaderAction(
                icon: AppBackIcon(semanticsLabel: context.l10n.backToMeetings),
                onPress: widget.onBack,
              ),
            ],
            suffixes: [
              if (viewModel.snapshot != null &&
                  !viewModel.isTranscribing &&
                  !_editingTranscript) ...[
                MeetingShareActionButton(viewModel: viewModel),
                MeetingMoreActionsButton(
                  viewModel: viewModel,
                  onDeleted: widget.onDeleted,
                ),
              ],
            ],
          ),
          footer:
              viewModel.snapshot != null &&
                  !viewModel.isTranscribing &&
                  _editingTranscript
              ? TranscriptEditBottomBar(
                  saving: viewModel.isProcessing,
                  onCancel: () {
                    setState(() => _editingTranscript = false);
                  },
                  onSave: () => unawaited(
                    _transcriptKey.currentState?.saveRevision() ??
                        Future<void>.value(),
                  ),
                )
              : null,
          child: _body(context, viewModel),
        );
      },
    );
  }

  Widget _body(BuildContext context, MeetingDetailViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.isTranscribing) {
      return AppStatePanel.loading(label: context.l10n.loadingMeetingResult);
    }

    if (viewModel.isTranscribing) {
      return MeetingProcessingView(viewModel: viewModel);
    }

    if (viewModel.snapshot == null) {
      final message = viewModel.errorMessage;
      if (message != null) {
        return MeetingFailureView(message: message, viewModel: viewModel);
      }
      return AppStatePanel.empty(
        icon: FLucideIcons.fileAudio,
        title: context.l10n.noFinalTranscript,
        message: context.l10n.sourceAudioReturnLater,
      );
    }

    return MeetingResultView(
      viewModel: viewModel,
      transcriptKey: _transcriptKey,
      editingTranscript: _editingTranscript,
      onEditingChanged: (editing) {
        setState(() => _editingTranscript = editing);
      },
    );
  }
}
