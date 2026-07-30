import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meettrace/data/services/asr/rust_bridge/generated/api/health.dart';
import 'package:meettrace/data/services/asr/rust_bridge/generated/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(RustLib.init);
  tearDownAll(RustLib.dispose);

  testWidgets('loads the Rust mobile library through flutter_rust_bridge', (
    tester,
  ) async {
    final info = await rustRuntimeInfo();

    expect(info.bridgeVersion, '2.12.0');
    expect(info.whisperRsVersion, '0.16.0');
    expect(info.rustVersion, '1.88.0');
  });
}
