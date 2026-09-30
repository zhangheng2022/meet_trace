import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/app_failure.dart';
import 'package:meettrace/domain/models/meeting_readiness.dart';
import 'package:meettrace/domain/models/recording_input.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';
import 'package:meettrace/domain/ports/recording_input.dart';
import 'package:meettrace/domain/use_cases/lock_recording_input.dart';
import 'package:meettrace/domain/use_cases/check_meeting_readiness.dart';
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

  test('显式选择在线来源冻结完整配置，开始后再次选择不会换源或初始化网络', () async {
    final selected = TranscriptionProfile(
      id: 'selected-remote',
      name: 'Online',
      revision: 4,
      protocol: TranscriptionProtocol.realtimeTranscription,
      endpoint: Uri.parse('wss://speech.example.test/transcribe'),
      modelId: 'custom-model',
      credentialRef: 'key-version-4',
      language: 'zh',
    );
    final profileFactory = _ProfileFactory();
    final readiness = _SelectedReadiness();
    final vm = _viewModel(meetings, profileFactory, readiness: readiness);
    addTearDown(vm.dispose);

    final session = await vm.start(selection: selected);
    final second = await vm.start(selection: TranscriptionProfile.local());

    expect(session, isNotNull);
    expect(second, same(session));
    expect(session!.meeting.transcriptionProfile, same(selected));
    expect(session.meeting.recordingModelVersion, 'unreported');
    expect(session.meeting.recordingModelLanguage, 'zh');
    expect(profileFactory.profiles, [same(selected)]);
    expect(readiness.selections, [same(selected)]);
    expect(readiness.requestedPermission, isTrue);
    expect(profileFactory.engines.single.initializeCalls, 0);
    expect(meetings.saved, hasLength(1));
    expect(vm.requiresRuntimeRepair, isFalse);
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
      devices: const _RecordingInputDevices([
        RecordingInputDevice(id: 'mic-other', label: '内置麦克风'),
      ]),
    );
    final viewModel = _viewModel(
      meetings,
      factory,
      recordingInputLock: inputLock,
    );

    expect(await viewModel.start(), isNull);
    expect(viewModel.errorMessage, contains('所选麦克风当前不可用'));
    expect(meetings.saved, isEmpty);
    expect(factory.calls, isEmpty);
    viewModel.dispose();
  });

  test('系统默认但没有任何输入设备时不创建会议或初始化模型', () async {
    final inputLock = LockRecordingInputUseCase(
      preferences: _RecordingInputPreferences(
        const RecordingInputPreference.systemDefault(),
      ),
      devices: const _RecordingInputDevices([]),
    );
    final viewModel = _viewModel(
      meetings,
      factory,
      recordingInputLock: inputLock,
    );

    expect(await viewModel.start(), isNull);
    expect(viewModel.errorMessage, contains('未检测到可用麦克风'));
    expect(meetings.saved, isEmpty);
    expect(factory.calls, isEmpty);
    viewModel.dispose();
  });
}

StartMeetingViewModel _viewModel(
  TestMeetingRepository meetings,
  AsrEngineFactory factory, {
  MeetingReadinessChecker? readiness,
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
            devices: const _RecordingInputDevices([
              RecordingInputDevice(id: 'mic-default', label: '系统麦克风'),
            ]),
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

final class _ProfileFactory implements ProfileAsrEngineFactory {
  final profiles = <TranscriptionProfile>[];
  final engines = <TestAsrEngine>[];
  @override
  Future<AsrEngine> createForProfile(TranscriptionProfile profile) async {
    profiles.add(profile);
    final engine = TestAsrEngine(profile.descriptor);
    engines.add(engine);
    return engine;
  }

  @override
  Future<AsrEngine> create({
    required String modelId,
    required String modelVersion,
    String language = 'auto',
    bool useInverseTextNormalization = true,
  }) => throw StateError('selected source must use frozen profile');
}

final class _SelectedReadiness implements SelectedMeetingReadinessChecker {
  final selections = <TranscriptionProfile>[];
  bool requestedPermission = false;
  @override
  Future<MeetingReadiness> checkSelection(
    TranscriptionProfile profile, {
    bool requestMicrophonePermission = false,
  }) async {
    selections.add(profile);
    requestedPermission = requestMicrophonePermission;
    return MeetingReadiness(
      microphonePermissionGranted: true,
      freeBytes: minimumRecordingFreeBytes,
      defaultModelId: profile.modelId,
      defaultModelVersion: profile.identityVersion,
      defaultModelName: profile.name,
      defaultModelAvailable: true,
      transcriptionProfile: profile,
    );
  }

  @override
  Future<MeetingReadiness> check({bool requestMicrophonePermission = false}) =>
      throw StateError('explicit selection must not fall back to default');
}

final class _RecordingInputDevices implements RecordingInputDeviceCatalog {
  const _RecordingInputDevices(this.devices);

  final List<RecordingInputDevice> devices;

  @override
  Future<List<RecordingInputDevice>> listAvailable() async => devices;
}
