import 'package:storage_space/storage_space.dart';

import 'recording_ports.dart';
import 'reliable_recording_service.dart';

final class DeviceRecordingStorageCapacityProvider
    implements RecordingStorageCapacityProvider {
  const DeviceRecordingStorageCapacityProvider();

  @override
  Future<int> getFreeBytes() async {
    final storage = await getStorageSpace(
      lowOnSpaceThreshold: minimumRecordingFreeBytes,
      fractionDigits: 1,
    );
    return storage.free;
  }
}
