import 'package:record/record.dart' as record;

import '../../../domain/models/recording_input.dart';
import '../../../domain/ports/recording_input.dart';

typedef RecordInputDeviceReader = Future<List<record.InputDevice>> Function();

/// 只通过官方 record 插件公开 API 枚举输入设备。
final class RecordInputDeviceCatalog implements RecordingInputDeviceCatalog {
  RecordInputDeviceCatalog({RecordInputDeviceReader? readDevices})
    : _readDevices = readDevices ?? _readPlatformDevices;

  final RecordInputDeviceReader _readDevices;

  @override
  Future<List<RecordingInputDevice>> listAvailable() async {
    final devices = await _readDevices();
    return devices
        .where((device) => device.id.trim().isNotEmpty)
        .map(
          (device) => RecordingInputDevice(
            id: device.id,
            label: device.label.trim().isEmpty ? '未命名麦克风' : device.label,
          ),
        )
        .toList(growable: false);
  }

  static Future<List<record.InputDevice>> _readPlatformDevices() async {
    final recorder = record.AudioRecorder();
    try {
      return await recorder.listInputDevices();
    } finally {
      await recorder.dispose();
    }
  }
}
