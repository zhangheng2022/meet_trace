// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · previews: UI-02 meeting flow · macrostructure: Workbench

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../app/application.dart';
import '../../../../data/repositories/repository_contracts.dart';
import '../../../../data/services/asr/asr_engine.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/model_installation.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../core/asr_model_option.dart';
import '../view_models/meeting_list_view_model.dart';
import '../view_models/start_meeting_view_model.dart';
import 'meeting_list_view.dart';
import 'start_meeting_view.dart';

@Preview(name: '会议列表 · 375', group: 'UI-02 会议主流程', size: Size(375, 760))
Widget meetingListCompactPreview() => Application(
  home: MeetingListView(
    viewModel: MeetingListViewModel(
      meetings: _PreviewMeetingRepository(_previewMeetings),
    ),
    onStartMeeting: () {},
    onOpenMeeting: (_) {},
    onOpenSettings: () {},
  ),
);

@Preview(name: '会议列表 · 1024', group: 'UI-02 会议主流程', size: Size(1024, 760))
Widget meetingListExpandedPreview() => meetingListCompactPreview();

@Preview(name: '开始会议 · 375', group: 'UI-02 会议主流程', size: Size(375, 760))
Widget startMeetingCompactPreview() => Application(
  home: StartMeetingView(
    viewModel: StartMeetingViewModel(
      preferences: const _PreviewPreferences(),
      installations: _PreviewInstallations(),
      meetings: _PreviewMeetingRepository(const []),
      engineFactory: const _PreviewEngineFactory(),
      meetingIdFactory: () => 'preview-meeting',
      now: () => DateTime(2026, 7, 25, 9, 30),
      actions: AdvancedModelActions(download: _previewDownload),
    ),
    onBack: () {},
  ),
);

Future<void> _previewDownload() async {}

final _previewMeetings = <Meeting>[
  Meeting(
    id: 'preview-recording',
    title: '产品 Alpha 评审',
    createdAt: DateTime(2026, 7, 25, 9, 30),
    startedAt: DateTime(2026, 7, 25, 9, 30),
    status: MeetingState.recording,
    audioDurationMs: 14 * 60 * 1000 + 28 * 1000,
    requestedModelId: paraformerStandardModelId,
    recordingModelId: paraformerStandardModelId,
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
    requestedModelId: paraformerStandardModelId,
    recordingModelId: paraformerStandardModelId,
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
    requestedModelId: paraformerStandardModelId,
    recordingModelId: paraformerStandardModelId,
    recordingModelVersion: AsrModelRegistry.alpha.defaultModel.version,
    lastErrorCode: 'transcription.failed',
  ),
];

final class _PreviewMeetingRepository implements MeetingRepository {
  const _PreviewMeetingRepository(this.meetings);

  final List<Meeting> meetings;

  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<Meeting?> getById(String meetingId) async {
    for (final meeting in meetings) {
      if (meeting.id == meetingId) {
        return meeting;
      }
    }
    return null;
  }

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Stream<List<Meeting>> watchAll() => Stream.value(meetings);
}

final class _PreviewPreferences implements ModelPreferenceRepository {
  const _PreviewPreferences();

  @override
  Future<String> getDefaultModelId() async => paraformerStandardModelId;

  @override
  Future<void> setDefaultModelId(String modelId) async {}
}

final class _PreviewInstallations implements ActiveModelInstallationRepository {
  _PreviewInstallations()
    : _standard = ModelInstallation(
        modelId: AsrModelRegistry.alpha.defaultModel.modelId,
        version: AsrModelRegistry.alpha.defaultModel.version,
        installationType: AsrInstallationType.bundled,
        state: ModelInstallationState.installed,
        installedPath: 'preview://standard-model',
        verifiedAt: DateTime(2026, 7, 25),
        bytes: 82 * 1024 * 1024,
      );

  final ModelInstallation _standard;

  @override
  Future<void> deleteAndDeactivate({
    required String modelId,
    required String version,
  }) async {}

  @override
  Future<ModelInstallation?> get({
    required String modelId,
    required String version,
  }) async => modelId == _standard.modelId && version == _standard.version
      ? _standard
      : null;

  @override
  Future<String?> getActiveVersion(String modelId) async =>
      modelId == _standard.modelId ? _standard.version : null;

  @override
  Future<void> save(ModelInstallation installation) async {}

  @override
  Future<void> saveInstalledAndActivate(ModelInstallation installation) async {}

  @override
  Stream<List<ModelInstallation>> watchAll() async* {
    yield [_standard];
    await Completer<void>().future;
  }
}

final class _PreviewEngineFactory implements AsrEngineFactory {
  const _PreviewEngineFactory();

  @override
  Future<AsrEngine> create({
    required String modelId,
    required String modelVersion,
  }) => throw UnsupportedError('组件预览不启动真实 ASR Engine');
}
