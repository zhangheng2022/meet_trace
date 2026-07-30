import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/rust_bridge/generated/api/health.dart';
import 'package:meettrace/data/services/asr/rust_bridge/generated/api/probe.dart';
import 'package:meettrace/data/services/asr/rust_bridge/generated/frb_generated.dart';

void main() {
  setUpAll(() {
    RustLib.initMock(api: _FakeRustLibApi());
  });

  tearDownAll(RustLib.dispose);

  test('Rust runtime exposes pinned component versions', () async {
    final info = await rustRuntimeInfo();

    expect(info.bridgeVersion, '2.12.0');
    expect(info.whisperRsVersion, '0.16.0');
    expect(info.rustVersion, startsWith('1.88.0'));
  });
}

class _FakeRustLibApi extends RustLibApi {
  @override
  Future<void> crateApiHealthInitApp() async {}

  @override
  Future<WhisperProbeResult> crateApiProbeProbeWhisperModel({
    required String modelPath,
    required List<double> pcmF32,
    String? language,
  }) {
    throw UnsupportedError('The runtime contract test does not invoke ASR.');
  }

  @override
  Future<RustRuntimeInfo> crateApiHealthRustRuntimeInfo() async {
    return const RustRuntimeInfo(
      bridgeVersion: '2.12.0',
      whisperRsVersion: '0.16.0',
      rustVersion: '1.88.0',
    );
  }
}
