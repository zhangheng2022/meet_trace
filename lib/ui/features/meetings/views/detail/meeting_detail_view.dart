// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Impeccable · page: meeting result · world: Evidence Ledger
// Composition C: compact evidence reading, expanded fact rail + workbench.

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

enum MeetingResultSection { transcript, recording }

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
  MeetingResultSection _section = MeetingResultSection.transcript;
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
        return PopScope(
          canPop: !viewModel.isProcessing,
          child: FScaffold(
            header: FHeader.nested(
              title: const Text('会议详情'),
              prefixes: [
                FHeaderAction(
                  icon: const AppBackIcon(semanticsLabel: '返回会议列表'),
                  onPress: viewModel.isProcessing ? null : widget.onBack,
                ),
              ],
            ),
            child: _body(context, viewModel),
          ),
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
        return AppPageBody(
          width: AppPageWidth.reading,
          child: _FailureCard(message: message, viewModel: viewModel),
        );
      }
      return const AppStatePanel.empty(
        icon: FLucideIcons.fileAudio,
        title: '暂无最终转录',
        message: '事实录音仍保存在本机，可稍后返回继续处理。',
      );
    }

    return _ResultView(
      viewModel: viewModel,
      section: _section,
      editingTranscript: _editingTranscript,
      onSectionChanged: (section) {
        setState(() {
          _section = section;
          if (section != MeetingResultSection.transcript) {
            _editingTranscript = false;
          }
        });
      },
      onEditingChanged: (editing) {
        setState(() => _editingTranscript = editing);
      },
      onDeleted: widget.onDeleted,
    );
  }
}
