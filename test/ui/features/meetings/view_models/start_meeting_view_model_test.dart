import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:meetily_ai/ui/features/meetings/view_models/start_meeting_view_model.dart';

import '../../../../support/model_selection_fakes.dart';

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

  test('继承全局默认，选择本场覆盖不会修改默认值', () async {
    final qwen = AsrModelRegistry.alpha.requireById(qwenAdvancedModelId);
    installations.install(installations.installed(qwen), active: true);
    final viewModel = _viewModel(preferences, installations, meetings, factory);
    await viewModel.load();

    expect(viewModel.selectedModelId, paraformerStandardModelId);
    viewModel.chooseModel(qwen.modelId);
    viewModel.updateTitle('产品评审');
    final session = await viewModel.start();

    expect(preferences.setCalls, isEmpty);
    expect(session, isNotNull);
    expect(session!.meeting.title, '产品评审');
    expect(session.meeting.requestedModelId, qwen.modelId);
    expect(session.meeting.recordingModelId, qwen.modelId);
    expect(session.meeting.recordingModelVersion, qwen.version);
    expect(session.meeting.status, MeetingState.recording);
    expect(session.meeting.isRecordingModelLocked, isTrue);
    expect(factory.calls, [(qwen.modelId, qwen.version)]);
    expect(factory.engines.single.initializeCalls, 1);
    viewModel.dispose();
  });

  test('高级模型不可用时先阻止开始，用户确认后记录标准模型回退', () async {
    final viewModel = _viewModel(preferences, installations, meetings, factory);
    await viewModel.load();
    viewModel.chooseModel(qwenAdvancedModelId);

    expect(await viewModel.start(), isNull);
    expect(viewModel.requiresAdvancedModelAction, isTrue);
    expect(factory.calls, isEmpty);

    final session = await viewModel.useStandardAndStart();

    expect(session, isNotNull);
    expect(session!.meeting.requestedModelId, qwenAdvancedModelId);
    expect(session.meeting.recordingModelId, paraformerStandardModelId);
    expect(session.meeting.modelFallbackReason, advancedModelFallbackReason);
    expect(factory.calls.single.$1, paraformerStandardModelId);
    expect(preferences.setCalls, isEmpty);
    viewModel.dispose();
  });

  test('开始后 ViewModel 和 Meeting 都拒绝更改锁定模型', () async {
    final viewModel = _viewModel(preferences, installations, meetings, factory);
    await viewModel.load();
    final session = await viewModel.start();

    expect(() => viewModel.chooseModel(qwenAdvancedModelId), throwsStateError);
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
  TestAsrEngineFactory factory,
) {
  return StartMeetingViewModel(
    preferences: preferences,
    installations: installations,
    meetings: meetings,
    engineFactory: factory,
    meetingIdFactory: () => 'meeting-step-11',
    now: () => DateTime.utc(2026, 7, 24, 9),
  );
}
