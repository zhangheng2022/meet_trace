import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/data/repositories/shared_preferences_remote_diagnostics_repository.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';
import 'package:meettrace/data/services/monitoring/sentry_bootstrap.dart';
import 'package:meettrace/domain/models/app_language.dart';
import 'package:meettrace/domain/models/app_theme.dart';
import 'package:meettrace/theme/system_ui.dart';

Future<void> main() async {
  final appStartedAt = DateTime.now().toUtc();
  WidgetsFlutterBinding.ensureInitialized();
  final sentryConfiguration = SentryRuntimeConfiguration.fromEnvironment();
  SharedPreferencesRemoteDiagnosticsRepository? remoteDiagnostics;
  var remoteDiagnosticsEnabled = false;
  if (sentryConfiguration.enabled) {
    remoteDiagnostics = SharedPreferencesRemoteDiagnosticsRepository();
    try {
      remoteDiagnosticsEnabled = await remoteDiagnostics.getEnabled().timeout(
        const Duration(seconds: 10),
      );
    } on Object catch (error) {
      // 读取失败时本次启动关闭诊断，避免覆盖用户已有的退出选择。
      debugPrint('远程诊断偏好读取失败：$error');
      remoteDiagnostics = null;
    }
  }
  final themeMode = ValueNotifier(AppThemeMode.system);
  final languageMode = ValueNotifier(AppLanguageMode.system);
  await SentryBootstrap.run(
    configuration: sentryConfiguration,
    userEnabled: remoteDiagnosticsEnabled,
    app: Application(
      themeMode: themeMode,
      languageMode: languageMode,
      home: MeetTraceBootstrap(
        themeMode: themeMode,
        languageMode: languageMode,
      ),
      navigatorObservers: sentryConfiguration.enabled
          ? createSentryNavigatorObservers()
          : const [],
    ),
    beforeRunApp: () async {
      if (const bool.fromEnvironment('MEETTRACE_REQUIRE_NATIVE_RUNTIME')) {
        final runtime = sherpaOnnxRuntimeInitializer.initialize();
        if (!runtime.isReady) {
          throw StateError('sherpa/ONNX 原生运行时加载失败');
        }
      }
      await initializeDateFormatting();
      await enableAppEdgeToEdge();
    },
    appStartedAt: appStartedAt,
  );
}
