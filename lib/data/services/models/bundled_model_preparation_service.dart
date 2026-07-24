import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../domain/models/asr_model.dart';
import '../../../domain/models/model_installation.dart';
import '../../../domain/models/model_manifest.dart';
import '../../../domain/models/workflow_states.dart';
import '../../repositories/repository_contracts.dart';
import '../storage/app_file_layout.dart';
import 'model_file_verifier.dart';

abstract interface class ModelAssetSource {
  Future<Uint8List> load(String assetUrl);
}

enum BundledModelPreparationPhase {
  checking,
  copying,
  verifying,
  committing,
  ready,
}

final class BundledModelPreparationProgress {
  const BundledModelPreparationProgress({
    required this.phase,
    required this.completedBytes,
    required this.totalBytes,
  });

  final BundledModelPreparationPhase phase;
  final int completedBytes;
  final int totalBytes;
}

final class BundledModelPreparationResult {
  const BundledModelPreparationResult({
    required this.installedPath,
    required this.alreadyReady,
    required this.recoveredExistingFiles,
  });

  final String installedPath;
  final bool alreadyReady;
  final bool recoveredExistingFiles;
}

final class BundledModelPreparationException implements Exception {
  const BundledModelPreparationException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'BundledModelPreparationException($code, $message)';
}

typedef ModelPreparationProgressCallback =
    void Function(BundledModelPreparationProgress progress);

