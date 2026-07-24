import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/audio/device_recording_storage_capacity.dart';
import 'package:meetily_ai/data/services/models/platform_download_preflight_providers.dart';
import 'package:meetily_ai/data/services/storage/device_free_space_service.dart';

void main() {
  group('DeviceFreeSpaceService', () {
    test('将插件返回的 MiB 保守换算为字节', () async {
      final service = DeviceFreeSpaceService(reader: () async => 2048.5);

      expect(await service.getFreeBytes(), 2148007936);
    });

    test('拒绝平台返回空值或无效数值', () async {
      for (final invalidValue in <double?>[
        null,
        -1,
        double.nan,
        double.infinity,
      ]) {
        final service = DeviceFreeSpaceService(
          reader: () async => invalidValue,
        );

        await expectLater(service.getFreeBytes(), throwsA(isA<StateError>()));
      }
    });

    test('下载与录音容量 Provider 共用统一字节结果', () async {
      final service = DeviceFreeSpaceService(reader: () async => 3072);

      expect(
        await DeviceStorageCapacityProvider(freeSpace: service).getFreeBytes(),
        3221225472,
      );
      expect(
        await DeviceRecordingStorageCapacityProvider(
          freeSpace: service,
        ).getFreeBytes(),
        3221225472,
      );
    });
  });
}
