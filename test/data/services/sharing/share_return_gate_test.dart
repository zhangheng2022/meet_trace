import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/sharing/share_return_gate.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('Android 分享成功后等待离开并重新进入前台', () async {
    final gate = FlutterShareReturnGate(waitForLifecycle: true)..start();
    addTearDown(gate.dispose);
    var returned = false;
    final waiting = gate.waitUntilReturned().then((_) => returned = true);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(returned, false);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await waiting;
    expect(returned, true);
  });

  test('不产生插件缓存的平台不等待生命周期', () async {
    final gate = FlutterShareReturnGate(waitForLifecycle: false)..start();
    addTearDown(gate.dispose);

    await gate.waitUntilReturned();
  });
}
