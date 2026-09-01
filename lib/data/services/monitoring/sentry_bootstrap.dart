import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'sentry_monitoring.dart';
import 'sentry_recording_telemetry.dart';

export 'sentry_recording_telemetry.dart' show sentryRecordingTelemetryGate;

typedef AppLauncher = void Function(Widget app);

/// Sentry 的编译期运行配置。
///
/// DSN 是 Sentry 项目的公开客户端标识；具备写权限的 Auth Token 只允许放在
/// `sentry.properties` 或 CI Secret 中，不能通过此配置进入应用包。
final class SentryRuntimeConfiguration {
  const SentryRuntimeConfiguration._({
    required this.enabled,
    required this.dsn,
    required this.environment,
    required this.release,
    required this.dist,
    required this.tracesSampleRate,
    required this.performanceSampled,
  });

  static const _projectDsn =
      'https://5bc98b0f98fd646730e6ea415eec20dc@o4507501589823488.'
      'ingest.us.sentry.io/4511863291576320';

  final bool enabled;
  final String dsn;
  final String environment;
  final String? release;
  final String? dist;

  /// 仅用于决定本进程是否采样；运行时由 [performanceSampled] 固定返回 1 或 0。
  final double tracesSampleRate;
  final bool performanceSampled;

  static final SentryRuntimeConfiguration _environmentConfiguration =
      SentryRuntimeConfiguration._fromEnvironment();

  factory SentryRuntimeConfiguration.fromEnvironment() =>
      _environmentConfiguration;

  factory SentryRuntimeConfiguration._fromEnvironment() {
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
      release: const String.fromEnvironment('SENTRY_RELEASE'),
      dist: const String.fromEnvironment('SENTRY_DIST'),
      tracesSampleRate: const String.fromEnvironment(
        'SENTRY_TRACES_SAMPLE_RATE',
        defaultValue: '0.2',
      ),
    );
  }

  @visibleForTesting
  factory SentryRuntimeConfiguration.fromValues({
    required bool enabled,
    required String dsn,
    required String environment,
    String release = '',
    String dist = '',
    required String tracesSampleRate,
    bool? performanceSampled,
  }) {
    final normalizedDsn = dsn.trim();
    final normalizedEnvironment = environment.trim();
    final normalizedTraceRate = _parseSampleRate(
      tracesSampleRate,
      fallback: 0.2,
    );
    return SentryRuntimeConfiguration._(
      enabled: enabled && normalizedDsn.isNotEmpty,
      dsn: normalizedDsn,
      environment: normalizedEnvironment.isEmpty
          ? 'production'
          : normalizedEnvironment,
      release: _normalizedOptional(release),
      dist: _normalizedOptional(dist),
      tracesSampleRate: normalizedTraceRate,
      performanceSampled:
          performanceSampled ?? Random().nextDouble() < normalizedTraceRate,
    );
  }

  void applyTo(SentryFlutterOptions options) {
    options
      ..dsn = dsn
      ..environment = environment
      ..sampleRate = 1
      ..sendDefaultPii = false
      ..attachStacktrace = true
      ..attachThreads = false
      ..reportPackages = false
      ..sendClientReports = true
      ..captureFailedRequests = false
      ..captureNativeFailedRequests = false
      ..recordHttpBreadcrumbs = true
      ..maxRequestBodySize = MaxRequestBodySize.never
      ..enableDartSymbolication = true
      ..propagateTraceparent = false
      ..strictTraceContinuation = true
      ..groupExceptions = true
      ..enableLogs = false
      ..enableMetrics = true
      ..includeModuleInStackTrace = true
      ..maxBreadcrumbs = 100
      ..maxCacheItems = 10
      ..autoInitializeNativeSdk = true
      ..enableAutoSessionTracking = true
      ..enableNativeCrashHandling = true
      ..anrEnabled = true
      ..enableTombstone = true
      ..enableAutoNativeBreadcrumbs = false
      ..enableAppLifecycleBreadcrumbs = true
      ..enableWindowMetricBreadcrumbs = false
      ..enableBrightnessChangeBreadcrumbs = false
      ..enableTextScaleChangeBreadcrumbs = false
      ..enableMemoryPressureBreadcrumbs = true
      ..reportSilentFlutterErrors = true
      ..enableWatchdogTerminationTracking = true
      ..enableAutoPerformanceTracing = true
      ..attachScreenshot = false
      ..enableUserInteractionBreadcrumbs = false
      ..enableUserInteractionTracing = false
      ..enableTimeToFullDisplayTracing = true
      ..enableAppHangTracking = true
      ..enableFramesTracking = true
      ..beforeSend = SentryMonitoring.sanitizeEvent
      ..beforeSendTransaction = SentryMonitoring.sanitizeTransaction
      ..beforeBreadcrumb = SentryMonitoring.sanitizeBreadcrumb
      ..beforeSendMetric = SentryMonitoring.sanitizeMetric
      ..beforeSendSpan = SentryMonitoring.sanitizeSpan;

    options.tracePropagationTargets.clear();

    if (release case final release?) {
      options.release = release;
    }
    if (dist case final dist?) {
      options.dist = dist;
    }

    options.tracesSampler = (_) => performanceSampled ? 1 : 0;
    options.replay
      ..sessionSampleRate = 0
      ..onErrorSampleRate = 0;
    // sentry_flutter 9.28.0 的 profiling setter 仍是 experimental；保持 SDK 默认关闭。
  }

  SentryRuntimeConfiguration resamplePerformance() =>
      SentryRuntimeConfiguration._(
        enabled: enabled,
        dsn: dsn,
        environment: environment,
        release: release,
        dist: dist,
        tracesSampleRate: tracesSampleRate,
        performanceSampled: Random().nextDouble() < tracesSampleRate,
      );

  static double _parseSampleRate(String rawValue, {required double fallback}) {
    final parsed = double.tryParse(rawValue.trim());
    if (parsed == null || !parsed.isFinite) {
      return fallback;
    }
    return parsed.clamp(0, 1).toDouble();
  }

  static String? _normalizedOptional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