final class BundledModelPreparationService {
  BundledModelPreparationService({
    required this.fileLayout,
    required this.installations,
    required this.assetSource,
    required this.verifier,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final AppFileLayout fileLayout;
  final ModelInstallationRepository installations;
  final ModelAssetSource assetSource;
  final ModelFileVerifier verifier;
  final DateTime Function() now;

  Future<BundledModelPreparationResult> prepare({
    required AsrModelDescriptor descriptor,
    required ModelManifestEntry manifest,
    ModelPreparationProgressCallback? onProgress,
  }) async {
    _validateInputs(descriptor, manifest);
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
      BundledModelPreparationPhase.checking,
      0,
      manifest.requiredBytes,
    );
    final existingDirectory = Directory(finalPath);
    if (await existingDirectory.exists()) {
      final existing = await verifier.verifyDirectory(
        directoryPath: finalPath,
        manifest: manifest,
      );
      if (existing.isValid) {
        final alreadyReady =
            current?.state == ModelInstallationState.installed &&
            current?.installedPath == finalPath;
        if (!alreadyReady) {
          await installations.save(
            _installedRecord(descriptor, finalPath, existing.verifiedBytes),
          );
        }
        _notify(
          onProgress,
          BundledModelPreparationPhase.ready,
          manifest.requiredBytes,
          manifest.requiredBytes,
        );
        return BundledModelPreparationResult(
          installedPath: finalPath,
          alreadyReady: alreadyReady,
          recoveredExistingFiles: !alreadyReady,
        );
      }
      await _deleteDirectoryWithin(
        path: finalPath,
        allowedRoot: fileLayout.modelsRoot,
      );
    }

    var state = _retryableRecord(descriptor, current);
    try {
      state = state.transitionTo(ModelInstallationState.checking);
      await installations.save(state);

      await _deleteDirectoryWithin(
        path: tempPath,
        allowedRoot: fileLayout.modelTempRoot,
      );
      await Directory(tempPath).create(recursive: true);

      state = state.transitionTo(ModelInstallationState.downloading);
      await installations.save(state);
      var copiedBytes = 0;
      _notify(
        onProgress,
        BundledModelPreparationPhase.copying,
        copiedBytes,
        manifest.requiredBytes,
      );
      for (final file in manifest.files) {
        final bytes = await assetSource.load(file.url);
        final destination = _resolveWithin(tempPath, file.path);
        await Directory(p.dirname(destination)).create(recursive: true);
        final output = await File(destination).open(mode: FileMode.write);
        try {
          await output.writeFrom(bytes);
          await output.flush();
        } finally {
          await output.close();
        }
        copiedBytes += bytes.length;
        _notify(
          onProgress,
          BundledModelPreparationPhase.copying,
          copiedBytes,
          manifest.requiredBytes,
        );
      }

      state = state.transitionTo(ModelInstallationState.verifying);
      await installations.save(state);
      _notify(
        onProgress,
        BundledModelPreparationPhase.verifying,
        copiedBytes,
        manifest.requiredBytes,
      );
      final verification = await verifier.verifyDirectory(
        directoryPath: tempPath,
        manifest: manifest,
      );
      if (!verification.isValid) {
        throw _PreparationFailure(
          code: 'model.integrity',
          message: verification.issues
              .map((issue) => '${issue.path}:${issue.kind.name}')
              .join(', '),
        );
      }

      _notify(
        onProgress,
        BundledModelPreparationPhase.committing,
        verification.verifiedBytes,
        manifest.requiredBytes,
      );
      await Directory(p.dirname(finalPath)).create(recursive: true);
      await Directory(tempPath).rename(finalPath);

      final installed = state.transitionTo(
        ModelInstallationState.installed,
        installedPath: finalPath,
        verifiedAt: now().toUtc(),
        bytes: verification.verifiedBytes,
      );
      await installations.save(installed);
      _notify(
        onProgress,
        BundledModelPreparationPhase.ready,
        verification.verifiedBytes,
        manifest.requiredBytes,
      );
      return BundledModelPreparationResult(
        installedPath: finalPath,
        alreadyReady: false,
        recoveredExistingFiles: false,
      );
    } catch (error, stackTrace) {
      final failure = error is _PreparationFailure
          ? error
          : _PreparationFailure(
              code: 'model.prepare',
              message: '内置模型准备失败',
              cause: error,
            );
      try {
        await installations.save(_failedRecord(state, failure.code));
      } on Object {
        // 最终文件可能已原子形成；下次启动会重新校验并收养该孤儿目录。
      }
      Error.throwWithStackTrace(
        BundledModelPreparationException(
          code: failure.code,
          message: failure.message,
          cause: failure.cause ?? error,
        ),
        stackTrace,
      );
    }
  }

  void _validateInputs(
    AsrModelDescriptor descriptor,
    ModelManifestEntry manifest,
  ) {
    if (descriptor.installationType != AsrInstallationType.bundled) {
      throw ArgumentError.value(
        descriptor.installationType,
        'descriptor',
        '只接受内置模型',
      );
    }
    if (manifest.modelId != descriptor.modelId ||
        manifest.version != descriptor.version ||
        manifest.installationType != descriptor.installationType.name ||
        manifest.requiredBytes != descriptor.requiredBytes) {
      throw ArgumentError('Manifest 与模型描述不一致');
    }
    if (manifest.files.any(
      (file) => Uri.tryParse(file.url)?.scheme != 'asset',
    )) {
      throw ArgumentError('内置模型只能从 asset:// 读取');
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
        installationType: AsrInstallationType.bundled,
        state: ModelInstallationState.notInstalled,
        bytes: 0,
      );
    }
    if (current.state == ModelInstallationState.notInstalled ||
        current.state == ModelInstallationState.failed) {
      return current;
    }
    return _failedRecord(current, 'model.interrupted');
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
      installedPath: current.installedPath,
      verifiedAt: current.verifiedAt,
      bytes: current.bytes,
      lastErrorCode: errorCode,
    );
  }

  ModelInstallation _installedRecord(
    AsrModelDescriptor descriptor,
    String installedPath,
    int bytes,
  ) {
    return ModelInstallation(
      modelId: descriptor.modelId,
      version: descriptor.version,
      installationType: AsrInstallationType.bundled,
      state: ModelInstallationState.installed,
      installedPath: installedPath,
      verifiedAt: now().toUtc(),
      bytes: bytes,
    );
  }

  void _notify(
    ModelPreparationProgressCallback? callback,
    BundledModelPreparationPhase phase,
    int completedBytes,
    int totalBytes,
  ) {
    callback?.call(
      BundledModelPreparationProgress(
        phase: phase,
        completedBytes: completedBytes.clamp(0, totalBytes),
        totalBytes: totalBytes,
      ),
    );
  }

  String _resolveWithin(String root, String relativePath) {
    final normalizedRoot = p.normalize(p.absolute(root));
    final resolved = p.normalize(
      p.absolute(p.joinAll([normalizedRoot, ...relativePath.split('/')])),
    );
    if (!p.isWithin(normalizedRoot, resolved)) {
      throw ArgumentError.value(relativePath, 'relativePath', '路径越界');
    }
    return resolved;
  }

  Future<void> _deleteDirectoryWithin({
    required String path,
    required String allowedRoot,
  }) async {
    final normalizedRoot = p.normalize(p.absolute(allowedRoot));
    final normalizedPath = p.normalize(p.absolute(path));
    if (!p.isWithin(normalizedRoot, normalizedPath)) {
      throw StateError('拒绝删除允许根目录之外的路径：$normalizedPath');
    }
    final directory = Directory(normalizedPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

final class _PreparationFailure implements Exception {
  const _PreparationFailure({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;
}
