import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/models/model_manifest.dart';
import 'model_download_types.dart';
import 'model_file_verifier.dart';

enum RuntimeArtifactInstallFailure {
  incomplete,
  integrity,
  invalidPath,
  preparation,
}

final class RuntimeArtifactInstallException implements Exception {
  const RuntimeArtifactInstallException(this.failure, this.message);

  final RuntimeArtifactInstallFailure failure;
  final String message;
}

final class RuntimeArtifactDownloadOutcome {
  const RuntimeArtifactDownloadOutcome({
    required this.finalBytes,
    required this.resumed,
  });

  final int finalBytes;
  final bool resumed;
}

final class RuntimeArtifactInstallResult {
  const RuntimeArtifactInstallResult({
    required this.verifiedBytes,
    required this.resumed,
  });

  final int verifiedBytes;
  final bool resumed;
}

typedef RuntimeArtifactDownload =
    Future<RuntimeArtifactDownloadOutcome> Function({
      required ModelManifestFile file,
      required String destinationPath,
      required int resumeFrom,
      required void Function(int absoluteFileBytes) onProgress,
    });

typedef RuntimeArtifactPreparation =
    Future<void> Function({
      required String downloadPath,
      required String installationPath,
      required void Function() throwIfCanceled,
    });

/// 共享 ASR 与 VAD 的文件下载、续传、校验和原子目录切换事务。
///
/// 安装记录、网络预检和用户提示仍由各自业务服务负责。
final class RuntimeArtifactInstallTransaction {
  const RuntimeArtifactInstallTransaction({
    this.verifier = const ModelFileVerifier(),
  });

  final ModelFileVerifier verifier;

