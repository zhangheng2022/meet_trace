import '../models/runtime_initialization.dart';
import '../ports/runtime_asset_preparation.dart';

final class InitializeRuntimeAssetsUseCase {
  const InitializeRuntimeAssetsUseCase(this._preparation);

  final RuntimeAssetPreparationPort _preparation;

  Future<void> execute({
    required void Function(RuntimeInitializationProgress progress) onProgress,
    bool forceRepair = false,
  }) => _preparation.prepare(onProgress: onProgress, forceRepair: forceRepair);

  Future<void> grantMobileConsent() => _preparation.grantMobileConsent();

  void pause() => _preparation.pause();
}
