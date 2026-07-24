import '../../domain/models/asr_model.dart';
import '../../domain/models/model_installation.dart';
import '../../domain/models/workflow_states.dart';

enum AsrModelUiStatus {
  notInstalled,
  checking,
  downloading,
  paused,
  verifying,
  installed,
  updateAvailable,
  deleting,
  failed,
  insufficientStorage,
}

final class AsrModelOption {
  const AsrModelOption({
    required this.descriptor,
    required this.status,
    this.lastErrorCode,
  });

  factory AsrModelOption.fromInstallation({
    required AsrModelDescriptor descriptor,
    required ModelInstallation? installation,
  }) {
    final state = installation?.state;
    final status = switch (state) {
      null ||
      ModelInstallationState.notInstalled => AsrModelUiStatus.notInstalled,
      ModelInstallationState.checking => AsrModelUiStatus.checking,
      ModelInstallationState.downloading => AsrModelUiStatus.downloading,
      ModelInstallationState.paused => AsrModelUiStatus.paused,
      ModelInstallationState.verifying => AsrModelUiStatus.verifying,
      ModelInstallationState.installed => AsrModelUiStatus.installed,
      ModelInstallationState.updateAvailable =>
        AsrModelUiStatus.updateAvailable,
      ModelInstallationState.deleting => AsrModelUiStatus.deleting,
      ModelInstallationState.failed
          when installation?.lastErrorCode == 'model.storage.insufficient' =>
        AsrModelUiStatus.insufficientStorage,
      ModelInstallationState.failed => AsrModelUiStatus.failed,
    };
    return AsrModelOption(
      descriptor: descriptor,
      status: status,
      lastErrorCode: installation?.lastErrorCode,
    );
  }

  final AsrModelDescriptor descriptor;
  final AsrModelUiStatus status;
  final String? lastErrorCode;

  bool get isInstalled => status == AsrModelUiStatus.installed;

  String get statusLabel => switch (status) {
    AsrModelUiStatus.notInstalled => '未下载',
    AsrModelUiStatus.checking => '检查中',
    AsrModelUiStatus.downloading => '下载中',
    AsrModelUiStatus.paused => '已暂停',
    AsrModelUiStatus.verifying => '校验中',
    AsrModelUiStatus.installed => '已安装',
    AsrModelUiStatus.updateAvailable => '可更新',
    AsrModelUiStatus.deleting => '删除中',
    AsrModelUiStatus.failed => '下载失败',
    AsrModelUiStatus.insufficientStorage => '空间不足',
  };

  String get positioningLabel => switch (descriptor.tier) {
    AsrModelTier.standard => '默认、低功耗，适合普通话与英语',
    AsrModelTier.advanced => '准确率优先，资源占用较高',
  };

  String? get resourceLabel => switch (descriptor.tier) {
    AsrModelTier.standard => null,
    AsrModelTier.advanced => '约 941 MB · 至少需要 2 GB 空间 · 建议使用 Wi-Fi',
  };
}

final class AdvancedModelActions {
  const AdvancedModelActions({
    this.download,
    this.cancel,
    this.retry,
    this.delete,
  });

  final Future<void> Function()? download;
  final void Function()? cancel;
  final Future<void> Function()? retry;
  final Future<void> Function()? delete;
}
