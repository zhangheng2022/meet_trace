import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/monitoring/sentry_bootstrap.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  setUp(SentryRemoteDiagnosticsController.resetTransitionState);

  group('SentryRuntimeConfiguration', () {
    test('DSN 为空时强制关闭上报', () {
      final configuration = _configuration(enabled: true, dsn: '  ');

      expect(configuration.enabled, isFalse);
      expect(configuration.dsn, isEmpty);
    });

    test('环境配置在同一进程只创建和抽样一次', () {
      expect(
        SentryRuntimeConfiguration.fromEnvironment(),
        same(SentryRuntimeConfiguration.fromEnvironment()),
      );
    });

    test('规范化环境并约束进程性能采样率', () {
      final configuration = _configuration(
        environment: ' staging ',
        release: ' com.meettrace.app@1.0.0+7 ',
        dist: ' 7 ',
        tracesSampleRate: '1.5',
      );

      expect(configuration.environment, 'staging');
      expect(configuration.release, 'com.meettrace.app@1.0.0+7');
      expect(configuration.dist, '7');
      expect(configuration.tracesSampleRate, 1);
    });

    test('仅启用产品合同允许的 Sentry 功能', () {
      final configuration = _configuration(
        release: 'com.meettrace.app@1.0.0+7',
        dist: '7',
        performanceSampled: true,
      );
      final options = SentryFlutterOptions();

      configuration.applyTo(options);

      expect(options.dsn, configuration.dsn);
      expect(options.environment, 'production');
      expect(options.release, 'com.meettrace.app@1.0.0+7');
      expect(options.dist, '7');
      expect(options.sampleRate, 1);
      expect(options.sendDefaultPii, isFalse);
      expect(options.attachStacktrace, isTrue);
      expect(options.attachThreads, isFalse);
      expect(options.reportPackages, isFalse);
      expect(options.sendClientReports, isTrue);
      expect(options.enableLogs, isFalse);
      expect(options.enableMetrics, isTrue);
      expect(options.captureFailedRequests, isFalse);
      expect(options.captureNativeFailedRequests, isFalse);
      expect(options.recordHttpBreadcrumbs, isFalse);
      expect(options.maxBreadcrumbs, 100);
      expect(options.maxCacheItems, 10);
      expect(options.enableAutoSessionTracking, isTrue);
      expect(options.enableAutoPerformanceTracing, isTrue);
      expect(options.enableFramesTracking, isTrue);
      expect(options.enableUserInteractionBreadcrumbs, isFalse);
      expect(options.enableUserInteractionTracing, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isFalse);
      expect(options.enableAppLifecycleBreadcrumbs, isTrue);
      expect(options.enableWindowMetricBreadcrumbs, isFalse);
      expect(options.enableBrightnessChangeBreadcrumbs, isFalse);
      expect(options.enableTextScaleChangeBreadcrumbs, isFalse);
      expect(options.enableMemoryPressureBreadcrumbs, isTrue);
      expect(options.enableTimeToFullDisplayTracing, isTrue);
      expect(options.attachScreenshot, isFalse);
      expect(options.enableNativeCrashHandling, isTrue);
      expect(options.anrEnabled, isTrue);
      expect(options.enableTombstone, isTrue);
      expect(options.enableAppHangTracking, isTrue);
      expect(options.enableWatchdogTerminationTracking, isTrue);
      expect(options.reportSilentFlutterErrors, isTrue);
      expect(options.replay.sessionSampleRate, 0);
      expect(options.replay.onErrorSampleRate, 0);
    });

    test('性能采样按进程固定返回一或零', () {
      final options = SentryFlutterOptions();
      _configuration(performanceSampled: true).applyTo(options);
      final samplingContext = SentrySamplingContext.forTransaction(
        SentryTransactionContext('recording', 'ui.action'),
      );

      expect(options.tracesSampler!(samplingContext), 1);

      final unsampled = SentryFlutterOptions();
      _configuration(performanceSampled: false).applyTo(unsampled);
      expect(unsampled.tracesSampler!(samplingContext), 0);
    });
  });

  testWidgets('未启用时跳过 Sentry 并直接启动应用', (WidgetTester tester) async {
    final calls = <String>[];
    Widget? launchedApp;

    await SentryBootstrap.run(
      app: const SizedBox(),
      configuration: _configuration(enabled: false),
      beforeRunApp: () => calls.add('before'),
      appLauncher: (app) {
        calls.add('launch');
        launchedApp = app;
      },
    );

    expect(calls, <String>['before', 'launch']);
    expect(launchedApp, isA<SentryWidget>());
    await tester.pumpWidget(launchedApp!);
  });

  testWidgets('用户退出时不初始化 Sentry 并直接启动应用', (WidgetTester tester) async {
    Widget? launchedApp;

    await SentryBootstrap.run(
      app: const SizedBox(),
      configuration: _configuration(dsn: 'https://public@sentry.example.com/1'),
      userEnabled: false,
      appLauncher: (app) => launchedApp = app,
    );

    expect(launchedApp, isA<SentryWidget>());
    await tester.pumpWidget(launchedApp!);
    expect(Sentry.isEnabled, isFalse);
  });

  testWidgets('Sentry 初始化失败时仍启动应用', (WidgetTester tester) async {
    final calls = <String>[];
    Widget? launchedApp;

    await SentryBootstrap.run(
      app: const SizedBox(),
      configuration: _configuration(dsn: 'not-a-dsn'),
      userEnabled: true,
      beforeRunApp: () => calls.add('before'),
      appLauncher: (app) {
        calls.add('launch');
        launchedApp = app;
      },
    );

    expect(calls, <String>['before', 'launch']);
    expect(launchedApp, isA<SentryWidget>());
    await tester.pumpWidget(launchedApp!);
    expect(Sentry.isEnabled, isFalse);
  });

  test('编译期关闭时接受开启偏好但不初始化 SDK', () async {
    final controller = SentryRemoteDiagnosticsController(
      _configuration(enabled: false),
    );

    expect(await controller.setEnabled(true), isTrue);
    expect(Sentry.isEnabled, isFalse);
  });

  test('SDK 未初始化时关闭诊断成功', () async {
    final controller = SentryRemoteDiagnosticsController(_configuration());

    expect(await controller.setEnabled(false), isTrue);
  });

  test('SDK 初始化异常被隔离并返回失败', () async {
    final controller = SentryRemoteDiagnosticsController(
      _configuration(dsn: 'not-a-dsn'),
    );

    expect(await controller.setEnabled(true), isFalse);
  });

  test('启用超时后在迟到 init 完成时串行自动关闭', () async {
    final initStarted = Completer<void>();
    final releaseInit = Completer<void>();
    final closeStarted = Completer<void>();
    final order = <String>[];
    var enabled = false;
    final controller = SentryRemoteDiagnosticsController(
      _configuration(dsn: 'https://public@sentry.example.com/1'),
      isEnabled: () => enabled,
      initialize: (_) async {
        order.add('init-start');
        initStarted.complete();
        await releaseInit.future;
        enabled = true;
        order.add('init-end');
      },
      close: () async {
        order.add('close');
        enabled = false;
        closeStarted.complete();
      },
      transitionTimeout: const Duration(milliseconds: 20),
    );

    final enabling = controller.setEnabled(true);
    await initStarted.future;

    expect(await enabling, isFalse);
    expect(await controller.setEnabled(false), isFalse);
    expect(closeStarted.isCompleted, isFalse);

    releaseInit.complete();
    await closeStarted.future.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);
    expect(order, <String>['init-start', 'init-end', 'close']);
    expect(enabled, isFalse);
    expect(await controller.setEnabled(false), isTrue);
  });

  test('关闭超时后在迟到 close 完成时恢复状态链', () async {
    final closeStarted = Completer<void>();
    final releaseClose = Completer<void>();
    final closeCompleted = Completer<void>();
    var enabled = true;
    final controller = SentryRemoteDiagnosticsController(
      _configuration(),
      isEnabled: () => enabled,
      close: () async {
        closeStarted.complete();
        await releaseClose.future;
        enabled = false;
        closeCompleted.complete();
      },
      transitionTimeout: const Duration(milliseconds: 20),
    );

    final disabling = controller.setEnabled(false);
    await closeStarted.future;

    expect(await disabling, isFalse);
    expect(await controller.setEnabled(false), isFalse);

    releaseClose.complete();
    await closeCompleted.future.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);
    expect(await controller.setEnabled(false), isTrue);
  });

  test('启用超时后的自动关闭排在已入队切换之后', () async {
    final initStarted = Completer<void>();
    final releaseInit = Completer<void>();
    var enabled = false;
    var activeCloses = 0;
    var maxConcurrentCloses = 0;
    var closeCalls = 0;
    final controller = SentryRemoteDiagnosticsController(
      _configuration(),
      isEnabled: () => enabled,
      initialize: (_) async {
        initStarted.complete();
        await releaseInit.future;
        enabled = true;
      },
      close: () async {
        closeCalls += 1;
        activeCloses += 1;
        maxConcurrentCloses = maxConcurrentCloses < activeCloses
            ? activeCloses
            : maxConcurrentCloses;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        enabled = false;
        activeCloses -= 1;
      },
      transitionTimeout: const Duration(seconds: 2),
    );

    final enabling = controller.setEnabled(true);
    await initStarted.future;
    await Future<void>.delayed(const Duration(seconds: 1));
    final disabling = controller.setEnabled(false);

    expect(await enabling, isFalse);
    releaseInit.complete();
    expect(await disabling, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(closeCalls, 1);
    expect(maxConcurrentCloses, 1);
    expect(enabled, isFalse);
  });

  test('迟到的自动关闭失败后允许再次关闭', () async {
    final initStarted = Completer<void>();
    final releaseInit = Completer<void>();
    final firstCloseAttempted = Completer<void>();
    var enabled = false;
    var closeAttempts = 0;
    final controller = SentryRemoteDiagnosticsController(
      _configuration(),
      isEnabled: () => enabled,
      initialize: (_) async {
        initStarted.complete();
        await releaseInit.future;
        enabled = true;
      },
      close: () async {
        closeAttempts += 1;
        if (closeAttempts == 1) {
          firstCloseAttempted.complete();
          throw StateError('close failed');
        }
        enabled = false;
      },
      transitionTimeout: const Duration(milliseconds: 20),
    );

    final enabling = controller.setEnabled(true);
    await initStarted.future;
    expect(await enabling, isFalse);

    releaseInit.complete();
    await firstCloseAttempted.future.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);
    expect(await controller.setEnabled(false), isTrue);
    expect(closeAttempts, 2);
    expect(enabled, isFalse);
  });

  test('底层操作永久挂起时快速拒绝后续请求并由进程重启恢复', () async {
    final neverCompletes = Completer<void>();
    var initializeCalls = 0;
    final controller = SentryRemoteDiagnosticsController(
      _configuration(),
      isEnabled: () => false,
      initialize: (_) {
        initializeCalls += 1;
        return neverCompletes.future;
      },
      transitionTimeout: const Duration(milliseconds: 20),
    );

    expect(await controller.setEnabled(true), isFalse);
    expect(await controller.setEnabled(false), isFalse);
    expect(initializeCalls, 1);

    // 测试重置等价于新进程重新按本机偏好装配控制器。
    SentryRemoteDiagnosticsController.resetTransitionState();
    expect(await controller.setEnabled(false), isTrue);
  });
}

SentryRuntimeConfiguration _configuration({
  bool enabled = true,
  String dsn = 'https://public@example.ingest.sentry.io/1',
  String environment = 'production',
  String release = '',
  String dist = '',
  String tracesSampleRate = '0.2',
  bool? performanceSampled,
}) {
  return SentryRuntimeConfiguration.fromValues(
    enabled: enabled,
    dsn: dsn,
    environment: environment,
    release: release,
    dist: dist,
    tracesSampleRate: tracesSampleRate,
    performanceSampled: performanceSampled,
  );
}
