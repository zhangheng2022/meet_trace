import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/meeting_readiness.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/use_cases/start_meeting.dart';
import 'package:meettrace/ui/features/meetings/view_models/start/start_meeting_view_model.dart';

import '../../../../../support/model_selection_fakes.dart';

void main() {
  late TestModelPreferences preferences;
  late TestActiveInstallations installations;
  late TestMeetingRepository meetings;
  late TestAsrEngineFactory factory;

  setUp(() {
    preferences = TestModelPreferences(paraformerStandardModelId);
    installations = TestActiveInstallations();
    meetings = TestMeetingRepository();
    factory = TestAsrEngineFactory();
    final standard = AsrModelRegistry.alpha.requireById(
      paraformerStandardModelId,
    );
    installations.install(installations.installed(standard), active: true);
  });

  tearDown(() => installations.dispose());

  test('直接使用全局默认模型并以待生成标题创建会议', () async {
    final qwen = AsrModelRegistry.alpha.requireById(qwenAdvancedModelId);
    installations.install(installations.installed(qwen), active: true);
    preferences = TestModelPreferences(qwen.modelId);
    final viewModel = _viewModel(preferences, installations, meetings, factory);
    await viewModel.load();

    expect(viewModel.defaultModelId, qwen.modelId);
    final session = await viewModel.start();

    expect(preferences.setCalls, isEmpty);
    expect(session, isNotNull);
    expect(session!.meeting.title, pendingMeetingTitle);
    expect(session.meeting.requestedModelId, qwen.modelId);
    expect(session.meeting.recordingModelId, qwen.modelId);
    expect(session.meeting.recordingModelVersion, qwen.version);
    expect(session.meeting.status, MeetingState.recording);
    expect(session.meeting.isRecordingModelLocked, isTrue);
    expect(factory.calls, [(qwen.modelId, qwen.version)]);
    expect(factory.engines.single.initializeCalls, 1);
    viewModel.dispose();
  });

  test('默认高级模型不可用时阻止开始且不静默回退', () async {
    preferences = TestModelPreferences(qwenAdvancedModelId);
    final viewModel = _viewModel(preferences, installations, meetings, factory);
    await viewModel.load();

    expect(await viewModel.start(), isNull);
    expect(viewModel.errorMessage, contains('默认高级模型尚未安装'));
    expect(factory.calls, isEmpty);
    expect(preferences.setCalls, isEmpty);
    viewModel.dispose();
  });

  test('开始前请求麦克风权限，拒绝时不创建会议或初始化模型', () async {
    final readiness = TestMeetingReadinessChecker(
      result: MeetingReadiness(
        microphonePermissionGranted: false,
        freeBytes: minimumRecordingFreeBytes,
        defaultModelId: paraformerStandardModelId,
        defaultModelName: AsrModelRegistry.alpha.defaultModel.displayName,
        defaultModelAvailable: true,
      ),
    );
    final viewModel = _viewModel(
      preferences,
      installations,
      meetings,
      factory,
      readiness: readiness,
    );
    await viewModel.load();

    expect(await viewModel.start(), isNull);
    expect(readiness.permissionRequests, [true]);
    expect(viewModel.errorMessage, contains('需要麦克风权限'));
    expect(meetings.saved, isEmpty);
    expect(factory.calls, isEmpty);
    viewModel.dispose();
  });

  test('开始后 Meeting 拒绝更改锁定模型', () async {
    final viewModel = _viewModel(preferences, installations, meetings, factory);
    await viewModel.load();
    final session = await viewModel.start();

    expect(
      () => session!.meeting.changeRecordingModel(
        recordingModelId: qwenAdvancedModelId,
        recordingModelVersion: '2026-03-25',
        fallbackReason: '不应允许',
      ),
      throwsA(isA<InvalidStateTransitionException>()),
    );
    viewModel.dispose();
  });
}

StartMeetingViewModel _viewModel(
  TestModelPreferences preferences,
  TestActiveInstallations installations,
  TestMeetingRepository meetings,
  TestAsrEngineFactory factory, {
  TestMeetingReadinessChecker? readiness,
}) {
  return StartMeetingViewModel(
    preferences: preferences,
    installations: installations,
    startMeeting: StartMeetingUseCase(
      meetings: meetings,
      engineFactory: factory,
      readinessChecker: readiness ?? TestMeetingReadinessChecker(),
      meetingIdFactory: () => 'meeting-step-11',
      now: () => DateTime.utc(2026, 7, 24, 9),
    ),
  );
}
