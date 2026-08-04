enum FailureStage {
  recording,
  storage,
  modelDownload,
  modelVerification,
  asrInitialization,
  asrInference,
  finalTranscription,
  speakerDiarization,
}

enum FailureRecoverability { retryable, userActionRequired, unrecoverable }

enum FailureUserAction {
  none,
  retry,
  grantPermission,
  freeStorage,
  checkNetwork,
  downloadModel,
  chooseAnotherModel,
  reinstallApp,
}

final class AppFailure {
  AppFailure({
    required this.code,
    required this.stage,
    this.modelId,
    this.modelVersion,
    required this.recoverability,
    required this.userAction,
    Map<String, Object?> diagnosticContext = const {},
  }) : diagnosticContext = Map.unmodifiable(diagnosticContext) {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(code, 'code', '不能为空');
    }
  }

  final String code;
  final FailureStage stage;
  final String? modelId;
  final String? modelVersion;
  final FailureRecoverability recoverability;
  final FailureUserAction userAction;
  final Map<String, Object?> diagnosticContext;
}
