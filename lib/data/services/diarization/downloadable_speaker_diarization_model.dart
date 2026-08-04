import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/runtime/speaker_diarization_manifest.dart';
import '../models/downloadable_model_service.dart';
import '../models/model_download_types.dart';
import '../models/model_file_verifier.dart';
import '../models/restricted_tar_bz2_extractor.dart';
import '../models/runtime_artifact_install_transaction.dart';
import '../models/runtime_asset_installers.dart';
import '../storage/app_file_layout.dart';

final class DownloadableSpeakerDiarizationModelService
    implements RuntimeSpeakerDiarizationInstaller {
  const DownloadableSpeakerDiarizationModelService({
    required this.fileLayout,
    required this.downloader,
    this.verifier = const ModelFileVerifier(),
    this.extractor = const RestrictedTarBz2Extractor(),
  });

  final AppFileLayout fileLayout;
  final ModelFileDownloader downloader;
  final ModelFileVerifier verifier;
  final RestrictedTarBz2Extractor extractor;

  SpeakerDiarizationAssetPaths assetPaths(SpeakerDiarizationManifest manifest) {
    final root = fileLayout.modelVersionDirectory(
      manifest.modelId,
      manifest.version,
    );
    return SpeakerDiarizationAssetPaths(
      segmentationModelPath: _resolveWithin(
        root,
        manifest.segmentationArchive.installFiles
            .singleWhere(
              (entry) => entry.file.path == speakerSegmentationModelPath,
            )
            .file
            .path,
      ),
      embeddingModelPath: _resolveWithin(
        root,
        manifest.embeddingModel.installation.path,
      ),
    );
  }

  @override
  Future<bool> isReadyFast(SpeakerDiarizationManifest manifest) async {
    final root = fileLayout.modelVersionDirectory(
      manifest.modelId,
      manifest.version,
    );
    final expected = manifest.installationManifest.files;
    for (final entry in expected) {
      final file = File(_resolveWithin(root, entry.path));
      if (!await file.exists() || await file.length() != entry.bytes) {
        return false;
      }
    }
    final directory = Directory(root);
    if (!await directory.exists()) {
      return false;
    }
    var actualFiles = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        actualFiles++;
      }
    }
    return actualFiles == expected.length;
  }

  @override
  Future<SpeakerDiarizationAssetPaths> prepare({
    required SpeakerDiarizationManifest manifest,
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
        message: '说话人分离资源下载已暂停，可稍后继续',
        cause: error,
      );
    }
  }

  Future<SpeakerDiarizationAssetPaths> _prepare({
    required SpeakerDiarizationManifest manifest,
    required ModelDownloadCancellationToken cancellation,
    void Function(int completedBytes, int totalBytes)? onProgress,
  }) async {
    final finalPath = fileLayout.modelVersionDirectory(
      manifest.modelId,
      manifest.version,
    );
    final finalVerification = await verifier.verifyDirectory(
      directoryPath: finalPath,
      manifest: manifest.installationManifest,
    );
    if (finalVerification.isValid) {
      return assetPaths(manifest);
    }

    final tempPath = fileLayout.modelTempDirectory(
      manifest.modelId,
      manifest.version,
    );
    final downloadPath = p.join(tempPath, 'download');
    final installationPath = p.join(tempPath, 'install');
    try {
      await RuntimeArtifactInstallTransaction(verifier: verifier).install(
        manifest: manifest.downloadManifest,
        installationManifest: manifest.installationManifest,
        tempPath: tempPath,
        downloadPath: downloadPath,
        installationPath: installationPath,
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
        prepareInstallation:
            ({
              required downloadPath,
              required installationPath,
              required throwIfCanceled,
            }) async {
              await extractor.extract(
                archivePath: _resolveWithin(
                  downloadPath,
                  manifest.segmentationArchive.download.path,
                ),
                installationPath: installationPath,
                allowedEntries: manifest.segmentationArchive.allowedEntries,
                installFiles: manifest.segmentationArchive.installFiles,
                throwIfCanceled: throwIfCanceled,
              );
              throwIfCanceled();
              final embeddingSource = File(
                _resolveWithin(
                  downloadPath,
                  manifest.embeddingModel.download.path,
                ),
              );
              final embeddingTarget = _resolveWithin(
                installationPath,
                manifest.embeddingModel.installation.path,
              );
              await Directory(
                p.dirname(embeddingTarget),
              ).create(recursive: true);
              await embeddingSource.copy(embeddingTarget);
              throwIfCanceled();
            },
        onProgress: onProgress,
      );
    } on RuntimeArtifactInstallException catch (error) {
      throw DownloadableModelException(
        code: switch (error.failure) {
          RuntimeArtifactInstallFailure.incomplete =>
            'speaker.download.incomplete',
          RuntimeArtifactInstallFailure.integrity => 'speaker.integrity',
          RuntimeArtifactInstallFailure.invalidPath => 'speaker.path.invalid',
          RuntimeArtifactInstallFailure.preparation =>
            'speaker.archive.invalid',
        },
        message: error.message,
        cause: error,
      );
    }
    return assetPaths(manifest);
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
      '说话人资源路径越界：$relativePath',
    );
  }
  return candidate;
}
