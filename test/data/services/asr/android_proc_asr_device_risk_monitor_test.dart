import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/android_proc_asr_device_risk_monitor.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';

void main() {
  test('从 procfs 内存和 thermal zone 生成支持设备快照', () async {
    final monitor = AndroidProcAsrDeviceRiskMonitor(
      readText: (path) async => switch (path) {
        '/proc/meminfo' =>
          'MemTotal:        8388608 kB\n'
              'MemAvailable:    2097152 kB\n',
        '/thermal/0' => '42000',
        _ => throw StateError(path),
      },
      listThermalPaths: () async => ['/thermal/0'],
    );

    final state = await monitor.inspect();

    expect(state.support, AsrDeviceSupport.supported);
    expect(state.memoryPressure, AsrMemoryPressure.normal);
    expect(state.thermalState, AsrThermalState.nominal);
    expect(state.estimatedAvailableBytes, 2 * 1024 * 1024 * 1024);
    expect(state.processRssBytes, greaterThan(0));
  });

  test('低内存和高温会阻止高级推理', () async {
    final monitor = AndroidProcAsrDeviceRiskMonitor(
      readText: (path) async => switch (path) {
        '/proc/meminfo' =>
          'MemTotal:        3145728 kB\n'
              'MemAvailable:     262144 kB\n',
        '/thermal/0' => '81000',
        _ => throw StateError(path),
      },
      listThermalPaths: () async => ['/thermal/0'],
    );

    final state = await monitor.inspect();

    expect(state.support, AsrDeviceSupport.unsupported);
    expect(state.memoryPressure, AsrMemoryPressure.critical);
    expect(state.thermalState, AsrThermalState.critical);
    expect(state.blocksInference, isTrue);
  });

  test('平台节点不可读时保守返回 constrained 和 unknown', () async {
    final monitor = AndroidProcAsrDeviceRiskMonitor(
      readText: (_) async => throw const FileSystemException('denied'),
      listThermalPaths: () async => throw const FileSystemException('denied'),
    );

    final state = await monitor.inspect();

    expect(state.support, AsrDeviceSupport.constrained);
    expect(state.memoryPressure, AsrMemoryPressure.unknown);
    expect(state.thermalState, AsrThermalState.unknown);
    expect(state.blocksInference, isFalse);
  });
}
