import 'package:flutter/widgets.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';
import 'package:meettrace/theme/system_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await enableAppEdgeToEdge();
  sherpaOnnxRuntimeInitializer.initialize();
  runApp(const Application(home: MeetTraceBootstrap()));
}
