import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/runtime/silero_vad_manifest.dart';
import '../models/downloadable_model_service.dart';
import '../models/model_file_verifier.dart';
import '../models/runtime_artifact_install_transaction.dart';
import '../models/runtime_asset_installers.dart';
import '../storage/app_file_layout.dart';

final class DownloadableSileroVadModelService implements RuntimeVadInstaller {
  const DownloadableSileroVadModelService({
    required this.fileLayout,
    required this.downloader,
    this.verifier = const ModelFileVerifier(),
  });

  final AppFileLayout fileLayout;
  final ModelFileDownloader downloader;
  final ModelFileVerifier verifier;

  String modelPath(SileroVadManifest manifest) => p.join(
    fileLayout.modelVersionDirectory(manifest.modelId, manifest.version),
    sileroVadModelFileName,
  );

  @override
  Future<bool> isReadyFast(SileroVadManifest manifest) async {
    final file = File(modelPath(manifest));
    if (!await file.exists() || await file.length() != manifest.requiredBytes) {
      return false;
    }
    final root = Directory(p.dirname(file.path));
    var files = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        files++;
      }
    }
    return files == manifest.files.length;
  }

  @override
  Future<String> prepare({
    required SileroVadManifest manifest,
    required ModelDownloadCancellationToken cancellation,
    void Function(int completedBytes, int totalBytes)? onProgress,
  }) async {
    try {
      return await _prepare(
        manifest: manifest,
        cancellation: cancellation,
        onProgress: onProgress,
      );
    } on ModelDownloadCanceledException catch (error) {
      throw DownloadableModelException(
        code: 'model.download.canceled',
        message: 'VAD 下载已暂停，可稍后继续',
        cause: error,
      );
    }
  }

  Future<String> _prepare({
    required SileroVadManifest manifest,
    required ModelDownloadCancellationToken cancellation,
    void Function(int completedBytes, int totalBytes)? onProgress,
  }) async {
    final finalPath = fileLayout.modelVersionDirectory(
      manifest.modelId,
      manifest.version,
    );
    final tempPath = fileLayout.modelTempDirectory(
      manifest.modelId,
      manifest.version,
    );
    final finalVerification = await verifier.verifyDirectory(
      directoryPath: finalPath,
      manifest: manifest.verificationEntry,
    );
    if (finalVerification.isValid) {
      return modelPath(manifest);
    }
    try {
      await RuntimeArtifactInstallTransaction(verifier: verifier).install(
        manifest: manifest.verificationEntry,
        tempPath: tempPath,
        finalPath: finalPath,
        tempRoot: fileLayout.modelTempRoot,
        finalRoot: fileLayout.modelsRoot,
        throwIfCanceled: cancellation.throwIfCanceled,
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
                cancellation: cancellation,
                onProgress: onProgress,
              );
              return RuntimeArtifactDownloadOutcome(
                finalBytes: result.finalBytes,
                resumed: result.resumed,
              );
            },
        onProgress: onProgress,
      );
    } on RuntimeArtifactInstallException catch (error) {
      throw DownloadableModelException(
        code: switch (error.failure) {
          RuntimeArtifactInstallFailure.incomplete => 'vad.download.incomplete',
          RuntimeArtifactInstallFailure.integrity => 'vad.integrity',
          RuntimeArtifactInstallFailure.invalidPath => 'vad.path.invalid',
        },
        message: error.message,
        cause: error,
      );
    }
    return modelPath(manifest);
  }
}
