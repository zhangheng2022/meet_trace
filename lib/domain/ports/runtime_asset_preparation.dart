import '../models/runtime_initialization.dart';

abstract interface class RuntimeAssetPreparationPort {
  Future<void> prepare({
    required void Function(RuntimeInitializationProgress progress) onProgress,
    bool forceRepair = false,
  });

  Future<void> grantMobileConsent();

  void pause();
}

abstract interface class RuntimeDownloadConsentRepository {
  Future<bool> hasConsent(String resourceSetId);

  Future<void> grant(String resourceSetId);
}
