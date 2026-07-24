import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/models/asr_model.dart';
import '../../../domain/models/model_installation.dart';
import '../../../domain/models/model_manifest.dart';
import '../../../domain/models/workflow_states.dart';
import '../../repositories/repository_contracts.dart';
import '../storage/app_file_layout.dart';
import 'model_file_verifier.dart';

const minimumAdvancedModelFreeBytes = 2 * 1024 * 1024 * 1024;

enum DownloadNetworkKind { offline, unmetered, metered, unknown }

enum DownloadableModelPhase {
  checking,
  downloading,
  verifying,
  committing,
  ready,
  deleting,
}

final class DownloadableModelProgress {
  const DownloadableModelProgress({
    required this.phase,
    required this.completedBytes,
    required this.totalBytes,
  });

  final DownloadableModelPhase phase;
  final int completedBytes;
  final int totalBytes;
}

final class DownloadableModelResult {
  const DownloadableModelResult({
    required this.installedPath,
    required this.alreadyInstalled,
    required this.resumed,
  });

  final String installedPath;
  final bool alreadyInstalled;
  final bool resumed;
}

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

final class ModelDownloadCanceledException implements Exception {
  const ModelDownloadCanceledException();
}

typedef DownloadableModelProgressCallback =
    void Function(DownloadableModelProgress progress);

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

final class ModelDownloadCancellationToken {
  bool _isCanceled = false;
  final Set<void Function()> _listeners = {};

  bool get isCanceled => _isCanceled;

  void cancel() {
    if (_isCanceled) {
      return;
    }
    _isCanceled = true;
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void throwIfCanceled() {
    if (_isCanceled) {
      throw const ModelDownloadCanceledException();
    }
  }

  void addCancelListener(void Function() listener) {
    if (_isCanceled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeCancelListener(void Function() listener) {
    _listeners.remove(listener);
  }
}

final class DownloadableModelService {
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

  Future<DownloadableModelResult> download({
    required AsrModelDescriptor descriptor,
    required ModelManifestEntry manifest,
    bool allowMeteredNetwork = false,
    ModelDownloadCancellationToken? cancellation,
    DownloadableModelProgressCallback? onProgress,
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

    var state = _retryableRecord(descriptor, current);
    var integrityFailure = false;
    try {
      if (state.state == ModelInstallationState.notInstalled ||
          state.state == ModelInstallationState.failed ||
          state.state == ModelInstallationState.updateAvailable) {
        state = state.transitionTo(ModelInstallationState.checking);
        await installations.save(state);
      }

      await _validatePreflight(
        allowMeteredNetwork: allowMeteredNetwork,
        cancellation: token,
      );

      state = state.transitionTo(ModelInstallationState.downloading);
      await installations.save(state);
      await Directory(tempPath).create(recursive: true);

      var completedBeforeFile = 0;
      var resumed = false;
      for (final file in manifest.files) {
        token.throwIfCanceled();
        final destination = _resolveWithin(tempPath, file.path);
        await Directory(p.dirname(destination)).create(recursive: true);
        final output = File(destination);
        var resumeFrom = await output.exists() ? await output.length() : 0;
        if (resumeFrom > file.bytes) {
          await output.delete();
          resumeFrom = 0;
        }
        resumed = resumed || resumeFrom > 0;
        _notify(
          onProgress,
          DownloadableModelPhase.downloading,
          completedBeforeFile + resumeFrom,
          manifest.requiredBytes,
        );
        if (resumeFrom < file.bytes) {
          final result = await downloader.download(
            source: Uri.parse(file.url),
            destinationPath: destination,
            resumeFrom: resumeFrom,
            expectedBytes: file.bytes,
            cancellation: token,
            onProgress: (absoluteFileBytes) {
              _notify(
                onProgress,
                DownloadableModelPhase.downloading,
                completedBeforeFile + absoluteFileBytes,
                manifest.requiredBytes,
              );
            },
          );
          resumed = resumed || result.resumed;
          if (result.finalBytes != file.bytes) {
            throw DownloadableModelException(
              code: 'model.download.incomplete',
              message: '${file.path} 下载不完整',
            );
          }
        }
        completedBeforeFile += file.bytes;
      }

      state = state.transitionTo(ModelInstallationState.verifying);
      await installations.save(state);
      _notify(
        onProgress,
        DownloadableModelPhase.verifying,
        manifest.requiredBytes,
        manifest.requiredBytes,
      );
      final verification = await verifier.verifyDirectory(
        directoryPath: tempPath,
        manifest: manifest,
      );
      if (!verification.isValid) {
        integrityFailure = true;
        throw DownloadableModelException(
          code: 'model.integrity',
          message: verification.issues
              .map((issue) => '${issue.path}:${issue.kind.name}')
              .join(', '),
        );
      }

      _notify(
        onProgress,
        DownloadableModelPhase.committing,
        verification.verifiedBytes,
        manifest.requiredBytes,
      );
      await Directory(p.dirname(finalPath)).create(recursive: true);
      final finalDirectory = Directory(finalPath);
      if (await finalDirectory.exists()) {
        await _deleteDirectoryWithin(
          path: finalPath,
          allowedRoot: fileLayout.modelsRoot,
        );
      }
      await Directory(tempPath).rename(finalPath);

      final installed = state.transitionTo(
        ModelInstallationState.installed,
        installedPath: finalPath,
        verifiedAt: now().toUtc(),
        bytes: verification.verifiedBytes,
      );
      await installations.saveInstalledAndActivate(installed);
      _notify(
        onProgress,
        DownloadableModelPhase.ready,
        verification.verifiedBytes,
        manifest.requiredBytes,
      );
      return DownloadableModelResult(
        installedPath: finalPath,
        alreadyInstalled: false,
        resumed: resumed,
      );
    } catch (error, stackTrace) {
      if (integrityFailure) {
        await _deleteDirectoryWithin(
          path: tempPath,
          allowedRoot: fileLayout.modelTempRoot,
        );
      }
      final canceled =
          error is ModelDownloadCanceledException || token.isCanceled;
      final failure = canceled
          ? const DownloadableModelException(
              code: 'model.download.canceled',
              message: '高级模型下载已取消，可稍后继续',
            )
          : error is DownloadableModelException
          ? error
          : DownloadableModelException(
              code: 'model.download.failed',
              message: '高级模型下载失败，可重试',
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

  Future<DownloadableModelDeleteResult> delete({
    required AsrModelDescriptor descriptor,
    DownloadableModelProgressCallback? onProgress,
  }) async {
    if (descriptor.installationType != AsrInstallationType.downloadable) {
      throw const DownloadableModelException(
        code: 'model.delete.bundled',
        message: '内置标准模型不能删除',
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
    if (current == null &&
        !await Directory(finalPath).exists() &&
        !await Directory(tempPath).exists()) {
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
          message: '高级模型删除失败，可重试',
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
    if (freeBytes < minimumAdvancedModelFreeBytes) {
      throw DownloadableModelException(
        code: 'model.storage.insufficient',
        message: '至少需要 2 GiB 可用空间，当前为 $freeBytes 字节',
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
        message: '高级模型文件必须使用 HTTPS',
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

String _resolveWithin(String root, String relativePath) {
  final normalizedRoot = p.normalize(p.absolute(root));
  final candidate = p.normalize(
    p.absolute(p.joinAll([normalizedRoot, ...relativePath.split('/')])),
  );
  if (candidate != normalizedRoot && !p.isWithin(normalizedRoot, candidate)) {
    throw DownloadableModelException(
      code: 'model.path.invalid',
      message: '模型路径越界：$relativePath',
    );
  }
  return candidate;
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
