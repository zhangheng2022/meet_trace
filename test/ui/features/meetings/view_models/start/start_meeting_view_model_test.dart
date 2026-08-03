import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/app_failure.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/meeting_readiness.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';
import 'package:meettrace/domain/use_cases/start_meeting.dart';
import 'package:meettrace/ui/features/meetings/view_models/start/start_meeting_view_model.dart';

import '../../../../../support/model_selection_fakes.dart';

void main() {
  late TestMeetingRepository meetings;
  late TestAsrEngineFactory factory;

  setUp(() {
    meetings = TestMeetingRepository();
    factory = TestAsrEngineFactory();
  });

  test('直接使用全局默认模型并以待生成标题创建会议', () async {
    final senseVoice = AsrModelRegistry.alpha.requireById(
      senseVoiceDefaultModelId,
    );
    final viewModel = _viewModel(meetings, factory);

    final session = await viewModel.start();

    expect(session, isNotNull);
    expect(session!.meeting.title, pendingMeetingTitle);
    expect(session.meeting.recordingModelId, senseVoice.modelId);
    expect(session.meeting.recordingModelVersion, senseVoice.version);
    expect(session.meeting.status, MeetingState.recording);
    expect(session.meeting.isRecordingModelLocked, isTrue);
    expect(factory.calls, [(senseVoice.modelId, senseVoice.version)]);
    expect(factory.engines.single.initializeCalls, 1);
    viewModel.dispose();
  });

  test('SenseVoice 不可用时阻止开始且不静默回退', () async {
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    final readiness = TestMeetingReadinessChecker(
      result: MeetingReadiness(
        microphonePermissionGranted: true,
        freeBytes: minimumRecordingFreeBytes,
        defaultModelId: descriptor.modelId,
        defaultModelVersion: descriptor.version,
        defaultModelName: descriptor.displayName,
        defaultModelAvailable: false,
      ),
    );
    final viewModel = _viewModel(meetings, factory, readiness: readiness);

    expect(await viewModel.start(), isNull);
    expect(viewModel.errorMessage, contains('SenseVoice 尚未准备完成'));
    expect(viewModel.requiresRuntimeRepair, isTrue);
    expect(factory.calls, isEmpty);
    viewModel.dispose();
  });

  test('Engine 初始化失败时要求返回资源修复流程', () async {
    factory.createError = AsrEngineException(
      AppFailure(
        code: 'asr.senseVoice.initialization',
        stage: FailureStage.asrInitialization,
        recoverability: FailureRecoverability.userActionRequired,
        userAction: FailureUserAction.downloadModel,
      ),
    );
    final viewModel = _viewModel(meetings, factory);

    expect(await viewModel.start(), isNull);
    expect(viewModel.requiresRuntimeRepair, isTrue);
    expect(viewModel.errorMessage, contains('资源修复流程'));
    expect(meetings.saved, isEmpty);
    viewModel.dispose();
  });

  test('开始前请求麦克风权限，拒绝时不创建会议或初始化模型', () async {
    final readiness = TestMeetingReadinessChecker(
      result: MeetingReadiness(
        microphonePermissionGranted: false,
        freeBytes: minimumRecordingFreeBytes,
        defaultModelId: senseVoiceDefaultModelId,
        defaultModelVersion: AsrModelRegistry.alpha.defaultModel.version,
        defaultModelName: AsrModelRegistry.alpha.defaultModel.displayName,
        defaultModelAvailable: true,
      ),
    );
    final viewModel = _viewModel(meetings, factory, readiness: readiness);

    expect(await viewModel.start(), isNull);
    expect(readiness.permissionRequests, [true]);
    expect(viewModel.errorMessage, contains('需要麦克风权限'));
    expect(meetings.saved, isEmpty);
    expect(factory.calls, isEmpty);
    viewModel.dispose();
  });

  test('开始后 Meeting 拒绝更改锁定模型', () async {
    final viewModel = _viewModel(meetings, factory);
    final session = await viewModel.start();

    expect(
      () => session!.meeting.changeRecordingModel(
        recordingModelId: senseVoiceDefaultModelId,
        recordingModelVersion: '2024-07-17',
      ),
      throwsA(isA<InvalidStateTransitionException>()),
    );
    viewModel.dispose();
  });
}

StartMeetingViewModel _viewModel(
  TestMeetingRepository meetings,
  TestAsrEngineFactory factory, {
  TestMeetingReadinessChecker? readiness,
}) {
  return StartMeetingViewModel(
    startMeeting: StartMeetingUseCase(
      meetings: meetings,
      engineFactory: factory,
      readinessChecker: readiness ?? TestMeetingReadinessChecker(),
      meetingIdFactory: () => 'meeting-step-11',
      now: () => DateTime.utc(2026, 7, 24, 9),
    ),
  );
}
