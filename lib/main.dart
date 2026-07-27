import 'package:flutter/widgets.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  sherpaOnnxRuntimeInitializer.initialize();
  runApp(const Application(home: MeetTraceBootstrap()));
}
