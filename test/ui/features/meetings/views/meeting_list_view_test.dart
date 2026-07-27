import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/data/repositories/repository_contracts.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/ui/core/app_ledger.dart';
import 'package:meettrace/ui/features/meetings/view_models/meeting_list_view_model.dart';
import 'package:meettrace/ui/features/meetings/views/meeting_list_view.dart';

void main() {
  testWidgets('空会议列表使用 Forui 并触发开始会议操作', (WidgetTester tester) async {
    var startMeetingRequested = false;

    await tester.pumpWidget(
      Application(
        home: MeetingListView(
          onStartMeeting: () => startMeetingRequested = true,
        ),
      ),
    );

    expect(find.byType(FScaffold), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is FHeader),
      findsOneWidget,
    );
    expect(find.text('还没有会议'), findsOneWidget);
    expect(find.text('开始会议'), findsOneWidget);

    await tester.tap(find.text('开始会议'));
    await tester.pumpAndSettle();

    expect(startMeetingRequested, isTrue);
  });

  testWidgets('开始会议按下时保持全宽底栏几何稳定', (WidgetTester tester) async {
    var startMeetingRequested = false;

    await tester.pumpWidget(
      Application(
        home: MeetingListView(
          onStartMeeting: () => startMeetingRequested = true,
        ),
      ),
    );

    final control = find.byKey(const ValueKey('start-meeting-control'));
    final surface = find.byKey(const ValueKey('start-meeting-control-surface'));
    final restingDecoration =
        tester.widget<AnimatedContainer>(surface).decoration as BoxDecoration;
    final tappable = tester.widget<FTappable>(control);
    final tappableStyle = tappable.style(
      tester.element(control).theme.tappableStyle,
    );
    final gesture = await tester.startGesture(tester.getCenter(control));
    await tester.pump(const Duration(milliseconds: 120));

    expect(tappableStyle.motion.bounceTween.transform(1), 1);
    expect(
      tester.widget<AnimatedContainer>(surface).decoration,
      isNot(restingDecoration),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedContainer>(surface).decoration,
      restingDecoration,
    );
    expect(startMeetingRequested, isTrue);
  });

  testWidgets('平板使用会议账本和事实预览主从布局', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MeetingRepository();
    final viewModel = MeetingListViewModel(meetings: repository);
    Meeting? opened;

    await tester.pumpWidget(
      Application(
        home: MeetingListView(
          viewModel: viewModel,
          onStartMeeting: () {},
          onOpenMeeting: (meeting) => opened = meeting,
        ),
      ),
    );
    expect(find.byType(FProgress), findsOneWidget);

    repository.emit([
      _meeting('processing', '处理中会议', MeetingState.processing),
      _meeting('failed', '失败会议', MeetingState.failed),
    ]);
    await tester.pump();

    expect(find.byKey(const ValueKey('meeting-ledger')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meeting-home-master-detail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meeting-preview-processing')),
      findsOneWidget,
    );
    expect(find.byType(AppLedgerSurface), findsOneWidget);
    expect(find.byType(AppLedgerRow), findsNWidgets(2));
    expect(find.text('处理中'), findsOneWidget);
    expect(find.text('失败 · 打开查看事实音频状态'), findsOneWidget);
    expect(find.text('标准模型（Paraformer） · 2024-03-09'), findsOneWidget);
    expect(find.byIcon(FLucideIcons.audioLines), findsWidgets);
    expect(find.byIcon(FLucideIcons.circleAlert), findsWidgets);
    expect(find.text('开始会议'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('meeting-processing'))).height,
      lessThan(90),
    );
    expect(
      tester.getTopLeft(find.text('失败 · 打开查看事实音频状态')).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.text('失败会议')).dy),
    );

    await tester.tap(find.byKey(const ValueKey('meeting-failed')));
    await tester.pumpAndSettle();
    expect(opened, isNull);
    expect(
      find.byKey(const ValueKey('meeting-preview-failed')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('open-selected-meeting')));
    await tester.pumpAndSettle();
    expect(opened?.id, 'failed');
    viewModel.dispose();
    await repository.dispose();
  });

  testWidgets('本地会议流失败时显示可重试错误状态', (WidgetTester tester) async {
    final repository = _MeetingRepository();
    final viewModel = MeetingListViewModel(meetings: repository);

    await tester.pumpWidget(
      Application(home: MeetingListView(viewModel: viewModel)),
    );
    repository.fail(StateError('database unavailable'));
    await tester.pump();

    expect(find.text('会议加载失败'), findsOneWidget);
    expect(find.text('重试加载'), findsOneWidget);
    viewModel.dispose();
    await repository.dispose();
  });

  testWidgets('320 宽度和 2.0 字体缩放下保留文本主操作且无溢出', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = _MeetingRepository();
    final viewModel = MeetingListViewModel(meetings: repository);

    await tester.pumpWidget(
      Application(
        home: MeetingListView(
          viewModel: viewModel,
          onStartMeeting: () {},
          onOpenMeeting: (_) {},
        ),
      ),
    );
    repository.emit([
      _meeting('recording', '跨团队产品研究进展同步', MeetingState.recording),
    ]);
    await tester.pump();

    expect(find.byKey(const ValueKey('meeting-ledger')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meeting-home-master-detail')),
      findsNothing,
    );
    expect(find.text('开始会议'), findsOneWidget);
    expect(find.text('录音中'), findsOneWidget);
    expect(tester.takeException(), isNull);
    viewModel.dispose();
    await repository.dispose();
  });
}

final class _MeetingRepository implements MeetingRepository {
  final StreamController<List<Meeting>> _changes =
      StreamController<List<Meeting>>.broadcast();

  void emit(List<Meeting> meetings) => _changes.add(meetings);

  void fail(Object error) => _changes.addError(error);

  Future<void> dispose() => _changes.close();

  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<Meeting?> getById(String meetingId) async => null;

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Stream<List<Meeting>> watchAll() => _changes.stream;
}

Meeting _meeting(String id, String title, MeetingState state) => Meeting(
  id: id,
  title: title,
  createdAt: DateTime.utc(2026, 7, 24),
  status: state,
  audioDurationMs: 12000,
  requestedModelId: paraformerStandardModelId,
  recordingModelId: paraformerStandardModelId,
  recordingModelVersion: '2024-03-09',
  lastErrorCode: state == MeetingState.failed ? 'processing.failed' : null,
);
