// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Impeccable · page: recording-workbench · world: Evidence Ledger
// Composition B: the stable recorder instrument owns the first viewport.
// States: starting · recording · paused · backlogged · recording-only · finalizing · failed

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/models/workflow_states.dart';
import '../../../../../theme/theme.dart';
import '../../../../core/app_back_icon.dart';
import '../../../../core/app_dialog.dart';
import '../../../../core/app_page_body.dart';
import '../../view_models/recording/recording_session_view_model.dart';
import 'widgets/live_transcript_panel.dart';
import 'widgets/recording_controls.dart';
import 'widgets/recording_facts_panel.dart';

final class RecordingSessionView extends StatefulWidget {
  const RecordingSessionView({
    required this.viewModel,
    required this.onFinished,
    super.key,
  });

  final RecordingSessionViewModel viewModel;
  final ValueChanged<Meeting> onFinished;

  @override
  State<RecordingSessionView> createState() => _RecordingSessionViewState();
}

final class _RecordingSessionViewState extends State<RecordingSessionView> {
  bool _endDialogOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.start());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final active =
            _isActive(widget.viewModel.recordingState) ||
            widget.viewModel.canStop;
        return PopScope(
          canPop: !active,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && active) {
              unawaited(_requestEnd());
            }
          },
          child: FScaffold(
            childPad: false,
            header: FHeader.nested(
              title: const Text('会迹'),
              prefixes: [
                FHeaderAction(
                  icon: const AppBackIcon(semanticsLabel: '结束会议并返回'),
                  onPress: active ? () => unawaited(_requestEnd()) : null,
                ),
              ],
            ),
            footer: RecordingBottomBar(
              viewModel: widget.viewModel,
              onEnd: () => unawaited(_requestEnd()),
            ),
            child: _body(context),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final appStyle = context.theme.style.app;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= appStyle.wideLayoutMinWidth;
        final facts = RecordingFactsPanel(
          viewModel: widget.viewModel,
          wide: wide,
        );
        final transcript = LiveTranscriptPanel(
          viewModel: widget.viewModel,
          outlined: wide,
        );
        final content = wide
            ? Row(
                key: const ValueKey('recording-wide-layout'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 8, child: facts),
                  SizedBox(width: appStyle.spaceXl),
                  Expanded(flex: 12, child: transcript),
                ],
              )
            : Column(
                key: const ValueKey('recording-compact-layout'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  facts,
                  SizedBox(height: appStyle.spaceXl),
                  transcript,
                ],
              );
        return SingleChildScrollView(
          child: AppPageBody(width: AppPageWidth.wide, child: content),
        );
      },
    );
  }

  Future<void> _requestEnd() async {
    if (_endDialogOpen ||
        (!_isActive(widget.viewModel.recordingState) &&
            !widget.viewModel.canStop)) {
      return;
    }
    _endDialogOpen = true;
    final confirmed = await showAppConfirmDialog(
      context: context,
      semanticsLabel: '结束并保存会议',
      title: '结束并保存会议？',
      message: '结束后会先封存本机事实音频，再进入最终转录。当前实时转录仅供预览。',
      cancelLabel: '继续录音',
      confirmLabel: '结束并保存',
      barrierDismissible: false,
      confirmAutofocus: true,
    );
    _endDialogOpen = false;
    if (confirmed == true && mounted) {
      await _stop();
    }
  }

  Future<void> _stop() async {
    final meeting = await widget.viewModel.stop();
    if (meeting != null && mounted) {
      widget.onFinished(meeting);
    }
  }
}

bool _isActive(RecordingState state) => {
  RecordingState.starting,
  RecordingState.recording,
  RecordingState.paused,
  RecordingState.finalizing,
}.contains(state);
