import 'dart:async';
import 'dart:io';

import 'android_proc_asr_device_risk_monitor.dart';
import 'asr_engine.dart';

enum AsrRiskPlatform { android, ios, windows }

AsrDeviceRiskMonitor createPlatformAsrDeviceRiskMonitor({
  AsrRiskPlatform? platform,
}) {
  final resolved = platform ?? _currentPlatform();
  return switch (resolved) {
    AsrRiskPlatform.android => AndroidProcAsrDeviceRiskMonitor(),
    AsrRiskPlatform.ios ||
    AsrRiskPlatform.windows => PortableAsrDeviceRiskMonitor(),
  };
}

AsrRiskPlatform _currentPlatform() {
  if (Platform.isAndroid) {
    return AsrRiskPlatform.android;
  }
  if (Platform.isIOS) {
    return AsrRiskPlatform.ios;
  }
  if (Platform.isWindows) {
    return AsrRiskPlatform.windows;
  }
  throw UnsupportedError('当前平台不支持会迹运行');
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