/// 严格串行切换 Sentry 运行时状态。
///
/// 原生调用超时后会快速拒绝后续请求，直到该调用收敛；若它永久不返回，
/// 由进程重启按已保存偏好恢复，避免脱离旧调用后并发操作 SDK。
final class SentryRemoteDiagnosticsController
    implements RemoteDiagnosticsController {
  SentryRemoteDiagnosticsController(
    this.configuration, {
    bool Function()? isEnabled,
    Future<void> Function()? close,
    Future<void> Function(SentryRuntimeConfiguration)? initialize,
    this.transitionTimeout = const Duration(seconds: 10),
  }) : _isEnabled = isEnabled ?? _sentryIsEnabled,
       _close = close ?? Sentry.close,
       _initialize = initialize ?? _initializeSentry;

  static Future<void> _pendingTransition = Future<void>.value();
  static bool _poisoned = false;

  @visibleForTesting
  static void resetTransitionState() {
    _pendingTransition = Future<void>.value();
    _poisoned = false;
  }

  final SentryRuntimeConfiguration configuration;
  final bool Function() _isEnabled;
  final Future<void> Function() _close;
  final Future<void> Function(SentryRuntimeConfiguration) _initialize;
  final Duration transitionTimeout;

  @override
  Future<bool> setEnabled(bool enabled) {
    if (_poisoned) {
      debugPrint('远程诊断状态链已超时，等待底层操作收敛。');
      return Future<bool>.value(false);
    }
    final transition = _pendingTransition.then((_) => _apply(enabled));
    _pendingTransition = transition.then<void>((_) {}, onError: (_, _) {});
    return transition.timeout(
      transitionTimeout,
      onTimeout: () {
        _poisoned = true;
        debugPrint('远程诊断状态切换超时。');
        if (enabled) {
          // 迟到的 init 完成后立即按同一串行链关闭，保持 fail-closed。
          final closeTransition = _pendingTransition.then((_) => _apply(false));
          _pendingTransition = closeTransition.then<void>(
            (_) {},
            onError: (_, _) {},
          );
          unawaited(
            closeTransition.then((_) {
              _poisoned = false;
            }),
          );
        } else {
          unawaited(
            transition.then((_) {
              _poisoned = false;
            }),
          );
        }
        return false;
      },
    );
  }

  Future<bool> _apply(bool enabled) async {
    try {
      if (!enabled) {
        sentryRecordingTelemetryGate.configure(
          enabled: false,
          performanceSampled: false,
        );
        if (_isEnabled()) {
          await _close();
        }
        return !_isEnabled();
      }
      if (!configuration.enabled || _isEnabled()) {
        // 编译期关闭是当前构建的能力上限，仍接受用户的本机偏好。
        return true;
      }
      final sampledConfiguration = configuration.resamplePerformance();
      await _initialize(sampledConfiguration);
      final initialized = _isEnabled();
      sentryRecordingTelemetryGate.configure(
        enabled: initialized,
        performanceSampled: sampledConfiguration.performanceSampled,
      );
      return initialized;
    } on Object catch (error) {
      // 远程诊断故障不得阻断 App、事实录音或最终处理。
      debugPrint('远程诊断状态切换失败：$error');
      return false;
    }
  }

  static bool _sentryIsEnabled() => Sentry.isEnabled;

  static Future<void> _initializeSentry(
    SentryRuntimeConfiguration configuration,
  ) => SentryFlutter.init(configuration.applyTo);
}

List<NavigatorObserver> createSentryNavigatorObservers() {
  return <NavigatorObserver>[
    SentryNavigatorObserver(
      enableNewTraceOnNavigation: true,
      setRouteNameAsTransaction: true,
    ),
  ];
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
    bool userEnabled = false,
    DateTime? appStartedAt,
  }) async {
    final resolvedConfiguration =
        configuration ?? SentryRuntimeConfiguration.fromEnvironment();
    final root = SentryWidget(child: app);
    var launchStarted = false;

    Future<void> launch() async {
      if (launchStarted) {
        return;
      }
      launchStarted = true;
      await beforeRunApp?.call();
      appLauncher(root);
    }

    if (!resolvedConfiguration.enabled || !userEnabled) {
      sentryRecordingTelemetryGate.configure(
        enabled: false,
        performanceSampled: false,
      );
      WidgetsFlutterBinding.ensureInitialized();
      await launch();
      return;
    }

    try {
      await SentryFlutter.init(
        resolvedConfiguration.applyTo,
        appRunner: () async {
          sentryRecordingTelemetryGate.configure(
            enabled: true,
            performanceSampled: resolvedConfiguration.performanceSampled,
          );
          ISentrySpan? appStartSpan;
          try {
            appStartSpan = Sentry.startTransaction(
              'app.start',
              'app.start',
              bindToScope: true,
              startTimestamp: appStartedAt,
            );
          } on Object {
            // 启动 Span 失败不影响应用启动。
          }
          await launch();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              appStartSpan?.finish(status: const SpanStatus.ok()).ignore();
            } on Object {
              // 结束 Span 失败不影响首帧。
            }
          });
        },
      );
    } on Object {
      sentryRecordingTelemetryGate.configure(
        enabled: false,
        performanceSampled: false,
      );
      if (launchStarted) {
        rethrow;
      }
      WidgetsFlutterBinding.ensureInitialized();
      await launch();
    }
  }
}
