import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/runtime_initialization.dart';
import 'package:meettrace/domain/ports/runtime_asset_preparation.dart';
import 'package:meettrace/domain/use_cases/initialize_runtime_assets.dart';
import 'package:meettrace/ui/features/startup/view_models/runtime_initialization_view_model.dart';
import 'package:meettrace/ui/features/startup/views/meettrace_startup_view.dart';

void main() {
  testWidgets('启动页说明真实本地准备内容且不显示免登录页脚', (tester) async {
    await tester.pumpWidget(const Application(home: MeetTraceStartupView()));

    expect(find.text('会迹'), findsOneWidget);
    expect(find.text('MeetTrace'), findsOneWidget);
    expect(find.text('正在打开本地工作区'), findsOneWidget);
    expect(find.text('恢复会议记录，并确认离线转录能力是否可用。'), findsOneWidget);
    expect(find.text('无需登录 · 事实音频仅保存在本机'), findsNothing);
    expect(find.byType(FHeader), findsNothing);
    expect(find.byType(FProgress), findsOneWidget);
    expect(find.byType(FCircularProgress), findsOneWidget);
    expect(
      tester
          .widget<FCircularProgress>(find.byType(FCircularProgress))
          .semanticsLabel,
      '正在读取本地数据',
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('meettrace-startup-progress')))
          .width,
      lessThan(32),
    );
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
      find.byKey(const ValueKey('meettrace-startup-loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meettrace-startup-local-evidence')),
      findsNothing,
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
          .getSize(find.byKey(const ValueKey('meettrace-startup-loading')))
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

    expect(find.text('准备离线转录'), findsOneWidget);
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

  testWidgets('快速检查沿用基础启动内容并平滑进入首页', (tester) async {
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
    expect(find.text('正在打开本地工作区'), findsOneWidget);
    expect(find.text('准备离线转录'), findsNothing);

    preparation.completeReady();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    expect(find.text('会议首页'), findsOneWidget);
    expect(find.text('准备离线转录'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('仅在确实需要准备资源时显示详细初始化步骤', (tester) async {
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
    preparation.showDownload();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    expect(find.text('准备离线转录'), findsOneWidget);
    expect(find.text('下载离线资源'), findsOneWidget);
    expect(find.text('步骤 2 / 4'), findsOneWidget);
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
