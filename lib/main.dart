import 'package:flutter/widgets.dart';
import 'package:meetily_ai/app/application.dart';
import 'package:meetily_ai/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  sherpaOnnxRuntimeInitializer.initialize();
  runApp(const Application());
}
