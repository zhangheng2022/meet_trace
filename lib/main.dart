import 'package:flutter/foundation.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/data/services/monitoring/sentry_bootstrap.dart';
import 'package:meettrace/domain/models/app_theme.dart';
import 'package:meettrace/domain/models/app_language.dart';
import 'package:meettrace/theme/system_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  final sentryConfiguration = SentryRuntimeConfiguration.fromEnvironment();
  final themeMode = ValueNotifier(AppThemeMode.system);
  final languageMode = ValueNotifier(AppLanguageMode.system);
  await SentryBootstrap.run(
    configuration: sentryConfiguration,
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
      await initializeDateFormatting();
      await enableAppEdgeToEdge();
    },
  );
}