  Future<RuntimeArtifactInstallResult> install({
    required ModelManifestEntry manifest,
    required String tempPath,
    required String finalPath,
    required String tempRoot,
    required String finalRoot,
    required void Function() throwIfCanceled,
    required RuntimeArtifactDownload download,
    void Function(int completedBytes, int totalBytes)? onProgress,
    Future<void> Function()? onVerifying,
    Future<void> Function(int verifiedBytes)? onCommitting,
    String? downloadPath,
    String? installationPath,
    ModelManifestEntry? installationManifest,
    RuntimeArtifactPreparation? prepareInstallation,
  }) async {
    final effectiveDownloadPath = downloadPath ?? tempPath;
    final effectiveInstallationPath = installationPath ?? tempPath;
    _requireWithinOrEqual(tempPath, effectiveDownloadPath);
    _requireWithinOrEqual(tempPath, effectiveInstallationPath);
    if (prepareInstallation != null &&
        p.equals(effectiveDownloadPath, effectiveInstallationPath)) {
      throw const RuntimeArtifactInstallException(
        RuntimeArtifactInstallFailure.invalidPath,
        '转换型安装必须隔离下载目录与安装目录',
      );
    }
    await Directory(effectiveDownloadPath).create(recursive: true);
    var completedBeforeFile = 0;
    var resumed = false;
    for (final file in manifest.files) {
      throwIfCanceled();
      final destination = _resolveWithin(effectiveDownloadPath, file.path);
      await Directory(p.dirname(destination)).create(recursive: true);
      final output = File(destination);
      var resumeFrom = await output.exists() ? await output.length() : 0;
      if (resumeFrom > file.bytes) {
        await output.delete();
        resumeFrom = 0;
      }
      resumed = resumed || resumeFrom > 0;
      onProgress?.call(
        completedBeforeFile + resumeFrom,
        manifest.requiredBytes,
      );
      if (resumeFrom < file.bytes) {
        final outcome = await download(
          file: file,
          destinationPath: destination,
          resumeFrom: resumeFrom,
          onProgress: (absoluteFileBytes) => onProgress?.call(
            completedBeforeFile + absoluteFileBytes,
            manifest.requiredBytes,
          ),
        );
        resumed = resumed || outcome.resumed;
        if (outcome.finalBytes != file.bytes) {
          throw RuntimeArtifactInstallException(
            RuntimeArtifactInstallFailure.incomplete,
            '${file.path} 下载不完整',
          );
        }
      }
      completedBeforeFile += file.bytes;
    }

    await onVerifying?.call();
    final downloadVerification = await verifier.verifyDirectory(
      directoryPath: effectiveDownloadPath,
      manifest: manifest,
    );
    if (!downloadVerification.isValid) {
      await deleteDirectoryWithin(path: tempPath, allowedRoot: tempRoot);
      throw RuntimeArtifactInstallException(
        RuntimeArtifactInstallFailure.integrity,
        downloadVerification.issues
            .map((issue) => '${issue.path}:${issue.kind.name}')
            .join(', '),
      );
    }

    var verification = downloadVerification;
    if (prepareInstallation != null) {
      try {
        await deleteDirectoryWithin(
          path: effectiveInstallationPath,
          allowedRoot: tempPath,
        );
        await Directory(effectiveInstallationPath).create(recursive: true);
        throwIfCanceled();
        await prepareInstallation(
          downloadPath: effectiveDownloadPath,
          installationPath: effectiveInstallationPath,
          throwIfCanceled: throwIfCanceled,
        );
        throwIfCanceled();
        verification = await verifier.verifyDirectory(
          directoryPath: effectiveInstallationPath,
          manifest: installationManifest ?? manifest,
        );
      } on ModelDownloadCanceledException {
        await deleteDirectoryWithin(
          path: effectiveInstallationPath,
          allowedRoot: tempPath,
        );
        rethrow;
      } on RuntimeArtifactInstallException {
        await deleteDirectoryWithin(path: tempPath, allowedRoot: tempRoot);
        rethrow;
      } on Object catch (error) {
        await deleteDirectoryWithin(path: tempPath, allowedRoot: tempRoot);
        throw RuntimeArtifactInstallException(
          RuntimeArtifactInstallFailure.preparation,
          '运行资源准备失败：$error',
        );
      }
      if (!verification.isValid) {
        await deleteDirectoryWithin(path: tempPath, allowedRoot: tempRoot);
        throw RuntimeArtifactInstallException(
          RuntimeArtifactInstallFailure.integrity,
          verification.issues
              .map((issue) => '${issue.path}:${issue.kind.name}')
              .join(', '),
        );
      }
    }

    await onCommitting?.call(verification.verifiedBytes);
    await Directory(p.dirname(finalPath)).create(recursive: true);
    await deleteDirectoryWithin(path: finalPath, allowedRoot: finalRoot);
    await Directory(effectiveInstallationPath).rename(finalPath);
    if (!p.equals(tempPath, effectiveInstallationPath)) {
      await deleteDirectoryWithin(path: tempPath, allowedRoot: tempRoot);
    }
    return RuntimeArtifactInstallResult(
      verifiedBytes: verification.verifiedBytes,
      resumed: resumed,
    );
  }
}

void _requireWithinOrEqual(String root, String candidate) {
  final normalizedRoot = p.normalize(p.absolute(root));
  final normalizedCandidate = p.normalize(p.absolute(candidate));
  if (normalizedCandidate != normalizedRoot &&
      !p.isWithin(normalizedRoot, normalizedCandidate)) {
    throw const RuntimeArtifactInstallException(
      RuntimeArtifactInstallFailure.invalidPath,
      '运行资源暂存路径越界',
    );
  }
}

String _resolveWithin(String root, String relativePath) {
  final normalizedRoot = p.normalize(p.absolute(root));
  final candidate = p.normalize(
    p.absolute(p.joinAll([normalizedRoot, ...relativePath.split('/')])),
  );
  if (candidate == normalizedRoot || !p.isWithin(normalizedRoot, candidate)) {
    throw RuntimeArtifactInstallException(
      RuntimeArtifactInstallFailure.invalidPath,
      '运行资源路径越界：$relativePath',
    );
  }
  return candidate;
}

Future<void> deleteDirectoryWithin({
  required String path,
  required String allowedRoot,
}) async {
  final normalizedPath = p.normalize(p.absolute(path));
  final normalizedRoot = p.normalize(p.absolute(allowedRoot));
  if (normalizedPath == normalizedRoot ||
      !p.isWithin(normalizedRoot, normalizedPath)) {
    throw const RuntimeArtifactInstallException(
      RuntimeArtifactInstallFailure.invalidPath,
      '拒绝删除运行资源根目录之外的路径',
    );
  }
  final directory = Directory(normalizedPath);
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}
