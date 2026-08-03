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
    expect(find.text('41%'), findsOneWidget);
    expect(find.text('100.0 MB / 239.8 MB'), findsOneWidget);
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
      closeTo(100000000 / 239762595, 0.000001),
    );
    expect(find.byType(FCircularProgress), findsNothing);
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
    expect(find.text('41%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('启动失败页不显示免登录页脚并可重试', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      Application(home: MeetTraceStartupErrorView(onRetry: () => retries++)),
    );

    expect(find.text('本地能力准备未完成'), findsOneWidget);
    expect(find.text('请确认设备空间充足后重试。已有会议数据不会被删除。'), findsOneWidget);
    expect(find.text('无需登录 · 事实音频仅保存在本机'), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧 Alpha 数据提示先导出且承诺不自动删除', (tester) async {
    await tester.pumpWidget(
      Application(
        home: MeetTraceStartupErrorView(
          title: '需要先导出旧 Alpha 录音',
          message:
              '检测到旧版数据。应用不会自动迁移或删除录音；请先退回原 Alpha 版本导出重要录音，再卸载或清除数据后安装当前版本。',
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('需要先导出旧 Alpha 录音'), findsOneWidget);
    expect(find.textContaining('不会自动迁移或删除录音'), findsOneWidget);
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
        totalBytes: 239762595,
        resourceName: 'SenseVoice',
      ),
    );
  }

  @override
  Future<void> grantMobileConsent() async {}

  @override
  void pause() {}
}
