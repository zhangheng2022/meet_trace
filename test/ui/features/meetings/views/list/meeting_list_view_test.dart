import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/data/repositories/repository_contracts.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/use_cases/delete_meeting.dart';
import 'package:meettrace/ui/core/app_ledger.dart';
import 'package:meettrace/ui/features/meetings/view_models/list/meeting_list_view_model.dart';
import 'package:meettrace/ui/features/meetings/views/list/meeting_list_view.dart';

import '../../../../../support/model_selection_fakes.dart';

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

  testWidgets('首页展示经过真实预检的录音条件状态', (WidgetTester tester) async {
    var settingsRequested = false;
    final repository = _MeetingRepository();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
    );

    await tester.pumpWidget(
      Application(
        home: MeetingListView(
          viewModel: viewModel,
          onOpenSettings: () => settingsRequested = true,
        ),
      ),
    );
    repository.emit(const []);
    await tester.pump();

    final title = find.byKey(const ValueKey('recording-setup-title'));
    final detail = find.byKey(const ValueKey('recording-setup-detail'));
    expect(find.text('录音条件已就绪'), findsOneWidget);
    expect(find.text('音频仅保存在本机 · SenseVoice可用'), findsOneWidget);
    expect(
      tester.getBottomLeft(title).dy,
      lessThan(tester.getTopLeft(detail).dy),
    );
    expect(find.text('事实音频本地优先 · 实时转录仅供参考'), findsNothing);
    expect(find.textContaining('准备就绪'), findsNothing);

    await tester.tap(find.text('录音条件已就绪'));
    await tester.pumpAndSettle();

    expect(settingsRequested, isTrue);
    viewModel.dispose();
    await repository.dispose();
  });

  testWidgets('预检失败时可从状态条重新检查并恢复', (WidgetTester tester) async {
    final repository = _MeetingRepository();
    final readiness = TestMeetingReadinessChecker(
      error: StateError('platform channel unavailable'),
    );
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: readiness,
      deletion: _deletion(repository),
    );

    await tester.pumpWidget(
      Application(home: MeetingListView(viewModel: viewModel)),
    );
    repository.emit(const []);
    await tester.pump();

    expect(find.text('无法检查录音条件'), findsOneWidget);
    readiness.error = null;
    await tester.tap(find.text('无法检查录音条件'));
    await tester.pumpAndSettle();

    expect(find.text('录音条件已就绪'), findsOneWidget);
    expect(readiness.permissionRequests, [false, false]);
    viewModel.dispose();
    await repository.dispose();
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

  testWidgets('会议准备期间立即反馈状态并阻止重复启动', (WidgetTester tester) async {
    var startMeetingRequests = 0;

    await tester.pumpWidget(
      Application(
        home: MeetingListView(
          startingMeeting: true,
          onStartMeeting: () => startMeetingRequests++,
        ),
      ),
    );

    expect(find.text('正在准备录音…'), findsOneWidget);
    expect(find.text('开始会议'), findsNothing);
    expect(
      tester
          .widget<FTappable>(
            find.byKey(const ValueKey('start-meeting-control')),
          )
          .onPress,
      isNull,
    );
    final progressIcon = find.byKey(
      const ValueKey('start-meeting-progress-icon'),
    );
    final initialTurn = tester
        .widget<RotationTransition>(progressIcon)
        .turns
        .value;

    await tester.pump(const Duration(milliseconds: 225));

    final advancedTurn = tester
        .widget<RotationTransition>(progressIcon)
        .turns
        .value;
    expect(advancedTurn, greaterThan(initialTurn));

    await tester.tap(find.byKey(const ValueKey('start-meeting-control')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(startMeetingRequests, 0);
  });

  testWidgets('平板使用会议账本和事实预览主从布局', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MeetingRepository();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
    );
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
    expect(find.byType(FProgress), findsNothing);
    expect(find.byType(FCircularProgress), findsOneWidget);
    expect(find.text('正在加载会议'), findsOneWidget);

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
    expect(find.text('SenseVoice · 2024-07-17'), findsOneWidget);
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

  testWidgets('会议账本使用今天、昨天、本周和日历日期标签', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(414, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reference = DateTime(2026, 7, 30, 15, 45);
    final repository = _MeetingRepository();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
    );

    await tester.pumpWidget(
      Application(
        home: MeetingListView(viewModel: viewModel, now: () => reference),
      ),
    );
    repository.emit([
      _meeting(
        'today',
        '今日会议',
        MeetingState.completed,
        createdAt: DateTime(2026, 7, 30, 9, 15),
      ),
      _meeting(
        'yesterday',
        '昨日会议',
        MeetingState.completed,
        createdAt: DateTime(2026, 7, 29, 18, 5),
      ),
      _meeting(
        'weekday',
        '本周会议',
        MeetingState.completed,
        createdAt: DateTime(2026, 7, 28, 10),
      ),
      _meeting(
        'earlier',
        '较早会议',
        MeetingState.completed,
        createdAt: DateTime(2026, 6, 3, 8),
      ),
    ]);
    await tester.pump();

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('周二'), findsOneWidget);
    expect(find.text('6月3日'), findsOneWidget);
    expect(find.text('09:15'), findsOneWidget);
    expect(find.text('07-30'), findsNothing);

    viewModel.dispose();
    await repository.dispose();
  });

  testWidgets('本地会议流失败时显示可重试错误状态', (WidgetTester tester) async {
    final repository = _MeetingRepository();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
    );

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
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
    );

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
    expect(find.text('录音条件已就绪'), findsOneWidget);
    expect(find.text('音频仅保存在本机 · SenseVoice可用'), findsOneWidget);
    expect(tester.takeException(), isNull);
    viewModel.dispose();
    await repository.dispose();
  });

  testWidgets('左滑只揭示删除操作并在取消确认后保留会议', (WidgetTester tester) async {
    final repository = _MeetingRepository();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
    );

    await tester.pumpWidget(
      Application(
        home: MeetingListView(viewModel: viewModel, onOpenMeeting: (_) {}),
      ),
    );
    repository.emit([_meeting('completed', '产品评审', MeetingState.completed)]);
    await tester.pump();

    final row = find.byKey(const ValueKey('meeting-completed'));
    final originalX = tester.getTopLeft(row).dx;
    await tester.drag(row, const Offset(-140, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(row).dx, lessThan(originalX));
    await tester.tap(find.byKey(const ValueKey('delete-meeting-completed')));
    await tester.pumpAndSettle();

    expect(find.text('永久删除「产品评审」？'), findsOneWidget);
    expect(find.text('将删除本场事实音频、转录、AI 总结、证据索引及处理记录。此操作无法撤销。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(repository.deleted, isEmpty);
    expect(find.text('产品评审'), findsOneWidget);
    viewModel.dispose();
    await repository.dispose();
  });

  testWidgets('确认左滑删除后移除会议并反馈本地数据已删除', (WidgetTester tester) async {
    final repository = _MeetingRepository();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
    );

    await tester.pumpWidget(
      Application(home: MeetingListView(viewModel: viewModel)),
    );
    repository.emit([_meeting('completed', '产品评审', MeetingState.completed)]);
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('meeting-completed')),
      const Offset(-140, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-meeting-completed')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-delete-meeting-completed')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(repository.deleted, ['completed']);
    expect(find.byKey(const ValueKey('meeting-completed')), findsNothing);
    expect(find.text('会议及本地数据已删除'), findsOneWidget);
    viewModel.dispose();
    await repository.dispose();
  });

  testWidgets('录音中和后台处理中会议不响应左滑删除', (WidgetTester tester) async {
    final repository = _MeetingRepository();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
    );

    await tester.pumpWidget(
      Application(home: MeetingListView(viewModel: viewModel)),
    );
    repository.emit([
      _meeting('recording', '录音中会议', MeetingState.recording),
      _meeting('processing', '处理中会议', MeetingState.processing),
    ]);
    await tester.pump();

    for (final id in ['recording', 'processing']) {
      final row = find.byKey(ValueKey('meeting-$id'));
      final originalX = tester.getTopLeft(row).dx;
      await tester.drag(row, const Offset(-140, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(row).dx, originalX);
    }

    expect(repository.deleted, isEmpty);
    viewModel.dispose();
    await repository.dispose();
  });
}

