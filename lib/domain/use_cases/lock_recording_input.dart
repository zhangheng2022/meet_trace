import '../models/recording_input.dart';
import '../ports/recording_input.dart';

final class RecordingInputUnavailableException implements Exception {
  const RecordingInputUnavailableException({
    required this.deviceId,
    required this.lastKnownLabel,
  });

  final String deviceId;
  final String lastKnownLabel;

  @override
  String toString() =>
      'RecordingInputUnavailableException($deviceId, $lastKnownLabel)';
}

/// 在会议创建边界读取一次全局偏好并冻结，不在录音中重新解析设置。
final class LockRecordingInputUseCase {
  const LockRecordingInputUseCase({
    required this.preferences,
    required this.devices,
  });

  final RecordingInputPreferenceRepository preferences;
  final RecordingInputDeviceCatalog devices;

  Future<LockedRecordingInput> execute() async {
    final preference = await preferences.getPreference();
    if (preference.usesSystemDefault) {
      return const LockedRecordingInput.systemDefault();
    }

    final available = await devices.listAvailable();
    for (final device in available) {
      if (device.id == preference.deviceId) {
        return LockedRecordingInput.device(device);
      }
    }
    throw RecordingInputUnavailableException(
      deviceId: preference.deviceId!,
      lastKnownLabel: preference.lastKnownLabel!,
    );
  }
}

/// 设备流结束后只允许一次当前系统默认输入回退。
final class PlanRecordingInputRecoveryUseCase {
  const PlanRecordingInputRecoveryUseCase();

  RecordingInputRecoveryDecision execute(RecordingInputRecoveryState state) {
    if (!state.systemDefaultAttempted) {
      return const RecordingInputRecoveryDecision(
        action: RecordingInputRecoveryAction.switchToSystemDefault,
        nextState: RecordingInputRecoveryState(systemDefaultAttempted: true),
      );
    }
    return RecordingInputRecoveryDecision(
      action: RecordingInputRecoveryAction.interrupt,
      nextState: state,
    );
  }
}
