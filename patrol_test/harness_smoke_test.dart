import 'common/test_app.dart';

void main() {
  testApp('Patrol 在 Android 真机完成 Flutter 与原生往返', (
    $,
    modules,
    system,
    apiClients,
  ) async {
    await modules.harness.activate();
    await system.leaveAndReturnToApp();
    await modules.harness.expectActivated();
  }, tags: const ['android', 'smoke']);
}
