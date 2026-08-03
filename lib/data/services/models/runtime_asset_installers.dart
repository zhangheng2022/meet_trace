import '../../../domain/models/asr_model.dart';
import '../../../domain/models/model_manifest.dart';
import '../../models/runtime/silero_vad_manifest.dart';
import 'model_download_types.dart';

abstract interface class RuntimeAsrModelInstaller {
  Future<bool> isReadyFast({
    required AsrModelDescriptor descriptor,
    required ModelManifestEntry manifest,
  });

  Future<DownloadableModelResult> download({
    required AsrModelDescriptor descriptor,
    required ModelManifestEntry manifest,
    bool allowMeteredNetwork = false,
    ModelDownloadCancellationToken? cancellation,
    DownloadableModelProgressCallback? onProgress,
    bool skipPreflight = false,
    bool forceDownload = false,
  });
}

abstract interface class RuntimeVadInstaller {
  Future<bool> isReadyFast(SileroVadManifest manifest);

  Future<String> prepare({
    required SileroVadManifest manifest,
    required ModelDownloadCancellationToken cancellation,
    void Function(int completedBytes, int totalBytes)? onProgress,
  });
}
