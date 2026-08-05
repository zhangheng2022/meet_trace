// THESIS: 会议详情是一张可核对的事实工作台，不是转录与录音分离的卡片仪表盘。
// OWN-WORLD: 暖灰账本纸、连续时间轨、细边界、低曲率与零静止阴影。
// STORY: 用户先确认本地事实音频，再沿时间轨阅读、修订并分享最终结果。
// FIRST VIEWPORT: 标题与录音证据在上，紧凑最终转录直接展开，分享固定在安全区。
// FORM: 已确认的 Evidence Ledger 单列阅读稿；宽屏转为 280px 事实栏与转录工作区。

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../domain/models/speaker_diarization.dart';
import '../../../../../domain/models/transcript.dart';
import '../../../../../domain/ports/audio_playback.dart';
import '../../../../../domain/use_cases/build_meeting_share.dart';
import '../../../../../domain/use_cases/revise_final_transcript.dart';
import '../../../../../theme/theme.dart';
import '../../../../core/app_back_icon.dart';
import '../../../../core/app_dialog.dart';
import '../../../../core/app_page_body.dart';
import '../../../../core/app_responsive.dart';
import '../../../../core/app_state_panel.dart';
import '../../../../core/app_status_notice.dart';
import '../../view_models/detail/meeting_detail_view_model.dart';

part 'processing/meeting_processing_view.dart';
part 'widgets/meeting_result_layout.dart';
part 'transcript/meeting_transcript_section.dart';
part 'audio/meeting_audio_actions.dart';

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
  final GlobalKey<_TranscriptSectionState> _transcriptKey = GlobalKey();
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
            title: const Text('会议详情'),
            prefixes: [
              FHeaderAction(
                icon: const AppBackIcon(semanticsLabel: '返回会议列表'),
                onPress: widget.onBack,
              ),
            ],
            suffixes: [
              if (viewModel.snapshot != null &&
                  !viewModel.isTranscribing &&
                  !_editingTranscript)
                _MeetingMoreActionsButton(
                  viewModel: viewModel,
                  onDeleted: widget.onDeleted,
                ),
            ],
          ),
          footer: viewModel.snapshot != null && !viewModel.isTranscribing
              ? _editingTranscript
                    ? _TranscriptEditBottomBar(
                        saving: viewModel.isProcessing,
                        onCancel: () {
                          setState(() => _editingTranscript = false);
                        },
                        onSave: () => unawaited(
                          _transcriptKey.currentState?.saveRevision() ??
                              Future<void>.value(),
                        ),
                      )
                    : _MeetingShareBottomBar(viewModel: viewModel)
              : null,
          child: _body(context, viewModel),
        );
      },
    );
  }

  Widget _body(BuildContext context, MeetingDetailViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.isTranscribing) {
      return const AppStatePanel.loading(label: '加载会议结果');
    }

    if (viewModel.isTranscribing) {
      return _ProcessingView(viewModel: viewModel);
    }

    if (viewModel.snapshot == null) {
      final message = viewModel.errorMessage;
      if (message != null) {
        return _FailureView(message: message, viewModel: viewModel);
      }
      return const AppStatePanel.empty(
        icon: FLucideIcons.fileAudio,
        title: '暂无最终转录',
        message: '事实录音仍保存在本机，可稍后返回继续处理。',
      );
    }

    return _ResultView(
      viewModel: viewModel,
      transcriptKey: _transcriptKey,
      editingTranscript: _editingTranscript,
      onEditingChanged: (editing) {
        setState(() => _editingTranscript = editing);
      },
    );
  }
}
