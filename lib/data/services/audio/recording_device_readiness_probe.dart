import '../../../domain/use_cases/check_meeting_readiness.dart';
import 'recording_ports.dart';

typedef PcmAudioCaptureFactory = PcmAudioCapture Function();

final class DeviceRecordingReadinessProbe
    implements RecordingDeviceReadinessProbe {
  const DeviceRecordingReadinessProbe({
    required this.captureFactory,
    required this.storageCapacity,
  });

  final PcmAudioCaptureFactory captureFactory;
  final RecordingStorageCapacityProvider storageCapacity;

  @override
  Future<RecordingDeviceReadiness> check({
    required bool requestMicrophonePermission,
  }) async {
    final capture = captureFactory();
    try {
      final values = await Future.wait<Object>([
        capture.hasPermission(request: requestMicrophonePermission),
        storageCapacity.getFreeBytes(),
      ]);
      return RecordingDeviceReadiness(
        microphonePermissionGranted: values[0] as bool,
        freeBytes: values[1] as int,
      );
    } finally {
      await capture.dispose();
    }
  }
}
