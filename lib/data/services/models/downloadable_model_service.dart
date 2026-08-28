import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/models/asr_model.dart';
import '../../../domain/models/model_installation.dart';
import '../../../domain/models/model_manifest.dart';
import '../../../domain/models/workflow_states.dart';
import '../../../domain/ports/repositories.dart';
import '../storage/app_file_layout.dart';
import 'model_file_verifier.dart';
import 'model_download_types.dart';
import 'runtime_artifact_install_transaction.dart';
import 'runtime_asset_installers.dart';

const minimumRuntimeInitializationFreeBytes = 1024 * 1024 * 1024;
const maximumRuntimeDownloadBytes = 300000000;

enum DownloadNetworkKind { offline, unmetered, metered, unknown }

final class DownloadableModelDeleteResult {
  const DownloadableModelDeleteResult({required this.deleted});

  final bool deleted;
}

final class ModelFileDownloadResult {
  const ModelFileDownloadResult({
    required this.finalBytes,
    required this.resumed,
  });

  final int finalBytes;
  final bool resumed;
}

final class DownloadableModelException implements Exception {
  const DownloadableModelException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'DownloadableModelException($code, $message)';
}

abstract interface class ModelStorageCapacityProvider {
  Future<int> getFreeBytes();
}

abstract interface class DownloadNetworkStatusProvider {
  Future<DownloadNetworkKind> getCurrentKind();
}

abstract interface class ModelFileDownloader {
  Future<ModelFileDownloadResult> download({
    required Uri source,
    required String destinationPath,
    required int resumeFrom,
    required int expectedBytes,
    required ModelDownloadCancellationToken cancellation,
    required void Function(int absoluteFileBytes) onProgress,
  });
}

