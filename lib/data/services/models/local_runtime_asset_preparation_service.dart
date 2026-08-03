import '../../../domain/models/asr_model_registry.dart';
import '../../../domain/models/model_manifest.dart';
import '../../../domain/models/runtime_initialization.dart';
import '../../../domain/ports/runtime_asset_preparation.dart';
import '../../models/runtime/silero_vad_manifest.dart';
import 'downloadable_model_service.dart';
import 'model_download_types.dart';
import 'runtime_asset_installers.dart';

final class LocalRuntimeAssetPreparationService
    implements RuntimeAssetPreparationPort {
  LocalRuntimeAssetPreparationService({
    required this.registry,
    required this.modelManifest,
    required this.vadManifest,
    required this.modelDownloads,
    required this.vadDownloads,
    required this.capacity,
    required this.network,
    required this.consents,
  });

  final AsrModelRegistry registry;
  final ModelManifest modelManifest;
  final SileroVadManifest vadManifest;
  final RuntimeAsrModelInstaller modelDownloads;
  final RuntimeVadInstaller vadDownloads;
  final ModelStorageCapacityProvider capacity;
  final DownloadNetworkStatusProvider network;
  final RuntimeDownloadConsentRepository consents;

  ModelDownloadCancellationToken? _activeCancellation;

  ModelManifestEntry get _modelEntry => modelManifest.models.singleWhere(
    (entry) => entry.modelId == registry.defaultModel.modelId,
  );

  int get totalBytes => _modelEntry.requiredBytes + vadManifest.requiredBytes;

  String get resourceSetId {
    final resources = <String>[
      for (final file in _modelEntry.files)
        '${_modelEntry.modelId}@${_modelEntry.version}/${file.path}:'
            '${file.bytes}:${file.sha256}',
      for (final file in vadManifest.files)
        '${vadManifest.modelId}@${vadManifest.version}/${file.path}:'
            '${file.bytes}:${file.sha256}',
    ]..sort();
    return resources.join('|');
  }

  Future<bool> hasMobileConsent() => consents.hasConsent(resourceSetId);

  @override
  Future<void> prepare({
    required void Function(RuntimeInitializationProgress progress) onProgress,
    bool forceRepair = false,
  }) async {
    if (totalBytes > maximumRuntimeDownloadBytes) {
      throw const RuntimeInitializationException(
        code: 'runtime.assets.overLimit',
        message: '固定运行资源超过 300,000,000 字节，必须重新评审 PRD',
      );
    }
    final descriptor = registry.defaultModel;
    final manifest = _modelEntry;
    onProgress(
      RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.checking,
        completedBytes: 0,
        totalBytes: totalBytes,
        message: '正在检查本地转录资源',
      ),
    );
    final modelReady = forceRepair
        ? false
        : await modelDownloads.isReadyFast(
            descriptor: descriptor,
            manifest: manifest,
          );
    final vadReady = await vadDownloads.isReadyFast(vadManifest);
    if (modelReady && vadReady) {
      onProgress(
        RuntimeInitializationProgress(
          phase: RuntimeInitializationPhase.ready,
          completedBytes: totalBytes,
          totalBytes: totalBytes,
        ),
      );
      return;
    }

    final freeBytes = await capacity.getFreeBytes();
    if (freeBytes < minimumRuntimeInitializationFreeBytes) {
      final shortage = minimumRuntimeInitializationFreeBytes - freeBytes;
      throw RuntimeInitializationException(
        code: 'runtime.storage.insufficient',
        message: '初始化至少需要 768 MiB 可用空间，还缺少 $shortage 字节',
        shortageBytes: shortage,
      );
    }
    final networkKind = await network.getCurrentKind();
    if (networkKind == DownloadNetworkKind.offline) {
      throw const RuntimeInitializationException(
        code: 'runtime.network.offline',
        message: '首次初始化需要联网下载离线转录资源',
      );
    }
    final metered =
        networkKind == DownloadNetworkKind.metered ||
        networkKind == DownloadNetworkKind.unknown;
    if (metered && !await consents.hasConsent(resourceSetId)) {
      final decimalMb = (totalBytes / 1000000).toStringAsFixed(1);
      throw RuntimeInitializationException(
        code: 'runtime.network.mobileConsentRequired',
        message: '将使用移动网络下载约 $decimalMb MB，可能产生流量费用；下载可暂停并续传。',
      );
    }

    final cancellation = ModelDownloadCancellationToken();
    _activeCancellation = cancellation;
    try {
      if (!modelReady) {
        await modelDownloads.download(
          descriptor: descriptor,
          manifest: manifest,
          allowMeteredNetwork: true,
          skipPreflight: true,
          forceDownload: forceRepair,
          cancellation: cancellation,
          onProgress: (progress) {
            onProgress(
              RuntimeInitializationProgress(
                phase: _mapPhase(progress.phase),
                completedBytes: progress.completedBytes,
                totalBytes: totalBytes,
                resourceName: 'SenseVoice',
              ),
            );
          },
        );
      }
      if (!vadReady) {
        await vadDownloads.prepare(
          manifest: vadManifest,
          cancellation: cancellation,
          onProgress: (completed, _) {
            onProgress(
              RuntimeInitializationProgress(
                phase: RuntimeInitializationPhase.downloading,
                completedBytes: descriptor.requiredBytes + completed,
                totalBytes: totalBytes,
                resourceName: 'Silero VAD',
              ),
            );
          },
        );
      }
      onProgress(
        RuntimeInitializationProgress(
          phase: RuntimeInitializationPhase.ready,
          completedBytes: totalBytes,
          totalBytes: totalBytes,
        ),
      );
    } on DownloadableModelException catch (error) {
      if (error.code == 'model.download.canceled') {
        throw const RuntimeInitializationException(
          code: 'runtime.download.paused',
          message: '下载已暂停，已完成的分片会保留',
        );
      }
      throw RuntimeInitializationException(
        code: error.code,
        message: error.message,
        cause: error,
      );
    } finally {
      if (identical(_activeCancellation, cancellation)) {
        _activeCancellation = null;
      }
    }
  }

  @override
  Future<void> grantMobileConsent() => consents.grant(resourceSetId);

  @override
  void pause() => _activeCancellation?.cancel();
}

RuntimeInitializationPhase _mapPhase(
  DownloadableModelPhase phase,
) => switch (phase) {
  DownloadableModelPhase.checking => RuntimeInitializationPhase.checking,
  DownloadableModelPhase.downloading => RuntimeInitializationPhase.downloading,
  DownloadableModelPhase.verifying => RuntimeInitializationPhase.verifying,
  DownloadableModelPhase.committing => RuntimeInitializationPhase.activating,
  DownloadableModelPhase.ready => RuntimeInitializationPhase.activating,
  DownloadableModelPhase.deleting => RuntimeInitializationPhase.failed,
};
