/// 录音输入设备的稳定业务身份，不暴露任何平台插件类型。
final class RecordingInputDevice {
  const RecordingInputDevice({required this.id, required this.label})
    : assert(id != ''),
      assert(label != '');

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is RecordingInputDevice && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// 全局输入偏好。“系统默认”保持为延迟解析的明确选择。
final class RecordingInputPreference {
  const RecordingInputPreference.systemDefault()
    : deviceId = null,
      lastKnownLabel = null;

  const RecordingInputPreference.device({
    required String this.deviceId,
    required String this.lastKnownLabel,
  }) : assert(deviceId != ''),
       assert(lastKnownLabel != '');

  final String? deviceId;
  final String? lastKnownLabel;

  bool get usesSystemDefault => deviceId == null;

  @override
  bool operator ==(Object other) =>
      other is RecordingInputPreference &&
      other.deviceId == deviceId &&
      other.lastKnownLabel == lastKnownLabel;

  @override
  int get hashCode => Object.hash(deviceId, lastKnownLabel);
}

/// 开始会议时冻结的输入选择。
///
/// 显式设备会保存当次枚举得到的稳定 ID 与名称；系统默认输入由平台在打开
/// 采集流时解析，并由该采集流持有，不会在会议中重新读取全局偏好。
final class LockedRecordingInput {
  const LockedRecordingInput.systemDefault() : this._(null);

  const LockedRecordingInput.device(RecordingInputDevice device)
    : this._(device);

  const LockedRecordingInput._(this.device);

  final RecordingInputDevice? device;

  bool get usesSystemDefault => device == null;
  String get displayLabel => device?.label ?? '系统默认麦克风';
}

enum RecordingInputRecoveryAction { switchToSystemDefault, interrupt }

/// 设备中断后的单次回退状态；第二次中断必须真实进入 interrupted。
final class RecordingInputRecoveryState {
  const RecordingInputRecoveryState({this.systemDefaultAttempted = false});

  final bool systemDefaultAttempted;
}

final class RecordingInputRecoveryDecision {
  const RecordingInputRecoveryDecision({
    required this.action,
    required this.nextState,
  });

  final RecordingInputRecoveryAction action;
  final RecordingInputRecoveryState nextState;
}
