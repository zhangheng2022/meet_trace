import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/runtime_initialization.dart';
import 'package:meettrace/domain/ports/runtime_asset_preparation.dart';
import 'package:meettrace/domain/use_cases/initialize_runtime_assets.dart';
import 'package:meettrace/ui/core/branding/meettrace_brand_mark.dart';
import 'package:meettrace/ui/features/startup/view_models/runtime_initialization_view_model.dart';
import 'package:meettrace/ui/features/startup/views/meettrace_startup_view.dart';

void main() {
  testWidgets('启动页显示本地准备状态且不显示冗余说明', (tester) async {
    await tester.pumpWidget(const Application(home: MeetTraceStartupView()));

    expect(find.text('会迹'), findsOneWidget);
    expect(find.text('MeetTrace'), findsOneWidget);
    expect(find.text('正在准备会迹'), findsOneWidget);
    expect(find.text('恢复本地会议并检查离线转录资源，完成后自动进入首页。'), findsNothing);
    expect(find.text('打开本地工作区'), findsOneWidget);
    expect(find.text('步骤 1 / 4'), findsOneWidget);
    expect(find.text('会议记录与事实音频仍保存在本机'), findsOneWidget);
    expect(find.text('无需登录 · 事实音频仅保存在本机'), findsNothing);
    expect(find.byType(FHeader), findsNothing);
    expect(find.byType(FProgress), findsNothing);
    expect(find.byType(FCircularProgress), findsOneWidget);
    expect(
      tester
          .widget<FCircularProgress>(find.byType(FCircularProgress))
          .semanticsLabel,
      '打开本地工作区',
    );
    expect(tester.getSize(find.byType(FCircularProgress)).width, lessThan(32));
    expect(tester.takeException(), isNull);
  });

  testWidgets('启动页适配紧凑手机与双倍字体', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(const Application(home: MeetTraceStartupView()));

    expect(
      find.byKey(const ValueKey('meettrace-startup-progress-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meettrace-startup-local-evidence')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('启动页在宽屏保持紧凑内容宽度', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const Application(home: MeetTraceStartupView()));

    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('meettrace-startup-progress-content')),
          )
          .width,
      lessThanOrEqualTo(520),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('运行时资源下载只显示一个数值进度', (tester) async {
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(_DownloadingPreparation()),
    );
    addTearDown(viewModel.dispose);
    await viewModel.start();

    await tester.pumpWidget(
      Application(home: MeetTraceStartupView(viewModel: viewModel)),
    );

    expect(find.text('正在准备会迹'), findsOneWidget);
    expect(find.text('下载离线资源'), findsOneWidget);
    expect(find.text('步骤 2 / 4'), findsOneWidget);
    expect(find.text('SenseVoice'), findsOneWidget);
    expect(find.text('34%'), findsOneWidget);
    expect(find.text('100.0 MB / 286.3 MB'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('runtime-download-progress')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FDeterminateProgress>(
            find.byKey(const ValueKey('runtime-download-progress-bar')),
          )
          .value,
      closeTo(100000000 / 286314800, 0.000001),
    );
    expect(find.byType(FCircularProgress), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('资源重试失败后刷新提示而不是停留在相同画面', (tester) async {
    final preparation = _RetryFailurePreparation();
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(preparation),
    );
    addTearDown(viewModel.dispose);
    await viewModel.start();

    await tester.pumpWidget(
      Application(home: MeetTraceStartupView(viewModel: viewModel)),
    );
    expect(find.text('首次初始化需要联网下载离线运行资源'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('resume-runtime-download')));
    await tester.pumpAndSettle();

    expect(preparation.attempts, 2);
    expect(find.text('重试未成功：首次初始化需要联网下载离线运行资源'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('暂停后继续下载直接进入稳定下载态', (tester) async {
    final preparation = _PausedThenResumePreparation();
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(preparation),
    );
    addTearDown(viewModel.dispose);
    await viewModel.start();

    await tester.pumpWidget(
      Application(home: MeetTraceStartupView(viewModel: viewModel)),
    );

    expect(find.text('下载已暂停'), findsOneWidget);
    expect(find.text('27.6 MB / 286.3 MB'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('resume-runtime-download')),
      findsOneWidget,
    );
    final contentSize = tester.getSize(
      find.byKey(const ValueKey('meettrace-startup-progress-content')),
    );

    await tester.tap(find.byKey(const ValueKey('resume-runtime-download')));
    await tester.pump();

    expect(find.text('检查离线资源'), findsNothing);
    expect(find.text('下载离线资源'), findsOneWidget);
    expect(find.text('27.6 MB / 286.3 MB'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pause-runtime-download')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('resume-runtime-download')), findsNothing);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('meettrace-startup-progress-content')),
      ),
      contentSize,
    );
    expect(tester.takeException(), isNull);

    preparation.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('快速检查至少等待品牌动画完成后再进入首页', (tester) async {
    final preparation = _ControlledPreparation();
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(preparation),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      Application(
        home: MeetTraceRuntimeInitializationTransition(
          viewModel: viewModel,
          ready: const Text('会议首页'),
        ),
      ),
    );
    unawaited(viewModel.start());
    await tester.pump();

    final transition = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(transition.duration, const Duration(milliseconds: 280));
    expect(transition.reverseDuration, const Duration(milliseconds: 180));
    expect(find.text('正在准备会迹'), findsOneWidget);
    expect(find.text('检查离线资源'), findsOneWidget);
    expect(find.text('步骤 2 / 4'), findsOneWidget);

    preparation.completeReady();
    await tester.pump();

    await tester.pump(
      meetTraceBrandMotionDuration - const Duration(milliseconds: 1),
    );
    expect(find.text('会议首页'), findsNothing);
    expect(find.text('正在准备会迹'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('会议首页'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 280));

    expect(find.text('会议首页'), findsOneWidget);
    expect(find.text('正在准备会迹'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动态效果时不等待不可见的品牌动画', (tester) async {
    final preparation = _ControlledPreparation();
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(preparation),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      Application(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MeetTraceRuntimeInitializationTransition(
            viewModel: viewModel,
            ready: const Text('会议首页'),
          ),
        ),
      ),
    );
    unawaited(viewModel.start());
    await tester.pump();

    preparation.completeReady();
    await tester.pump();

    expect(find.text('会议首页'), findsOneWidget);
    expect(find.text('正在准备会迹'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('更换初始化流程时重新等待品牌动画完成', (tester) async {
    final firstPreparation = _ControlledPreparation();
    final firstViewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(firstPreparation),
    );
    final secondPreparation = _ControlledPreparation();
    final secondViewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(secondPreparation),
    );
    addTearDown(firstViewModel.dispose);
    addTearDown(secondViewModel.dispose);

    Widget build(RuntimeInitializationViewModel viewModel) => Application(
      home: MeetTraceRuntimeInitializationTransition(
        viewModel: viewModel,
        ready: const Text('会议首页'),
      ),
    );

    await tester.pumpWidget(build(firstViewModel));
    unawaited(firstViewModel.start());
    await tester.pump();
    await tester.pump(meetTraceBrandMotionDuration);
    await tester.pump();
    expect(find.text('会议首页'), findsNothing);
    expect(find.text('正在准备会迹'), findsOneWidget);

    await tester.pumpWidget(build(secondViewModel));
    unawaited(secondViewModel.start());
    await tester.pump();
    secondPreparation.completeReady();
    await tester.pump();
    await tester.pump(
      meetTraceBrandMotionDuration - const Duration(milliseconds: 1),
    );

    expect(find.text('会议首页'), findsNothing);
    expect(find.text('正在准备会迹'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('会议首页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('初始化阶段只更新内容而不替换启动页面', (tester) async {
    final preparation = _ControlledPreparation();
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(preparation),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      Application(
        home: MeetTraceRuntimeInitializationTransition(
          viewModel: viewModel,
          ready: const Text('会议首页'),
        ),
      ),
    );
    unawaited(viewModel.start());
    await tester.pump();
    final progressPage = tester.element(
      find.byKey(const ValueKey('runtime-initialization-progress')),
    );
    await tester.pump(meetTraceBrandMotionDuration);
    final wordmark = tester.element(
      find.byKey(const ValueKey('meettrace-startup-wordmark')),
    );
    expect(
      tester
          .widget<MeetTraceRibbonRevealMark>(
            find.byType(MeetTraceRibbonRevealMark),
          )
          .progress,
      1,
    );

    preparation.showDownload();
    await tester.pump();

    expect(
      tester.element(
        find.byKey(const ValueKey('runtime-initialization-progress')),
      ),
      same(progressPage),
    );
    expect(
      tester.element(find.byKey(const ValueKey('meettrace-startup-wordmark'))),
      same(wordmark),
    );
    expect(
      tester
          .widget<MeetTraceRibbonRevealMark>(
            find.byType(MeetTraceRibbonRevealMark),
          )
          .progress,
      1,
    );
    expect(find.text('正在准备会迹'), findsOneWidget);
    expect(find.text('下载离线资源'), findsOneWidget);
    expect(find.text('步骤 2 / 4'), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('运行时下载布局适配紧凑手机与双倍字体', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(_DownloadingPreparation()),
    );
    addTearDown(viewModel.dispose);
    await viewModel.start();

    await tester.pumpWidget(
      Application(home: MeetTraceStartupView(viewModel: viewModel)),
    );

    expect(
      find.byKey(const ValueKey('runtime-download-percentage')),
      findsOneWidget,
    );
    expect(find.text('34%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('数据读取失败页明确阻断清理并可重试', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      Application(home: MeetTraceDataReadBlockedView(onRetry: () => retries++)),
    );

    expect(find.text('无法读取本地数据'), findsOneWidget);
    expect(find.text('自动清理未执行。请检查设备存储状态后重试。'), findsOneWidget);
    expect(find.textContaining('已有会议数据不会被删除'), findsNothing);
    expect(find.textContaining('事实音频不会因重试而改变'), findsNothing);
    expect(find.text('无需登录 · 事实音频仅保存在本机'), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('初始化失败页不承诺保留历史数据', (tester) async {
    await tester.pumpWidget(
      Application(home: MeetTraceInitializationBlockedView(onRetry: () {})),
    );

    expect(find.text('本地能力准备未完成'), findsOneWidget);
    expect(find.text('请确认设备空间充足后重试。'), findsOneWidget);
    expect(find.textContaining('已有会议数据不会被删除'), findsNothing);
    expect(find.textContaining('事实音频不会因重试而改变'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final class _RetryFailurePreparation implements RuntimeAssetPreparationPort {
  int attempts = 0;

  @override
  Future<void> prepare({
    required void Function(RuntimeInitializationProgress progress) onProgress,
    bool forceRepair = false,
  }) async {
    attempts++;
    throw const RuntimeInitializationException(
      code: 'runtime.network.offline',
      message: '首次初始化需要联网下载离线运行资源',
    );
  }

  @override
  Future<void> grantMobileConsent() async {}

  @override
  void pause() {}
}

final class _DownloadingPreparation implements RuntimeAssetPreparationPort {
  @override
  Future<void> prepare({
    required void Function(RuntimeInitializationProgress progress) onProgress,
    bool forceRepair = false,
  }) async {
    onProgress(
      const RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.downloading,
        completedBytes: 100000000,
        totalBytes: 286314800,
        resourceName: 'SenseVoice',
      ),
    );
  }

  @override
  Future<void> grantMobileConsent() async {}

  @override
  void pause() {}
}

final class _PausedThenResumePreparation
    implements RuntimeAssetPreparationPort {
  final Completer<void> _resumeCompletion = Completer<void>();
  int _attempts = 0;

  @override
  Future<void> prepare({
    required void Function(RuntimeInitializationProgress progress) onProgress,
    bool forceRepair = false,
  }) async {
    _attempts++;
    if (_attempts == 1) {
      onProgress(
        const RuntimeInitializationProgress(
          phase: RuntimeInitializationPhase.downloading,
          completedBytes: 27600000,
          totalBytes: 286314800,
          resourceName: 'SenseVoice + Silero VAD',
        ),
      );
      throw const RuntimeInitializationException(
        code: 'runtime.download.paused',
        message: '下载已暂停，已完成的分片会保留',
      );
    }
    onProgress(
      const RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.checking,
        completedBytes: 27600000,
        totalBytes: 286314800,
        resourceName: 'SenseVoice + Silero VAD',
      ),
    );
    await _resumeCompletion.future;
  }

  void complete() {
    if (!_resumeCompletion.isCompleted) {
      _resumeCompletion.complete();
    }
  }

  @override
  Future<void> grantMobileConsent() async {}

  @override
  void pause() {}
}

final class _ControlledPreparation implements RuntimeAssetPreparationPort {
  final Completer<void> _completion = Completer<void>();
  void Function(RuntimeInitializationProgress progress)? _onProgress;

  @override
  Future<void> prepare({
    required void Function(RuntimeInitializationProgress progress) onProgress,
    bool forceRepair = false,
  }) {
    _onProgress = onProgress;
    return _completion.future;
  }

  void showDownload() {
    _onProgress?.call(
      const RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.downloading,
        completedBytes: 100000000,
        totalBytes: 286314800,
        resourceName: 'SenseVoice',
      ),
    );
  }

  void completeReady() {
    _onProgress?.call(
      const RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.ready,
        completedBytes: 286314800,
        totalBytes: 286314800,
      ),
    );
    _completion.complete();
  }

  @override
  Future<void> grantMobileConsent() async {}

  @override
  void pause() {}
}
