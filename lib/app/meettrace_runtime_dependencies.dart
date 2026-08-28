import 'package:flutter/services.dart';

import '../data/models/runtime/silero_vad_manifest.dart';
import '../data/models/runtime/speaker_diarization_manifest.dart';
import '../data/repositories/sqflite_runtime_download_consent_repository.dart';
import '../data/services/models/downloadable_model_service.dart';
import '../data/services/models/http_model_file_downloader.dart';
import '../data/services/models/local_runtime_asset_preparation_service.dart';
import '../data/services/models/model_file_verifier.dart';
import '../data/services/models/model_manifest_parser.dart';
import '../data/services/models/platform_download_preflight_providers.dart';
import '../data/services/diarization/downloadable_speaker_diarization_model.dart';
import '../data/services/vad/downloadable_silero_vad_model.dart';
import '../domain/models/asr_model_registry.dart';
import '../domain/models/model_manifest.dart';
import 'meettrace_storage_dependencies.dart';

final class RuntimeAssetDependencies {
  const RuntimeAssetDependencies._({
    required this.registry,
    required this.modelManifest,
    required this.speakerManifest,
    required this.modelDownloads,
    required this.runtimeAssets,
    required this.vadModelPath,
    required this.speakerSegmentationModelPath,
    required this.speakerEmbeddingModelPath,
  });

  final AsrModelRegistry registry;
  final ModelManifest modelManifest;
  final SpeakerDiarizationManifest speakerManifest;
  final DownloadableModelService modelDownloads;
  final LocalRuntimeAssetPreparationService runtimeAssets;
  final String vadModelPath;
  final String speakerSegmentationModelPath;
  final String speakerEmbeddingModelPath;

  static Future<RuntimeAssetDependencies> create({
    required AsrModelRegistry registry,
    required StorageDependencies storage,
  }) async {
    final manifest = ModelManifestParser(
      registry: registry,
      currentAppVersion: '1.0.0',
    ).parse(await loadRuntimeManifestAsset('assets/models/manifest.json'));
    final vadManifest = const SileroVadManifestParser().parse(
      await loadRuntimeManifestAsset(sileroVadManifestAssetPath),
    );
    final speakerManifest = const SpeakerDiarizationManifestParser().parse(
      await loadRuntimeManifestAsset(speakerDiarizationManifestAssetPath),
    );
    final capacity = const DeviceStorageCapacityProvider();
    final network = ConnectivityDownloadNetworkStatusProvider();
    final downloader = HttpModelFileDownloader();
    final modelDownloads = DownloadableModelService(
      fileLayout: storage.fileLayout,
      installations: storage.installations,
      leases: storage.leases,
      capacity: capacity,
      network: network,
      downloader: downloader,
      verifier: const ModelFileVerifier(),
    );
    final vadDownloads = DownloadableSileroVadModelService(
      fileLayout: storage.fileLayout,
      downloader: downloader,
    );
    final speakerDownloads = DownloadableSpeakerDiarizationModelService(
      fileLayout: storage.fileLayout,
      downloader: downloader,
    );
    final speakerPaths = speakerDownloads.assetPaths(speakerManifest);
    final runtimeAssets = LocalRuntimeAssetPreparationService(
      registry: registry,
      modelManifest: manifest,
      vadManifest: vadManifest,
      speakerManifest: speakerManifest,
      modelDownloads: modelDownloads,
      vadDownloads: vadDownloads,
      speakerDownloads: speakerDownloads,
      capacity: capacity,
      network: network,
      consents: SqfliteRuntimeDownloadConsentRepository(storage.database),
    );
    return RuntimeAssetDependencies._(
      registry: registry,
      modelManifest: manifest,
      speakerManifest: speakerManifest,
      modelDownloads: modelDownloads,
      runtimeAssets: runtimeAssets,
      vadModelPath: vadDownloads.modelPath(vadManifest),
      speakerSegmentationModelPath: speakerPaths.segmentationModelPath,
      speakerEmbeddingModelPath: speakerPaths.embeddingModelPath,
    );
  }
}

/// Manifest 很小且是启动硬依赖。绕过 [CachingAssetBundle] 的字符串缓存，
/// 避免开发构建替换资源目录时的一次瞬时读取失败污染后续显式重试。
Future<String> loadRuntimeManifestAsset(String path, {AssetBundle? bundle}) {
  return (bundle ?? rootBundle).loadString(path, cache: false);
}
