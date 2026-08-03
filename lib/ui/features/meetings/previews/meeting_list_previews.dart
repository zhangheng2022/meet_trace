// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · previews: UI-02 meeting flow · macrostructure: Evidence ledger

import 'package:flutter/widgets.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../app/application.dart';
import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/meeting_readiness.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../domain/ports/repositories.dart';
import '../../../../domain/use_cases/check_meeting_readiness.dart';
import '../../../../domain/use_cases/delete_meeting.dart';
import '../view_models/list/meeting_list_view_model.dart';
import '../views/list/meeting_list_view.dart';

part 'support/meeting_list_preview_fixture.dart';

@Preview(name: '会议列表 · 375', group: 'UI-02 会议主流程', size: Size(375, 760))
Widget meetingListCompactPreview() => Application(
  home: MeetingListView(
    viewModel: MeetingListViewModel(
      meetings: _PreviewMeetingRepository(_previewMeetings),
      readinessChecker: const _PreviewMeetingReadinessChecker(),
      deletion: DeleteMeetingUseCase(
        meetings: _PreviewMeetingRepository(_previewMeetings),
        files: const _PreviewMeetingFileDeletionService(),
      ),
    ),
    onStartMeeting: () {},
    onOpenMeeting: (_) {},
    onOpenSettings: () {},
  ),
);

@Preview(name: '会议列表 · 1024', group: 'UI-02 会议主流程', size: Size(1024, 760))
Widget meetingListExpandedPreview() => meetingListCompactPreview();

final _previewMeetings = <Meeting>[
  Meeting(
    id: 'preview-recording',
    title: '产品 Alpha 评审',
    createdAt: DateTime(2026, 7, 25, 9, 30),
    startedAt: DateTime(2026, 7, 25, 9, 30),
    status: MeetingState.recording,
    audioDurationMs: 14 * 60 * 1000 + 28 * 1000,
    requestedModelId: senseVoiceDefaultModelId,
    recordingModelId: senseVoiceDefaultModelId,
    recordingModelVersion: AsrModelRegistry.alpha.defaultModel.version,
  ),
  Meeting(
    id: 'preview-completed',
    title: '每周研究进展同步',
    createdAt: DateTime(2026, 7, 24, 15),
    startedAt: DateTime(2026, 7, 24, 15),
    endedAt: DateTime(2026, 7, 24, 15, 42),
    status: MeetingState.completed,
    audioPath: 'preview://meeting.wav',
    audioDurationMs: 42 * 60 * 1000 + 8 * 1000,
    requestedModelId: senseVoiceDefaultModelId,
    recordingModelId: senseVoiceDefaultModelId,
    recordingModelVersion: AsrModelRegistry.alpha.defaultModel.version,
  ),
  Meeting(
    id: 'preview-failed',
    title: '离线转录恢复检查',
    createdAt: DateTime(2026, 7, 23, 11),
    startedAt: DateTime(2026, 7, 23, 11),
    endedAt: DateTime(2026, 7, 23, 11, 18),
    status: MeetingState.failed,
    audioPath: 'preview://failed.wav',
    audioDurationMs: 18 * 60 * 1000,
    requestedModelId: senseVoiceDefaultModelId,
    recordingModelId: senseVoiceDefaultModelId,
    recordingModelVersion: AsrModelRegistry.alpha.defaultModel.version,
    lastErrorCode: 'transcription.failed',
  ),
];
