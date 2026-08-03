import 'asr_model.dart';
import 'domain_exception.dart';
import 'workflow_states.dart';

final class ModelInstallation {
  ModelInstallation({
    required this.modelId,
    required this.version,
    required this.installationType,
    required this.state,
    this.installedPath,
    this.verifiedAt,
    required this.bytes,
    this.lastErrorCode,
  }) {
    if (modelId.trim().isEmpty || version.trim().isEmpty) {
      throw ArgumentError('modelId 和 version 不能为空');
    }
    if (bytes < 0) {
      throw ArgumentError.value(bytes, 'bytes', '不能为负数');
    }
    if (state == ModelInstallationState.installed &&
        (installedPath == null ||
            installedPath!.trim().isEmpty ||
            verifiedAt == null)) {
      throw ArgumentError('installed 状态必须包含安装路径和校验时间');
    }
  }

  final String modelId;
  final String version;
  final AsrInstallationType installationType;
  final ModelInstallationState state;
  final String? installedPath;
  final DateTime? verifiedAt;
  final int bytes;
  final String? lastErrorCode;

  ModelInstallation transitionTo(
    ModelInstallationState next, {
    String? installedPath,
    DateTime? verifiedAt,
    int? bytes,
    String? errorCode,
  }) {
    if (installationType == AsrInstallationType.bundled &&
        next == ModelInstallationState.deleting) {
      throw const DomainInvariantViolation('内置模型不能删除');
    }
    return ModelInstallation(
      modelId: modelId,
      version: version,
      installationType: installationType,
      state: state.transitionTo(next),
      installedPath: installedPath ?? this.installedPath,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      bytes: bytes ?? this.bytes,
      lastErrorCode: errorCode,
    );
  }
}