final class DownloadableModelService implements RuntimeAsrModelInstaller {
  DownloadableModelService({
    required this.fileLayout,
    required this.installations,
    required this.leases,
    required this.capacity,
    required this.network,
    required this.downloader,
    required this.verifier,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final AppFileLayout fileLayout;
  final ActiveModelInstallationRepository installations;
  final ModelUsageLeaseRepository leases;
  final ModelStorageCapacityProvider capacity;
  final DownloadNetworkStatusProvider network;
  final ModelFileDownloader downloader;
  final ModelFileVerifier verifier;
  final DateTime Function() now;

  @override
  Future<DownloadableModelResult> download({
    required AsrModelDescriptor descriptor,
    required ModelManifestEntry manifest,
    bool allowMeteredNetwork = false,
    ModelDownloadCancellationToken? cancellation,
    DownloadableModelProgressCallback? onProgress,
    bool skipPreflight = false,
    bool forceDownload = false,
  }) async {
    _validateInputs(descriptor, manifest);
    final token = cancellation ?? ModelDownloadCancellationToken();
    final finalPath = fileLayout.modelVersionDirectory(
      descriptor.modelId,
      descriptor.version,
    );
    final tempPath = fileLayout.modelTempDirectory(
      descriptor.modelId,
      descriptor.version,
    );
    final current = await installations.get(
      modelId: descriptor.modelId,
      version: descriptor.version,
    );

    _notify(
      onProgress,
      DownloadableModelPhase.checking,
      0,
      manifest.requiredBytes,
    );
    if (!forceDownload) {
      final existingResult = await _adoptExistingIfValid(
        descriptor: descriptor,
        manifest: manifest,
        current: current,
        finalPath: finalPath,
        tempPath: tempPath,
        onProgress: onProgress,
      );
      if (existingResult != null) {
        return existingResult;
      }
    }

    var state = _retryableRecord(descriptor, current);
    try {
      if (state.state == ModelInstallationState.notInstalled ||
          state.state == ModelInstallationState.failed ||
          state.state == ModelInstallationState.updateAvailable) {
        state = state.transitionTo(ModelInstallationState.checking);
        await installations.save(state);
      }

      if (!skipPreflight) {
        await _validatePreflight(
          allowMeteredNetwork: allowMeteredNetwork,
          cancellation: token,
        );
      }

      state = state.transitionTo(ModelInstallationState.downloading);
      await installations.save(state);
      final installation = await _installArtifact(
        manifest: manifest,
        token: token,
        tempPath: tempPath,
        finalPath: finalPath,
        onProgress: onProgress,
        onVerifying: () async {
          state = state.transitionTo(ModelInstallationState.verifying);
          await installations.save(state);
          _notify(
            onProgress,
            DownloadableModelPhase.verifying,
            manifest.requiredBytes,
            manifest.requiredBytes,
          );
        },
        onCommitting: (verifiedBytes) async {
          _notify(
            onProgress,
            DownloadableModelPhase.committing,
            verifiedBytes,
            manifest.requiredBytes,
          );
        },
      );

      final installed = state.transitionTo(
        ModelInstallationState.installed,
        installedPath: finalPath,
        verifiedAt: now().toUtc(),
        bytes: installation.verifiedBytes,
      );
      await installations.saveInstalledAndActivate(installed);
      _notify(
        onProgress,
        DownloadableModelPhase.ready,
        installation.verifiedBytes,
        manifest.requiredBytes,
      );
      return DownloadableModelResult(
        installedPath: finalPath,
        alreadyInstalled: false,
        resumed: installation.resumed,
      );
    } catch (error, stackTrace) {
      final canceled =
          error is ModelDownloadCanceledException || token.isCanceled;
      final failure = canceled
          ? const DownloadableModelException(
              code: 'model.download.canceled',
              message: '模型下载已暂停，可稍后继续',
            )
          : error is DownloadableModelException
          ? error
          : DownloadableModelException(
              code: 'model.download.failed',
              message: '模型下载失败，可重试',
              cause: error,
            );
      try {
        final failedState = canceled
            ? _pausedRecord(state)
            : _failedRecord(state, failure.code);
        await installations.save(failedState);
      } on Object {
        // 文件与数据库恢复由下次重试重新校验并收敛。
      }
      Error.throwWithStackTrace(failure, stackTrace);
    }
  }

  Future<RuntimeArtifactInstallResult> _installArtifact({
    required ModelManifestEntry manifest,
    required ModelDownloadCancellationToken token,
    required String tempPath,
    required String finalPath,
    required DownloadableModelProgressCallback? onProgress,
    required Future<void> Function() onVerifying,
    required Future<void> Function(int verifiedBytes) onCommitting,
  }) async {
    try {
      return await RuntimeArtifactInstallTransaction(verifier: verifier)
          .install(
            manifest: manifest,
            tempPath: tempPath,
            finalPath: finalPath,
            tempRoot: fileLayout.modelTempRoot,
            finalRoot: fileLayout.modelsRoot,
            throwIfCanceled: token.throwIfCanceled,
            download:
                ({
                  required file,
                  required destinationPath,
                  required resumeFrom,
                  required onProgress,
                }) async {
                  final result = await downloader.download(
                    source: Uri.parse(file.url),
                    destinationPath: destinationPath,
                    resumeFrom: resumeFrom,
                    expectedBytes: file.bytes,
                    cancellation: token,
                    onProgress: onProgress,
                  );
                  return RuntimeArtifactDownloadOutcome(
                    finalBytes: result.finalBytes,
                    resumed: result.resumed,
                  );
                },
            onProgress: (completedBytes, totalBytes) => _notify(
              onProgress,
              DownloadableModelPhase.downloading,
              completedBytes,
              totalBytes,
            ),
            onVerifying: onVerifying,
            onCommitting: onCommitting,
          );
    } on RuntimeArtifactInstallException catch (error) {
      throw DownloadableModelException(
        code: switch (error.failure) {
          RuntimeArtifactInstallFailure.incomplete =>
            'model.download.incomplete',
          RuntimeArtifactInstallFailure.integrity => 'model.integrity',
          RuntimeArtifactInstallFailure.invalidPath => 'model.path.invalid',
          RuntimeArtifactInstallFailure.preparation => 'model.prepare.failed',
        },
        message: error.message,
        cause: error,
      );
    }
  }

  /// 启动路径同时校验固定文件集合、字节数和 SHA-256。
  @override
  Future<bool> isReadyFast({
    required AsrModelDescriptor descriptor,
    required ModelManifestEntry manifest,
  }) async {
    _validateInputs(descriptor, manifest);
    final installation = await installations.get(
      modelId: descriptor.modelId,
      version: descriptor.version,
    );
    if (installation?.state != ModelInstallationState.installed ||
        installation?.installedPath?.trim().isEmpty != false ||
        installation?.bytes != descriptor.requiredBytes ||
        await installations.getActiveVersion(descriptor.modelId) !=
            descriptor.version) {
      return false;
    }
    return (await verifier.verifyDirectory(
      directoryPath: installation!.installedPath!,
      manifest: manifest,
    )).isValid;
  }

  Future<DownloadableModelDeleteResult> delete({
    required AsrModelDescriptor descriptor,
    DownloadableModelProgressCallback? onProgress,
  }) async {
    if (descriptor.capabilities.contains('required-runtime')) {
      throw const DownloadableModelException(
        code: 'model.delete.requiredRuntime',
        message: '当前唯一转录模型不能删除，只能校验和修复',
      );
    }
    if (descriptor.installationType != AsrInstallationType.downloadable) {
      throw const DownloadableModelException(
        code: 'model.delete.bundled',
        message: '内置模型不能删除',
      );
    }
    final activeLeases = await leases.listActive(
      modelId: descriptor.modelId,
      version: descriptor.version,
      now: now().toUtc(),
    );
    if (activeLeases.isNotEmpty) {
      final owners = activeLeases
          .map((lease) => lease.ownerId)
          .toSet()
          .join(', ');
      throw DownloadableModelException(
        code: 'model.inUse',
        message: '模型正被活动任务使用：$owners，请结束任务后重试',
      );
    }

    final current = await installations.get(
      modelId: descriptor.modelId,
      version: descriptor.version,
    );
    final finalPath = fileLayout.modelVersionDirectory(
      descriptor.modelId,
      descriptor.version,
    );
    final tempPath = fileLayout.modelTempDirectory(
      descriptor.modelId,
      descriptor.version,
    );
    final rollbackPath = fileLayout.modelRollbackDirectory(
      descriptor.modelId,
      descriptor.version,
    );
    if (current == null &&
        !await Directory(finalPath).exists() &&
        !await Directory(tempPath).exists() &&
        !await Directory(rollbackPath).exists()) {
      return const DownloadableModelDeleteResult(deleted: false);
    }

    ModelInstallation? deleting;
    try {
      if (current != null) {
        deleting = current.state == ModelInstallationState.deleting
            ? current
            : current.transitionTo(ModelInstallationState.deleting);
        await installations.save(deleting);
      }
      _notify(
        onProgress,
        DownloadableModelPhase.deleting,
        0,
        descriptor.requiredBytes,
      );
      await _deleteDirectoryWithin(
        path: tempPath,
        allowedRoot: fileLayout.modelTempRoot,
      );
      await _deleteDirectoryWithin(
        path: finalPath,
        allowedRoot: fileLayout.modelsRoot,
      );
      await _deleteDirectoryWithin(
        path: rollbackPath,
        allowedRoot: fileLayout.modelRollbackRoot,
      );
      await installations.deleteAndDeactivate(
        modelId: descriptor.modelId,
        version: descriptor.version,
      );
      return const DownloadableModelDeleteResult(deleted: true);
    } catch (error, stackTrace) {
      if (deleting != null) {
        try {
          await installations.save(
            deleting.transitionTo(
              ModelInstallationState.failed,
              errorCode: 'model.delete.failed',
            ),
          );
        } on Object {
          // 保留原始删除错误。
        }
      }
      Error.throwWithStackTrace(
        DownloadableModelException(
          code: 'model.delete.failed',
          message: '模型删除失败，可重试',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Future<DownloadableModelResult?> _adoptExistingIfValid({
    required AsrModelDescriptor descriptor,
    required ModelManifestEntry manifest,
    required ModelInstallation? current,
    required String finalPath,
    required String tempPath,
    required DownloadableModelProgressCallback? onProgress,
  }) async {
    final directory = Directory(finalPath);
    if (!await directory.exists()) {
      return null;
    }
    final verification = await verifier.verifyDirectory(
      directoryPath: finalPath,
      manifest: manifest,
    );
    if (!verification.isValid) {
      return null;
    }
    final activeVersion = await installations.getActiveVersion(
      descriptor.modelId,
    );
    final alreadyInstalled =
        current?.state == ModelInstallationState.installed &&
        current?.installedPath == finalPath &&
        activeVersion == descriptor.version;
    if (!alreadyInstalled) {
      await installations.saveInstalledAndActivate(
        _installedRecord(
          descriptor: descriptor,
          installedPath: finalPath,
          bytes: verification.verifiedBytes,
        ),
      );
    }
    await _deleteDirectoryWithin(
      path: tempPath,
      allowedRoot: fileLayout.modelTempRoot,
    );
    _notify(
      onProgress,
      DownloadableModelPhase.ready,
      verification.verifiedBytes,
      manifest.requiredBytes,
    );
    return DownloadableModelResult(
      installedPath: finalPath,
      alreadyInstalled: alreadyInstalled,
      resumed: false,
    );
  }

  Future<void> _validatePreflight({
    required bool allowMeteredNetwork,
    required ModelDownloadCancellationToken cancellation,
  }) async {
    cancellation.throwIfCanceled();
    final freeBytes = await capacity.getFreeBytes();
    if (freeBytes < minimumRuntimeInitializationFreeBytes) {
      final shortage = minimumRuntimeInitializationFreeBytes - freeBytes;
      throw DownloadableModelException(
        code: 'model.storage.insufficient',
        message: '初始化至少需要 1 GiB 可用空间，还缺少 $shortage 字节',
      );
    }
    final kind = await network.getCurrentKind();
    if (kind == DownloadNetworkKind.offline) {
      throw const DownloadableModelException(
        code: 'model.network.offline',
        message: '当前无可用网络，请联网后重试',
      );
    }
    if ((kind == DownloadNetworkKind.metered ||
            kind == DownloadNetworkKind.unknown) &&
        !allowMeteredNetwork) {
      throw const DownloadableModelException(
        code: 'model.network.confirmationRequired',
        message: '当前网络可能产生流量费用，需要确认后下载',
      );
    }
  }

  void _validateInputs(
    AsrModelDescriptor descriptor,
    ModelManifestEntry manifest,
  ) {
    if (descriptor.installationType != AsrInstallationType.downloadable ||
        manifest.installationType != AsrInstallationType.downloadable.name) {
      throw const DownloadableModelException(
        code: 'model.download.type',
        message: '下载服务只接受可下载模型',
      );
    }
    if (descriptor.modelId != manifest.modelId ||
        descriptor.version != manifest.version ||
        descriptor.requiredBytes != manifest.requiredBytes) {
      throw const DownloadableModelException(
        code: 'model.download.manifest',
        message: '模型描述与 Manifest 不一致',
      );
    }
    if (manifest.files.any((file) => Uri.parse(file.url).scheme != 'https')) {
      throw const DownloadableModelException(
        code: 'model.download.url',
        message: '模型文件必须使用 HTTPS',
      );
    }
  }

  ModelInstallation _retryableRecord(
    AsrModelDescriptor descriptor,
    ModelInstallation? current,
  ) {
    if (current == null) {
      return ModelInstallation(
        modelId: descriptor.modelId,
        version: descriptor.version,
        installationType: descriptor.installationType,
        state: ModelInstallationState.notInstalled,
        bytes: 0,
      );
    }
    if (current.state == ModelInstallationState.notInstalled ||
        current.state == ModelInstallationState.failed ||
        current.state == ModelInstallationState.paused ||
        current.state == ModelInstallationState.updateAvailable) {
      return current;
    }
    return ModelInstallation(
      modelId: descriptor.modelId,
      version: descriptor.version,
      installationType: descriptor.installationType,
      state: ModelInstallationState.failed,
      bytes: current.bytes,
      lastErrorCode: 'model.download.recoveredState',
    );
  }

  ModelInstallation _pausedRecord(ModelInstallation current) {
    if (current.state.canTransitionTo(ModelInstallationState.paused)) {
      return current.transitionTo(
        ModelInstallationState.paused,
        errorCode: 'model.download.canceled',
      );
    }
    return ModelInstallation(
      modelId: current.modelId,
      version: current.version,
      installationType: current.installationType,
      state: ModelInstallationState.paused,
      bytes: current.bytes,
      lastErrorCode: 'model.download.canceled',
    );
  }

  ModelInstallation _failedRecord(ModelInstallation current, String errorCode) {
    if (current.state.canTransitionTo(ModelInstallationState.failed)) {
      return current.transitionTo(
        ModelInstallationState.failed,
        errorCode: errorCode,
      );
    }
    return ModelInstallation(
      modelId: current.modelId,
      version: current.version,
      installationType: current.installationType,
      state: ModelInstallationState.failed,
      bytes: current.bytes,
      lastErrorCode: errorCode,
    );
  }

  ModelInstallation _installedRecord({
    required AsrModelDescriptor descriptor,
    required String installedPath,
    required int bytes,
  }) {
    return ModelInstallation(
      modelId: descriptor.modelId,
      version: descriptor.version,
      installationType: descriptor.installationType,
      state: ModelInstallationState.installed,
      installedPath: installedPath,
      verifiedAt: now().toUtc(),
      bytes: bytes,
    );
  }

  void _notify(
    DownloadableModelProgressCallback? callback,
    DownloadableModelPhase phase,
    int completedBytes,
    int totalBytes,
  ) {
    callback?.call(
      DownloadableModelProgress(
        phase: phase,
        completedBytes: completedBytes,
        totalBytes: totalBytes,
      ),
    );
  }
}

Future<void> _deleteDirectoryWithin({
  required String path,
  required String allowedRoot,
}) async {
  final normalizedPath = p.normalize(p.absolute(path));
  final normalizedRoot = p.normalize(p.absolute(allowedRoot));
  if (normalizedPath == normalizedRoot ||
      !p.isWithin(normalizedRoot, normalizedPath)) {
    throw DownloadableModelException(
      code: 'model.path.invalid',
      message: '拒绝删除模型根目录之外的路径',
    );
  }
  final directory = Directory(normalizedPath);
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}
