import '../storage/device_free_space_service.dart';
import 'recording_ports.dart';

final class DeviceRecordingStorageCapacityProvider
    implements RecordingStorageCapacityProvider {
  const DeviceRecordingStorageCapacityProvider({
    this.freeSpace = const DeviceFreeSpaceService(),
  });

  final DeviceFreeSpaceService freeSpace;

  @override
  Future<int> getFreeBytes() => freeSpace.getFreeBytes();
}
