import 'dart:async';
import 'dart:io';

import 'android_proc_asr_device_risk_monitor.dart';
import 'asr_engine.dart';

enum MobileOperatingSystem { android, ios }

AsrDeviceRiskMonitor createPlatformAsrDeviceRiskMonitor({
  MobileOperatingSystem? operatingSystem,
}) {
  final resolved = operatingSystem ?? _currentOperatingSystem();
  return switch (resolved) {
    MobileOperatingSystem.android => AndroidProcAsrDeviceRiskMonitor(),
    MobileOperatingSystem.ios => PortableAsrDeviceRiskMonitor(),
  };
}

MobileOperatingSystem _currentOperatingSystem() {
  if (Platform.isAndroid) {
    return MobileOperatingSystem.android;
  }
  if (Platform.isIOS) {
    return MobileOperatingSystem.ios;
  }
  throw UnsupportedError('会迹仅支持 Android 与 iOS');
}

/// iOS 的公开 Dart API 无法提供与 Android procfs 等价的整机内存和温控数据。
///
/// 在独立真机门槛闭环前，保守标记为 constrained，但不会仅因指标未知而阻止推理。
final class PortableAsrDeviceRiskMonitor implements AsrDeviceRiskMonitor {
  PortableAsrDeviceRiskMonitor({
    this.pollInterval = const Duration(seconds: 5),
    int Function()? processRssReader,
  }) : _processRssReader = processRssReader ?? _currentRss {
    if (pollInterval <= Duration.zero) {
      throw ArgumentError.value(pollInterval, 'pollInterval', '必须大于零');
    }
  }

  final Duration pollInterval;
  final int Function() _processRssReader;

  @override
  Stream<AsrDeviceRiskState> get changes =>
      Stream<void>.periodic(pollInterval).map((_) => _snapshot());

  @override
  Future<AsrDeviceRiskState> inspect() async => _snapshot();

  AsrDeviceRiskState _snapshot() => AsrDeviceRiskState(
    support: AsrDeviceSupport.constrained,
    memoryPressure: AsrMemoryPressure.unknown,
    thermalState: AsrThermalState.unknown,
    processRssBytes: _processRssReader(),
  );
}

int _currentRss() => ProcessInfo.currentRss;
