import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';
import 'package:patrol/patrol.dart';

import 'common/test_app.dart';

void main() {
  sherpaOnnxRuntimeInitializer.initialize();

  testApp(
    '真实完成首次初始化、录音并进入会议详情',
    ($, modules, system, apiClients) async {
      await modules.meetings.openRecordingConditions();
      await modules.meetings.requestMicrophonePermission();
      await system.grantPermissionWhenInUse();
      await modules.meetings.startMeeting();
      await system.grantPermissionWhenInUseIfRequested();
      await modules.meetings.endAndSaveMeeting();
      await modules.meetings.expectDetailVisible();
    },
    app: const Application(home: MeetTraceBootstrap()),
    config: const PatrolTesterConfig(
      existsTimeout: Duration(minutes: 15),
      printLogs: true,
      visibleTimeout: Duration(minutes: 15),
    ),
    settle: false,
    tags: const ['android', 'golden'],
  );
}
