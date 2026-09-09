import '../models/asr_model_registry.dart';
import '../models/meeting_readiness.dart';
import '../models/model_installation.dart';
import '../models/workflow_states.dart';
import '../models/transcription_profile.dart';
import '../ports/repositories.dart';
import '../ports/transcription_profiles.dart';

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

abstract interface class SelectedMeetingReadinessChecker
    implements MeetingReadinessChecker {
  Future<MeetingReadiness> checkSelection(
    TranscriptionProfile profile, {
    bool requestMicrophonePermission = false,
  });
}

final class CheckMeetingReadinessUseCase
    implements SelectedMeetingReadinessChecker {
  CheckMeetingReadinessUseCase({
    required this.device,
    required this.preferences,
    required this.installations,
    this.profiles,
    AsrModelRegistry? registry,
  }) : registry = registry ?? AsrModelRegistry.alpha;

  final RecordingDeviceReadinessProbe device;
  final ModelPreferenceRepository preferences;
  final ActiveModelInstallationRepository installations;
  final AsrModelRegistry registry;
  final TranscriptionProfileRepository? profiles;

  @override
  Future<MeetingReadiness> checkSelection(
    TranscriptionProfile profile, {
    bool requestMicrophonePermission = false,
  }) async {
    final readiness = await device.check(
      requestMicrophonePermission: requestMicrophonePermission,
    );
    var available = true;
    if (profile.isLocal) {
      final descriptor = registry.requireById(profile.modelId);
      final installation = await installations.get(
        modelId: profile.modelId,
        version: profile.identityVersion,
      );
      available =
          descriptor.version == profile.identityVersion &&
          installation?.state == ModelInstallationState.installed &&
          installation?.verifiedAt != null &&
          await installations.getActiveVersion(profile.modelId) ==
              profile.identityVersion;
    }
    // 网络和认证只决定转录可用性，不作为录音启动条件。
    return MeetingReadiness(
      microphonePermissionGranted: readiness.microphonePermissionGranted,
      freeBytes: readiness.freeBytes,
      defaultModelId: profile.modelId,
      defaultModelVersion: profile.identityVersion,
      defaultModelName: profile.name,
      defaultModelAvailable: available,
      transcriptionProfile: profile,
    );
  }

  @override
  Future<MeetingReadiness> check({
    bool requestMicrophonePermission = false,
  }) async {
    if (profiles case final profiles?) {
      final id = await profiles.getDefaultProfileId();
      final profile = await profiles.getById(id);
      if (profile == null) throw StateError('默认转录配置不存在');
      return checkSelection(
        profile,
        requestMicrophonePermission: requestMicrophonePermission,
      );
    }
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
