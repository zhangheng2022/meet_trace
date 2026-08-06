// Sentry 9.26 将 Profiling、View Hierarchy 和独立 App Start 标记为实验 API；
// 产品决策要求启用这些能力，升级 SDK 时必须重新验证这些调用。
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meettrace/domain/ports/recording_telemetry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef AppLauncher = void Function(Widget app);

final class SentryRecordingTelemetryGate implements RecordingTelemetryGate {
  bool _recordingActive = false;

  @override
  bool get recordingActive => _recordingActive;

  @override
  void setRecordingActive(bool active) {
    _recordingActive = active;
  }
}

final sentryRecordingTelemetryGate = SentryRecordingTelemetryGate();

/// Sentry 的编译期运行配置。
///
/// DSN 是 Sentry 项目的公开客户端标识；具备写权限的 Auth Token 只允许放在
/// `sentry.properties` 或 CI Secret 中，不能通过此配置进入应用包。
final class SentryRuntimeConfiguration {
  const SentryRuntimeConfiguration._({
    required this.enabled,
    required this.dsn,
    required this.environment,
    required this.tracesSampleRate,
    required this.profilesSampleRate,
    required this.replaySessionSampleRate,
    required this.replayOnErrorSampleRate,
  });

  static const _projectDsn =
      'https://5bc98b0f98fd646730e6ea415eec20dc@o4507501589823488.'
      'ingest.us.sentry.io/4511863291576320';

  final bool enabled;
  final String dsn;
  final String environment;
  final double tracesSampleRate;
  final double profilesSampleRate;
  final double replaySessionSampleRate;
  final double replayOnErrorSampleRate;

