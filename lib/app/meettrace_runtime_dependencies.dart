import 'package:flutter/services.dart';

import '../data/models/runtime/silero_vad_manifest.dart';
import '../data/repositories/sqflite_runtime_download_consent_repository.dart';
import '../data/services/models/downloadable_model_service.dart';
import '../data/services/models/http_model_file_downloader.dart';
import '../data/services/models/local_runtime_asset_preparation_service.dart';
import '../data/services/models/model_file_verifier.dart';
import '../data/services/models/model_manifest_parser.dart';
import '../data/services/models/platform_download_preflight_providers.dart';
import '../data/services/vad/downloadable_silero_vad_model.dart';
import '../domain/models/asr_model_registry.dart';
import '../domain/models/model_manifest.dart';
import 'meettrace_storage_dependencies.dart';

final class RuntimeAssetDependencies {
  const RuntimeAssetDependencies._({
    required this.registry,
    required this.modelManifest,
    required this.modelDownloads,
    required this.runtimeAssets,
    required this.vadModelPath,
  });

  final AsrModelRegistry registry;
  final ModelManifest modelManifest;
  final DownloadableModelService modelDownloads;
  final LocalRuntimeAssetPreparationService runtimeAssets;
  final String vadModelPath;

  static Future<RuntimeAssetDependencies> create({
    required AsrModelRegistry registry,
    required StorageDependencies storage,
  }) async {
    final manifest = ModelManifestParser(
      registry: registry,
      currentAppVersion: '1.0.0',
    ).parse(await rootBundle.loadString('assets/models/manifest.json'));
    final vadManifest = const SileroVadManifestParser().parse(
      await rootBundle.loadString(sileroVadManifestAssetPath),
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
    final runtimeAssets = LocalRuntimeAssetPreparationService(
      registry: registry,
      modelManifest: manifest,
      vadManifest: vadManifest,
      modelDownloads: modelDownloads,
      vadDownloads: vadDownloads,
      capacity: capacity,
      network: network,
      consents: SqfliteRuntimeDownloadConsentRepository(storage.database),
    );
    return RuntimeAssetDependencies._(
      registry: registry,
      modelManifest: manifest,
      modelDownloads: modelDownloads,
      runtimeAssets: runtimeAssets,
      vadModelPath: vadDownloads.modelPath(vadManifest),
    );
  }

  Future<void> dispose() async {}
}
