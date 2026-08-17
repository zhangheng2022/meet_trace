import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/app_failure.dart';
import 'package:meettrace/domain/models/meeting_readiness.dart';
import 'package:meettrace/domain/models/recording_input.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';
import 'package:meettrace/domain/ports/recording_input.dart';
import 'package:meettrace/domain/use_cases/lock_recording_input.dart';
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

  test('直接使用全局默认模型并以本地开始时间生成标题', () async {
    final senseVoice = AsrModelRegistry.alpha.requireById(
      senseVoiceDefaultModelId,
    );
    final viewModel = _viewModel(meetings, factory);

    final session = await viewModel.start();

    expect(session, isNotNull);
    expect(session!.meeting.title, '2026-07-24 09:05 会议');
    expect(session.meeting.recordingModelId, senseVoice.modelId);
    expect(session.meeting.recordingModelVersion, senseVoice.version);
    expect(session.meeting.status, MeetingState.recording);
    expect(session.meeting.isRecordingModelLocked, isTrue);
    expect(factory.calls, [(senseVoice.modelId, senseVoice.version)]);
    expect(factory.engines.single.initializeCalls, 0);
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

  test('开始会议时冻结全局输入设备并带入录音会话', () async {
    final inputLock = LockRecordingInputUseCase(
      preferences: _RecordingInputPreferences(
        const RecordingInputPreference.device(
          deviceId: 'mic-1',
          lastKnownLabel: 'USB 麦克风',
        ),
      ),
      devices: const _RecordingInputDevices([
        RecordingInputDevice(id: 'mic-1', label: 'USB 麦克风'),
      ]),
    );
    final viewModel = _viewModel(
      meetings,
      factory,
      recordingInputLock: inputLock,
    );

    final session = await viewModel.start();

    expect(session?.recordingInput.device?.id, 'mic-1');
    expect(session?.recordingInput.displayLabel, 'USB 麦克风');
    viewModel.dispose();
  });

  test('已选输入设备不可用时不创建会议或初始化模型', () async {
    final inputLock = LockRecordingInputUseCase(
      preferences: _RecordingInputPreferences(
        const RecordingInputPreference.device(
          deviceId: 'missing',
          lastKnownLabel: '拔出的麦克风',
        ),
      ),
      devices: const _RecordingInputDevices([]),
    );
    final viewModel = _viewModel(
      meetings,
      factory,
      recordingInputLock: inputLock,
    );

    expect(await viewModel.start(), isNull);
    expect(viewModel.errorMessage, contains('已选择的麦克风当前不可用'));
    expect(meetings.saved, isEmpty);
    expect(factory.calls, isEmpty);
    viewModel.dispose();
  });
}

StartMeetingViewModel _viewModel(
  TestMeetingRepository meetings,
  TestAsrEngineFactory factory, {
  TestMeetingReadinessChecker? readiness,
  LockRecordingInputUseCase? recordingInputLock,
}) {
  return StartMeetingViewModel(
    startMeeting: StartMeetingUseCase(
      meetings: meetings,
      engineFactory: factory,
      readinessChecker: readiness ?? TestMeetingReadinessChecker(),
      meetingIdFactory: () => 'meeting-step-11',
      now: () => DateTime(2026, 7, 24, 9, 5),
      recordingInputLock:
          recordingInputLock ??
          LockRecordingInputUseCase(
            preferences: _RecordingInputPreferences(
              const RecordingInputPreference.systemDefault(),
            ),
            devices: const _RecordingInputDevices([]),
          ),
    ),
  );
}

final class _RecordingInputPreferences
    implements RecordingInputPreferenceRepository {
  _RecordingInputPreferences(this.preference);

  RecordingInputPreference preference;

  @override
  Future<RecordingInputPreference> getPreference() async => preference;

  @override
  Future<void> setPreference(RecordingInputPreference preference) async {
    this.preference = preference;
  }
}

final class _RecordingInputDevices implements RecordingInputDeviceCatalog {
  const _RecordingInputDevices(this.devices);

  final List<RecordingInputDevice> devices;

  @override
  Future<List<RecordingInputDevice>> listAvailable() async => devices;
}
