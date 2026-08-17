import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/record_input_device_catalog.dart';
import 'package:meettrace/domain/models/recording_input.dart';
import 'package:record/record.dart';

void main() {
  test('把 record 输入设备映射为纯 Domain 身份并过滤空 ID', () async {
    final catalog = RecordInputDeviceCatalog(
      readDevices: () async => const [
        InputDevice(id: 'mic-1', label: 'USB 麦克风'),
        InputDevice(id: '', label: '无效设备'),
        InputDevice(id: 'mic-2', label: ''),
      ],
    );

    expect(await catalog.listAvailable(), const [
      RecordingInputDevice(id: 'mic-1', label: 'USB 麦克风'),
      RecordingInputDevice(id: 'mic-2', label: '未命名麦克风'),
    ]);
  });
}
