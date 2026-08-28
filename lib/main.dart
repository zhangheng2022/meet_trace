import 'package:flutter/foundation.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/data/services/monitoring/sentry_bootstrap.dart';
import 'package:meettrace/domain/models/app_theme.dart';
import 'package:meettrace/theme/system_ui.dart';

Future<void> main() async {
  final sentryConfiguration = SentryRuntimeConfiguration.fromEnvironment();
  final themeMode = ValueNotifier(AppThemeMode.system);
  await SentryBootstrap.run(
    configuration: sentryConfiguration,
    app: Application(
      themeMode: themeMode,
      home: MeetTraceBootstrap(themeMode: themeMode),
      navigatorObservers: sentryConfiguration.enabled
          ? createSentryNavigatorObservers()
          : const [],
    ),
    beforeRunApp: () async {
      await enableAppEdgeToEdge();
    },
  );
}
