import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';
import 'package:patrol/patrol.dart';

import 'common/test_app.dart';

void main() {
  sherpaOnnxRuntimeInitializer.initialize();

  testApp(
    '拒绝麦克风权限后仍阻止创建会议并可再次授权恢复',
    ($, modules, system, apiClients) async {
      await modules.meetings.openRecordingConditions();
      await modules.meetings.requestMicrophonePermission();
      await system.denyPermission();

      await modules.meetings.startMeeting();
      await modules.meetings.openRecordingConditions();
      await modules.meetings.expectMicrophonePermissionGranted(false);
      await modules.meetings.requestMicrophonePermission();
      await system.grantPermissionWhenInUse();

      await modules.meetings.openRecordingConditions();
      await modules.meetings.expectMicrophonePermissionGranted(true);
    },
    app: const Application(home: MeetTraceBootstrap()),
    config: const PatrolTesterConfig(
      existsTimeout: Duration(minutes: 15),
      printLogs: true,
      visibleTimeout: Duration(minutes: 15),
    ),
    settle: false,
    tags: const ['android', 'permission', 'recovery'],
  );
}