final class _MeetingRepository implements MeetingRepository {
  final StreamController<List<Meeting>> _changes =
      StreamController<List<Meeting>>.broadcast();
  final List<String> deleted = [];
  List<Meeting> _meetings = const [];

  void emit(List<Meeting> meetings) {
    _meetings = List.of(meetings);
    _changes.add(List.unmodifiable(_meetings));
  }

  void fail(Object error) => _changes.addError(error);

  Future<void> dispose() => _changes.close();

  @override
  Future<void> delete(String meetingId) async {
    deleted.add(meetingId);
    _meetings = [
      for (final meeting in _meetings)
        if (meeting.id != meetingId) meeting,
    ];
    _changes.add(List.unmodifiable(_meetings));
  }

  @override
  Future<Meeting?> getById(String meetingId) async {
    for (final meeting in _meetings) {
      if (meeting.id == meetingId) {
        return meeting;
      }
    }
    return null;
  }

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Stream<List<Meeting>> watchAll() => _changes.stream;
}

DeleteMeetingUseCase _deletion(_MeetingRepository repository) =>
    DeleteMeetingUseCase(
      meetings: repository,
      files: const _MeetingFileDeletionService(),
    );

final class _MeetingFileDeletionService implements MeetingFileDeletionService {
  const _MeetingFileDeletionService();

  @override
  Future<StagedMeetingDeletion> stage(String meetingId) async =>
      const _StagedMeetingDeletion();
}

final class _StagedMeetingDeletion implements StagedMeetingDeletion {
  const _StagedMeetingDeletion();

  @override
  Future<void> commit() async {}

  @override
  Future<void> rollback() async {}
}

Meeting _meeting(
  String id,
  String title,
  MeetingState state, {
  DateTime? createdAt,
}) => Meeting(
  id: id,
  title: title,
  createdAt: createdAt ?? DateTime.utc(2026, 7, 24),
  status: state,
  audioDurationMs: 12000,
  requestedModelId: senseVoiceDefaultModelId,
  recordingModelId: senseVoiceDefaultModelId,
  recordingModelVersion: '2024-07-17',
  lastErrorCode: state == MeetingState.failed ? 'processing.failed' : null,
);
