import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/ports/asr_engine.dart';

const _supportedMemoryBytes = 6 * 1024 * 1024 * 1024;
const _constrainedMemoryBytes = 4 * 1024 * 1024 * 1024;
const _memoryWarningBytes = 1024 * 1024 * 1024;
const _memoryCriticalBytes = 512 * 1024 * 1024;

typedef AsrRiskTextReader = Future<String> Function(String path);
typedef AsrThermalPathLister = Future<List<String>> Function();

/// 通过 Android 可读的 procfs/sysfs 提供保守设备风险快照。
///
/// 无法读取的维度保持 unknown；不会通过私有原生桥接猜测平台状态。
final class AndroidProcAsrDeviceRiskMonitor implements AsrDeviceRiskMonitor {
  AndroidProcAsrDeviceRiskMonitor({
    AsrRiskTextReader? readText,
    AsrThermalPathLister? listThermalPaths,
    String thermalRootPath = '/sys/class/thermal',
    this.pollInterval = const Duration(seconds: 5),
  }) : _readText = readText ?? _readFile,
       _listThermalPaths =
           listThermalPaths ?? (() => _thermalPaths(thermalRootPath)) {
    if (pollInterval <= Duration.zero) {
      throw ArgumentError.value(pollInterval, 'pollInterval', '必须大于零');
    }
  }

  final AsrRiskTextReader _readText;
  final AsrThermalPathLister _listThermalPaths;
  final Duration pollInterval;

  @override
  Stream<AsrDeviceRiskState> get changes =>
      Stream<void>.periodic(pollInterval).asyncMap((_) => inspect());

  @override
  Future<AsrDeviceRiskState> inspect() async {
    final memory = await _memorySnapshot();
    return AsrDeviceRiskState(
      support: _deviceSupport(memory.totalBytes),
      memoryPressure: _memoryPressure(memory.availableBytes),
      thermalState: await _thermalState(),
      processRssBytes: ProcessInfo.currentRss,
      estimatedAvailableBytes: memory.availableBytes,
    );
  }

  Future<({int? totalBytes, int? availableBytes})> _memorySnapshot() async {
    try {
      final values = _parseMemInfo(await _readText('/proc/meminfo'));
      return (
        totalBytes: values['MemTotal'],
        availableBytes: values['MemAvailable'],
      );
    } on Object {
      return (totalBytes: null, availableBytes: null);
    }
  }

  Future<AsrThermalState> _thermalState() async {
    try {
      double? maximumCelsius;
      for (final path in await _listThermalPaths()) {
        try {
          final raw = double.tryParse((await _readText(path)).trim());
          if (raw == null) {
            continue;
          }
          final celsius = raw.abs() >= 1000 ? raw / 1000 : raw;
          if (celsius < -20 || celsius > 150) {
            continue;
          }
          if (maximumCelsius == null || celsius > maximumCelsius) {
            maximumCelsius = celsius;
          }
        } on Object {
          // 单个 thermal zone 不可读时继续检查其他公开节点。
        }
      }
      return switch (maximumCelsius) {
        null => AsrThermalState.unknown,
        >= 80 => AsrThermalState.critical,
        >= 65 => AsrThermalState.serious,
        >= 50 => AsrThermalState.fair,
        _ => AsrThermalState.nominal,
      };
    } on Object {
      return AsrThermalState.unknown;
    }
  }
}

Map<String, int> _parseMemInfo(String source) {
  final values = <String, int>{};
  for (final line in source.split('\n')) {
    final match = RegExp(r'^([A-Za-z_()]+):\s+(\d+)\s+kB$')
        .firstMatch(line.trim());
    if (match != null) {
      values[match.group(1)!] = int.parse(match.group(2)!) * 1024;
    }
  }
  return values;
}

AsrDeviceSupport _deviceSupport(int? totalBytes) {
  if (totalBytes == null) {
    return AsrDeviceSupport.constrained;
  }
  if (totalBytes >= _supportedMemoryBytes) {
    return AsrDeviceSupport.supported;
  }
  if (totalBytes >= _constrainedMemoryBytes) {
    return AsrDeviceSupport.constrained;
  }
  return AsrDeviceSupport.unsupported;
}

AsrMemoryPressure _memoryPressure(int? availableBytes) {
  if (availableBytes == null) {
    return AsrMemoryPressure.unknown;
  }
  if (availableBytes < _memoryCriticalBytes) {
    return AsrMemoryPressure.critical;
  }
  if (availableBytes < _memoryWarningBytes) {
    return AsrMemoryPressure.warning;
  }
  return AsrMemoryPressure.normal;
}

Future<String> _readFile(String path) => File(path).readAsString();

Future<List<String>> _thermalPaths(String rootPath) async {
  final root = Directory(rootPath);
  if (!await root.exists()) {
    return const [];
  }
  final paths = <String>[];
  await for (final entity in root.list(followLinks: false)) {
    if (p.basename(entity.path).startsWith('thermal_zone') &&
        await FileSystemEntity.type(entity.path, followLinks: true) ==
            FileSystemEntityType.directory) {
      paths.add('${entity.path}${Platform.pathSeparator}temp');
    }
  }
  return paths;
}
