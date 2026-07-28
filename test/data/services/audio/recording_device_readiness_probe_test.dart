import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/recording_device_readiness_probe.dart';
import 'package:meettrace/data/services/audio/recording_ports.dart';

void main() {
  test('设备预检并行读取麦克风权限和空间并释放录音器', () async {
    final capture = _Capture();
    final probe = DeviceRecordingReadinessProbe(
      captureFactory: () => capture,
      storageCapacity: const _Capacity(256),
    );

    final result = await probe.check(requestMicrophonePermission: false);

    expect(result.microphonePermissionGranted, isTrue);
    expect(result.freeBytes, 256);
    expect(capture.permissionRequests, [false]);
    expect(capture.disposeCalls, 1);
  });
}

final class _Capture implements PcmAudioCapture {
  final List<bool> permissionRequests = [];
  int disposeCalls = 0;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    permissionRequests.add(request);
    return true;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<Stream<Uint8List>> start() async => const Stream.empty();

  @override
  Future<void> stop() async {}
}

final class _Capacity implements RecordingStorageCapacityProvider {
  const _Capacity(this.freeBytes);

  final int freeBytes;

  @override
  Future<int> getFreeBytes() async => freeBytes;
}
