import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/android_proc_asr_device_risk_monitor.dart';
import 'package:meettrace/data/services/asr/asr_engine.dart';
import 'package:meettrace/data/services/asr/platform_asr_device_risk_monitor.dart';

void main() {
  group('createPlatformAsrDeviceRiskMonitor', () {
    test('Android 使用 procfs/sysfs 风险监测', () {
      final monitor = createPlatformAsrDeviceRiskMonitor(
        operatingSystem: MobileOperatingSystem.android,
      );

      expect(monitor, isA<AndroidProcAsrDeviceRiskMonitor>());
    });

    test('iOS 使用保守的可移植风险快照', () async {
      final monitor = createPlatformAsrDeviceRiskMonitor(
        operatingSystem: MobileOperatingSystem.ios,
      );

      expect(monitor, isA<PortableAsrDeviceRiskMonitor>());
      final state = await monitor.inspect();
      expect(state.support, AsrDeviceSupport.constrained);
      expect(state.memoryPressure, AsrMemoryPressure.unknown);
      expect(state.thermalState, AsrThermalState.unknown);
      expect(state.blocksInference, isFalse);
      expect(state.hasWarning, isTrue);
    });
  });

  test('Portable monitor 保留进程 RSS 且拒绝无效轮询周期', () async {
    final monitor = PortableAsrDeviceRiskMonitor(processRssReader: () => 42);

    expect((await monitor.inspect()).processRssBytes, 42);
    expect(
      () => PortableAsrDeviceRiskMonitor(pollInterval: Duration.zero),
      throwsArgumentError,
    );
  });
}
