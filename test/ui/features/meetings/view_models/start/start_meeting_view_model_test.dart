import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/app_failure.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/meeting_readiness.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/use_cases/start_meeting.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';
import 'package:meettrace/ui/features/meetings/view_models/start/start_meeting_view_model.dart';

import '../../../../../support/model_selection_fakes.dart';

void main() {
  late TestModelPreferences preferences;
  late TestActiveInstallations installations;
  late TestMeetingRepository meetings;
  late TestAsrEngineFactory factory;

  setUp(() {
    preferences = TestModelPreferences(whisperBaseStandardModelId);
    installations = TestActiveInstallations();
    meetings = TestMeetingRepository();
    factory = TestAsrEngineFactory();
    final standard = AsrModelRegistry.alpha.requireById(
      whisperBaseStandardModelId,
    );
    installations.install(installations.installed(standard), active: true);
  });

  tearDown(() => installations.dispose());

  test('直接使用全局默认模型并以待生成标题创建会议', () async {
    final qwen = AsrModelRegistry.alpha.requireById(
      whisperSmallAdvancedModelId,
    );
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
    expect(factory.purposes, [AsrEnginePurpose.preview]);
    expect(factory.engines.single.initializeCalls, 1);
    viewModel.dispose();
  });

  test('默认高级模型不可用时阻止开始且不静默回退', () async {
    preferences = TestModelPreferences(whisperSmallAdvancedModelId);
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
        defaultModelId: whisperBaseStandardModelId,
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
    expect(viewModel.errorCode, 'meeting.start.microphone_permission');
    expect(
      viewModel.errorMessage,
      contains('meeting.start.microphone_permission'),
    );
    expect(viewModel.failureAction, FailureUserAction.grantPermission);
    expect(meetings.saved, isEmpty);
    expect(factory.calls, isEmpty);
    viewModel.dispose();
  });

  test('Native Assets 动态库不可用时保留稳定错误码和重新安装动作', () async {
    factory.createError = AsrEngineException(
      AppFailure(
        code: 'asr.whisper.native_library_unavailable',
        stage: FailureStage.asrInitialization,
        recoverability: FailureRecoverability.userActionRequired,
        userAction: FailureUserAction.reinstallApp,
      ),
    );
    final viewModel = _viewModel(preferences, installations, meetings, factory);
    await viewModel.load();

    expect(await viewModel.start(), isNull);
    expect(viewModel.errorCode, 'asr.whisper.native_library_unavailable');
    expect(
      viewModel.errorMessage,
      contains('asr.whisper.native_library_unavailable'),
    );
    expect(viewModel.failureAction, FailureUserAction.reinstallApp);
    expect(meetings.saved, isEmpty);
    viewModel.dispose();
  });

  test('Base context 创建失败时释放 Engine 且不留下半创建会议', () async {
    factory.engineInitializeError = AsrEngineException(
      AppFailure(
        code: 'asr.whisper.context_create_failed',
        stage: FailureStage.asrInitialization,
        modelId: whisperBaseStandardModelId,
        modelVersion: AsrModelRegistry.alpha.defaultModel.version,
        recoverability: FailureRecoverability.retryable,
        userAction: FailureUserAction.retry,
      ),
    );
    final viewModel = _viewModel(preferences, installations, meetings, factory);
    await viewModel.load();

    expect(await viewModel.start(), isNull);
    expect(viewModel.errorCode, 'asr.whisper.context_create_failed');
    expect(
      viewModel.errorMessage,
      contains('asr.whisper.context_create_failed'),
    );
    expect(factory.engines.single.disposeCalls, 1);
    expect(meetings.saved, isEmpty);
    viewModel.dispose();
  });

  test('会议持久化失败时使用独立错误码并释放已初始化 Engine', () async {
    meetings.saveError = StateError('injected persistence failure');
    final viewModel = _viewModel(preferences, installations, meetings, factory);
    await viewModel.load();

    expect(await viewModel.start(), isNull);
    expect(viewModel.errorCode, 'meeting.start.persistence_failed');
    expect(
      viewModel.errorMessage,
      contains('meeting.start.persistence_failed'),
    );
    expect(viewModel.failureAction, FailureUserAction.retry);
    expect(factory.engines.single.initializeCalls, 1);
    expect(factory.engines.single.disposeCalls, 1);
    expect(meetings.saved, isEmpty);
    viewModel.dispose();
  });

  test('开始后 Meeting 拒绝更改锁定模型', () async {
    final viewModel = _viewModel(preferences, installations, meetings, factory);
    await viewModel.load();
    final session = await viewModel.start();

    expect(
      () => session!.meeting.changeRecordingModel(
        recordingModelId: whisperSmallAdvancedModelId,
        recordingModelVersion: 'v1.9.1-q5_1',
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
