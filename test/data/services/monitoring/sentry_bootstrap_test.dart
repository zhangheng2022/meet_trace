// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/monitoring/sentry_bootstrap.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('SentryRuntimeConfiguration', () {
    test('DSN 为空时强制关闭上报', () {
      final configuration = _configuration(enabled: true, dsn: '  ');

      expect(configuration.enabled, isFalse);
      expect(configuration.dsn, isEmpty);
    });

    test('规范化环境并约束全部采样率', () {
      final configuration = _configuration(
        environment: ' staging ',
        tracesSampleRate: '1.5',
        profilesSampleRate: '-0.2',
        replaySessionSampleRate: 'invalid',
        replayOnErrorSampleRate: 'NaN',
      );

      expect(configuration.environment, 'staging');
      expect(configuration.tracesSampleRate, 1);
      expect(configuration.profilesSampleRate, 0);
      expect(configuration.replaySessionSampleRate, 0.1);
      expect(configuration.replayOnErrorSampleRate, 1);
    });

    test('启用完整 Sentry 功能并保留 Replay 遮罩', () {
      final configuration = _configuration();
      final options = SentryFlutterOptions();

      configuration.applyTo(options);

      expect(options.dsn, configuration.dsn);
      expect(options.environment, 'production');
      expect(options.sampleRate, 1);
      expect(options.sendDefaultPii, isTrue);
      expect(options.attachStacktrace, isTrue);
      expect(options.attachThreads, isTrue);
      expect(options.enableLogs, isTrue);
      expect(options.enableMetrics, isTrue);
      expect(options.captureFailedRequests, isTrue);
      expect(options.captureNativeFailedRequests, isTrue);
      expect(options.recordHttpBreadcrumbs, isTrue);
      expect(options.tracesSampleRate, 0.2);
      expect(options.profilesSampleRate, 0.1);
      expect(options.enableAutoPerformanceTracing, isTrue);
      expect(options.enableStandaloneAppStartTracing, isTrue);
      expect(options.enableFramesTracking, isTrue);
      expect(options.enableUserInteractionBreadcrumbs, isTrue);
      expect(options.enableUserInteractionTracing, isTrue);
      expect(options.enableTimeToFullDisplayTracing, isTrue);
      expect(options.attachScreenshot, isTrue);
      expect(options.attachViewHierarchy, isTrue);
      expect(options.enableNativeCrashHandling, isTrue);
      expect(options.anrEnabled, isTrue);
      expect(options.enableTombstone, isTrue);
      expect(options.enableAppHangTracking, isTrue);
      expect(options.replay.sessionSampleRate, 0.1);
      expect(options.replay.onErrorSampleRate, 1);
      expect(options.replay.quality, SentryReplayQuality.high);
      expect(options.privacy.maskAllText, isTrue);
      expect(options.privacy.maskAllImages, isTrue);
      expect(options.privacy.maskAssetImages, isTrue);
    });

    test('录音期间丢弃交互 Breadcrumb 并禁止错误截图', () async {
      final gate = SentryRecordingTelemetryGate()..setRecordingActive(true);
      final options = SentryFlutterOptions();
      _configuration().applyTo(options, telemetryGate: gate);
      final samplingContext = SentrySamplingContext.forTransaction(
        SentryTransactionContext('recording', 'ui.action'),
      );

      final interaction = Breadcrumb.userInteraction(subCategory: 'click');
      final lifecycle = Breadcrumb(category: 'app.lifecycle');

      expect(options.tracesSampler!(samplingContext), 0);
      expect(options.beforeBreadcrumb!(interaction, Hint()), isNull);
      expect(options.beforeBreadcrumb!(lifecycle, Hint()), same(lifecycle));
      expect(
        await options.beforeCaptureScreenshot!(SentryEvent(), Hint(), false),
        isFalse,
      );
      expect(
        await options.beforeCaptureViewHierarchy!(SentryEvent(), Hint(), false),
        isFalse,
      );

      gate.setRecordingActive(false);
      expect(options.tracesSampler!(samplingContext), 0.2);
      expect(options.beforeBreadcrumb!(interaction, Hint()), same(interaction));
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
    expect(launchedApp, isA<SizedBox>());
  });
}

SentryRuntimeConfiguration _configuration({
  bool enabled = true,
  String dsn = 'https://public@example.ingest.sentry.io/1',
  String environment = 'production',
  String tracesSampleRate = '0.2',
  String profilesSampleRate = '0.1',
  String replaySessionSampleRate = '0.1',
  String replayOnErrorSampleRate = '1',
}) {
  return SentryRuntimeConfiguration.fromValues(
    enabled: enabled,
    dsn: dsn,
    environment: environment,
    tracesSampleRate: tracesSampleRate,
    profilesSampleRate: profilesSampleRate,
    replaySessionSampleRate: replaySessionSampleRate,
    replayOnErrorSampleRate: replayOnErrorSampleRate,
  );
}
