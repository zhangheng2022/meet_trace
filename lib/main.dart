import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';
import 'package:meettrace/data/services/monitoring/sentry_bootstrap.dart';
import 'package:meettrace/theme/system_ui.dart';

Future<void> main() async {
  final sentryConfiguration = SentryRuntimeConfiguration.fromEnvironment();
  await SentryBootstrap.run(
    configuration: sentryConfiguration,
    app: Application(
      home: const MeetTraceBootstrap(),
      navigatorObservers: sentryConfiguration.enabled
          ? createSentryNavigatorObservers()
          : const [],
    ),
    beforeRunApp: () async {
      await enableAppEdgeToEdge();
      sherpaOnnxRuntimeInitializer.initialize();
    },
  );
}
