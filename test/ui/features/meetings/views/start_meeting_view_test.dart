import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meetily_ai/app/application.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/ui/core/asr_model_option.dart';
import 'package:meetily_ai/ui/features/meetings/view_models/start_meeting_view_model.dart';
import 'package:meetily_ai/ui/features/meetings/views/start_meeting_view.dart';

import '../../../../support/model_selection_fakes.dart';

void main() {
  testWidgets('开始会议页继承默认并折叠模型选择', (tester) async {
    final fixture = _fixture();

    await tester.pumpWidget(
      Application(home: StartMeetingView(viewModel: fixture.viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FScaffold), findsOneWidget);
    expect(find.text('开始会议'), findsWidgets);
    expect(find.text('事实音频优先保存在本机'), findsOneWidget);
    expect(find.textContaining('转录模型：标准模型'), findsOneWidget);
    expect(find.textContaining('使用全局默认'), findsOneWidget);
    expect(find.text('高级模型（Qwen3-ASR）').hitTestable(), findsNothing);

    await tester.tap(find.textContaining('转录模型：标准模型'));
    await tester.pumpAndSettle();

    expect(find.text('高级模型（Qwen3-ASR）').hitTestable(), findsOneWidget);
    await fixture.dispose();
  });

  testWidgets('高级模型不可用时提供下载、改用标准模型和取消', (tester) async {
    final fixture = _fixture();
    var downloadCalls = 0;
    fixture.viewModel.actions = AdvancedModelActions(
      download: () async => downloadCalls++,
    );
    StartedMeetingSession? started;

    await tester.pumpWidget(
      Application(
        home: StartMeetingView(
          viewModel: fixture.viewModel,
          onStarted: (session) => started = session,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('转录模型：标准模型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('高级模型（Qwen3-ASR）'));
    await tester.pumpAndSettle();

    expect(find.textContaining('内存、耗电和发热'), findsOneWidget);
    await tester.tap(find.text('开始录音'));
    await tester.pumpAndSettle();

    expect(find.text('下载高级模型'), findsOneWidget);
    expect(find.text('改用标准模型并开始'), findsOneWidget);
    expect(find.text('取消本次选择'), findsOneWidget);

    await tester.ensureVisible(find.text('下载高级模型'));
    await tester.tap(find.text('下载高级模型'));
    await tester.pumpAndSettle();
    expect(downloadCalls, 1);

    await tester.ensureVisible(find.text('改用标准模型并开始'));
    await tester.tap(find.text('改用标准模型并开始'));
    await tester.pumpAndSettle();
    expect(started, isNotNull);
    expect(started!.meeting.modelFallbackReason, advancedModelFallbackReason);
    expect(fixture.preferences.setCalls, isEmpty);
    await fixture.dispose();
  });

  testWidgets('320 宽度和 2.0 字体缩放下主操作不遮挡内容', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final fixture = _fixture();

    await tester.pumpWidget(
      Application(home: StartMeetingView(viewModel: fixture.viewModel)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('start-recording-action')),
      findsOneWidget,
    );
    expect(find.text('开始录音'), findsOneWidget);
    expect(find.text('事实音频优先保存在本机'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await fixture.dispose();
  });
}

_Fixture _fixture() {
  final preferences = TestModelPreferences(paraformerStandardModelId);
  final installations = TestActiveInstallations();
  final standard = AsrModelRegistry.alpha.requireById(
    paraformerStandardModelId,
  );
  installations.install(installations.installed(standard), active: true);
  final viewModel = StartMeetingViewModel(
    preferences: preferences,
    installations: installations,
    meetings: TestMeetingRepository(),
    engineFactory: TestAsrEngineFactory(),
    meetingIdFactory: () => 'meeting-widget',
    now: () => DateTime.utc(2026, 7, 24, 10),
  );
  return _Fixture(
    preferences: preferences,
    installations: installations,
    viewModel: viewModel,
  );
}

final class _Fixture {
  const _Fixture({
    required this.preferences,
    required this.installations,
    required this.viewModel,
  });

  final TestModelPreferences preferences;
  final TestActiveInstallations installations;
  final StartMeetingViewModel viewModel;

  Future<void> dispose() async {
    viewModel.dispose();
    await installations.dispose();
  }
}
