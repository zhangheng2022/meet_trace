import '../models/asr_model_registry.dart';
import '../models/meeting_readiness.dart';
import '../models/model_installation.dart';
import '../models/workflow_states.dart';
import '../ports/repositories.dart';

final class RecordingDeviceReadiness {
  const RecordingDeviceReadiness({
    required this.microphonePermissionGranted,
    required this.freeBytes,
  });

  final bool microphonePermissionGranted;
  final int freeBytes;
}

abstract interface class RecordingDeviceReadinessProbe {
  Future<RecordingDeviceReadiness> check({
    required bool requestMicrophonePermission,
  });
}

abstract interface class MeetingReadinessChecker {
  Future<MeetingReadiness> check({bool requestMicrophonePermission = false});
}

final class CheckMeetingReadinessUseCase implements MeetingReadinessChecker {
  CheckMeetingReadinessUseCase({
    required this.device,
    required this.preferences,
    required this.installations,
    AsrModelRegistry? registry,
  }) : registry = registry ?? AsrModelRegistry.alpha;

  final RecordingDeviceReadinessProbe device;
  final ModelPreferenceRepository preferences;
  final ActiveModelInstallationRepository installations;
  final AsrModelRegistry registry;

  @override
  Future<MeetingReadiness> check({
    bool requestMicrophonePermission = false,
  }) async {
    final initial = await Future.wait<Object>([
      device.check(requestMicrophonePermission: requestMicrophonePermission),
      preferences.getDefaultModelId(),
    ]);
    final deviceReadiness = initial[0] as RecordingDeviceReadiness;
    final defaultModelId = initial[1] as String;
    final descriptor = registry.requireById(defaultModelId);
    final modelState = await Future.wait<Object?>([
      installations.get(
        modelId: descriptor.modelId,
        version: descriptor.version,
      ),
      installations.getActiveVersion(descriptor.modelId),
    ]);
    final installation = modelState[0] as ModelInstallation?;
    final activeVersion = modelState[1] as String?;
    final modelAvailable =
        installation?.state == ModelInstallationState.installed &&
        installation?.verifiedAt != null &&
        activeVersion == descriptor.version;

    return MeetingReadiness(
      microphonePermissionGranted: deviceReadiness.microphonePermissionGranted,
      freeBytes: deviceReadiness.freeBytes,
      defaultModelId: descriptor.modelId,
      defaultModelVersion: descriptor.version,
      defaultModelName: descriptor.displayName,
      defaultModelAvailable: modelAvailable,
    );
  }
}
