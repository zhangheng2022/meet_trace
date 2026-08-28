// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · previews: UI-03 recording flow · macrostructure: Recorder instrument

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../app/application.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/asr_preview.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/recording.dart';
import '../../../../domain/models/recording_input.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../domain/ports/asr_engine.dart';
import '../../../../domain/ports/asr_preview_session.dart';
import '../../../../domain/ports/recording_session.dart';
import '../../../../domain/use_cases/manage_recording_session.dart';
import '../../../../domain/use_cases/start_meeting.dart';
import '../view_models/recording/recording_session_view_model.dart';
import '../views/recording/recording_session_view.dart';
import 'support/preview_meeting_repository.dart';

part 'support/recording_preview_fixture.dart';

@Preview(name: '录音工作台 · 375', group: 'UI-03 录音工作台', size: Size(375, 800))
Widget recordingWorkbenchCompactPreview() =>
    _recordingPreview(AsrPreviewState.ready);

@Preview(name: '录音积压 · 414', group: 'UI-03 录音工作台', size: Size(414, 800))
Widget recordingBacklogPreview() =>
    _recordingPreview(AsrPreviewState.backlogged);

@Preview(name: '仅录音降级 · 1024', group: 'UI-03 录音工作台', size: Size(1024, 800))
Widget recordingOnlyExpandedPreview() =>
    _recordingPreview(AsrPreviewState.recordingOnly);

Widget _recordingPreview(AsrPreviewState state) {
  final descriptor = AsrModelRegistry.alpha.defaultModel;
  final meeting = Meeting(
    id: 'preview-recording-workbench',
    title: '产品 Alpha 评审',
    createdAt: DateTime(2026, 7, 25, 9, 30),
    startedAt: DateTime(2026, 7, 25, 9, 30),
    status: MeetingState.recording,
    audioDurationMs: 0,
    recordingModelId: descriptor.modelId,
    recordingModelVersion: descriptor.version,
  );
  final recording = _PreviewRecordingService();
  final preview = _PreviewSession(state);
  return Application(
    home: RecordingSessionView(
      viewModel: RecordingSessionViewModel(
        session: StartedMeetingSession(
          meeting: meeting,
          engine: _PreviewAsrEngine(descriptor),
          recordingInput: const LockedRecordingInput.systemDefault(),
        ),
        recording: recording,
        preview: preview,
        sessionLifecycle: ManageRecordingSessionUseCase(
          meetings: PreviewMeetingRepository(),
          recording: recording,
          preview: preview,
          now: () => DateTime(2026, 7, 25, 9, 44, 28),
        ),
        tickerFactory: (_, _) => Timer(const Duration(days: 1), () {}),
      ),
      onFinished: (_) {},
    ),
  );
}