  factory SentryRuntimeConfiguration.fromEnvironment() {
    return SentryRuntimeConfiguration.fromValues(
      enabled: const bool.fromEnvironment(
        'SENTRY_ENABLED',
        defaultValue: kReleaseMode,
      ),
      dsn: const String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue: _projectDsn,
      ),
      environment: const String.fromEnvironment(
        'SENTRY_ENVIRONMENT',
        defaultValue: kReleaseMode ? 'production' : 'development',
      ),
      tracesSampleRate: const String.fromEnvironment(
        'SENTRY_TRACES_SAMPLE_RATE',
        defaultValue: '0.2',
      ),
      profilesSampleRate: const String.fromEnvironment(
        'SENTRY_PROFILES_SAMPLE_RATE',
        defaultValue: '0.1',
      ),
      replaySessionSampleRate: const String.fromEnvironment(
        'SENTRY_REPLAY_SESSION_SAMPLE_RATE',
        defaultValue: '0.1',
      ),
      replayOnErrorSampleRate: const String.fromEnvironment(
        'SENTRY_REPLAY_ON_ERROR_SAMPLE_RATE',
        defaultValue: '1',
      ),
    );
  }

  @visibleForTesting
  factory SentryRuntimeConfiguration.fromValues({
    required bool enabled,
    required String dsn,
    required String environment,
    required String tracesSampleRate,
    required String profilesSampleRate,
    required String replaySessionSampleRate,
    required String replayOnErrorSampleRate,
  }) {
    final normalizedDsn = dsn.trim();
    final normalizedEnvironment = environment.trim();
    return SentryRuntimeConfiguration._(
      enabled: enabled && normalizedDsn.isNotEmpty,
      dsn: normalizedDsn,
      environment: normalizedEnvironment.isEmpty
          ? 'production'
          : normalizedEnvironment,
      tracesSampleRate: _parseSampleRate(tracesSampleRate, fallback: 0.2),
      profilesSampleRate: _parseSampleRate(profilesSampleRate, fallback: 0.1),
      replaySessionSampleRate: _parseSampleRate(
        replaySessionSampleRate,
        fallback: 0.1,
      ),
      replayOnErrorSampleRate: _parseSampleRate(
        replayOnErrorSampleRate,
        fallback: 1,
      ),
    );
  }

  void applyTo(
    SentryFlutterOptions options, {
    RecordingTelemetryGate? telemetryGate,
  }) {
    final gate = telemetryGate ?? sentryRecordingTelemetryGate;
    options
      ..dsn = dsn
      ..environment = environment
      ..sampleRate = 1
      ..sendDefaultPii = true
      ..attachStacktrace = true
      ..attachThreads = true
      ..reportPackages = true
      ..enablePrintBreadcrumbs = true
      ..captureFailedRequests = true
      ..captureNativeFailedRequests = true
      ..recordHttpBreadcrumbs = true
      ..enableDeduplication = true
      ..sendClientReports = true
      ..enableScopeSync = true
      ..enableDartSymbolication = true
      ..propagateTraceparent = true
      ..strictTraceContinuation = true
      ..groupExceptions = true
      ..enableLogs = true
      ..enableMetrics = true
      ..includeModuleInStackTrace = true
      ..tracesSampleRate = tracesSampleRate
      ..profilesSampleRate = profilesSampleRate
      ..autoInitializeNativeSdk = true
      ..enableAutoSessionTracking = true
      ..enableNativeCrashHandling = true
      ..anrEnabled = true
      ..enableTombstone = true
      ..enableAutoNativeBreadcrumbs = true
      ..enableAppLifecycleBreadcrumbs = true
      ..enableWindowMetricBreadcrumbs = true
      ..enableBrightnessChangeBreadcrumbs = true
      ..enableTextScaleChangeBreadcrumbs = true
      ..enableMemoryPressureBreadcrumbs = true
      ..reportSilentFlutterErrors = true
      ..enableWatchdogTerminationTracking = true
      ..enableNdkScopeSync = true
      ..enableAutoPerformanceTracing = true
      ..enableStandaloneAppStartTracing = true
      ..attachScreenshot = true
      ..screenshotQuality = SentryScreenshotQuality.full
      ..enableUserInteractionBreadcrumbs = true
      ..enableUserInteractionTracing = true
      ..enableTimeToFullDisplayTracing = true
      ..attachViewHierarchy = true
      ..reportViewHierarchyIdentifiers = true
      ..enableAppHangTracking = true
      ..enableFramesTracking = true
      ..enableNativeTraceSync = true;

    options.tracesSampler = (_) => gate.recordingActive ? 0 : tracesSampleRate;
    options.beforeSendTransaction = (transaction, _) =>
        gate.recordingActive ? null : transaction;
    options.beforeBreadcrumb = (breadcrumb, _) {
      if (gate.recordingActive &&
          (breadcrumb?.category?.startsWith('ui.') ?? false)) {
        return null;
      }
      return breadcrumb;
    };
    options.beforeCaptureScreenshot = (_, _, _) => !gate.recordingActive;
    options.beforeCaptureViewHierarchy = (_, _, _) => !gate.recordingActive;

    options.replay
      ..sessionSampleRate = replaySessionSampleRate
      ..onErrorSampleRate = replayOnErrorSampleRate
      ..quality = SentryReplayQuality.high;
    options.privacy
      ..maskAllText = true
      ..maskAllImages = true
      ..maskAssetImages = true;
  }

  static double _parseSampleRate(String rawValue, {required double fallback}) {
    final parsed = double.tryParse(rawValue.trim());
    if (parsed == null || !parsed.isFinite) {
      return fallback;
    }
    return parsed.clamp(0, 1).toDouble();
  }
}

List<NavigatorObserver> createSentryNavigatorObservers() {
  return <NavigatorObserver>[SentryNavigatorObserver()];
}

/// 组合根中的 Sentry 启动适配器。
///
/// 未启用时不初始化 SDK。SDK 在运行 App Runner 前失败时降级为无监控启动，
/// 监控故障不得阻断事实录音能力。
abstract final class SentryBootstrap {
  static Future<void> run({
    required Widget app,
    FutureOr<void> Function()? beforeRunApp,
    SentryRuntimeConfiguration? configuration,
    AppLauncher appLauncher = runApp,
    RecordingTelemetryGate? telemetryGate,
  }) async {
    final resolvedConfiguration =
        configuration ?? SentryRuntimeConfiguration.fromEnvironment();
    var launchStarted = false;

    Future<void> launch(Widget root) async {
      if (launchStarted) {
        return;
      }
      launchStarted = true;
      await beforeRunApp?.call();
      appLauncher(root);
    }

    if (!resolvedConfiguration.enabled) {
      WidgetsFlutterBinding.ensureInitialized();
      await launch(app);
      return;
    }

    try {
      await SentryFlutter.init(
        (options) => resolvedConfiguration.applyTo(
          options,
          telemetryGate: telemetryGate,
        ),
        appRunner: () async {
          await launch(SentryWidget(child: app));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(SentryFlutter.currentDisplay()?.reportFullyDisplayed());
          });
        },
      );
    } on Object {
      if (launchStarted) {
        rethrow;
      }
      WidgetsFlutterBinding.ensureInitialized();
      await launch(app);
    }
  }
}
