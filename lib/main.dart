import 'package:flutter/widgets.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/theme/system_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await enableAppEdgeToEdge();
  runApp(const Application(home: MeetTraceBootstrap()));
}
