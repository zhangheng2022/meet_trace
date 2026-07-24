import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../../domain/models/app_failure.dart';

abstract interface class SherpaOnnxBindings {
  void initialize();
}

final class OfficialSherpaOnnxBindings implements SherpaOnnxBindings {
  const OfficialSherpaOnnxBindings();

  @override
  void initialize() {
    sherpa.initBindings();
  }
}

final class SherpaOnnxRuntimeStatus {
  const SherpaOnnxRuntimeStatus._({required this.isReady, this.failure});

  const SherpaOnnxRuntimeStatus.ready() : this._(isReady: true);

  const SherpaOnnxRuntimeStatus.failed(AppFailure failure)
    : this._(isReady: false, failure: failure);

  final bool isReady;
  final AppFailure? failure;
}

final class SherpaOnnxRuntimeInitializer {
  factory SherpaOnnxRuntimeInitializer({required SherpaOnnxBindings bindings}) {
    return SherpaOnnxRuntimeInitializer._(bindings);
  }

  SherpaOnnxRuntimeInitializer._(this._bindings);

  final SherpaOnnxBindings _bindings;
  SherpaOnnxRuntimeStatus? _status;

  SherpaOnnxRuntimeStatus initialize() {
    final existing = _status;
    if (existing != null) {
      return existing;
    }

    try {
      _bindings.initialize();
      return _status = const SherpaOnnxRuntimeStatus.ready();
    } on Object catch (error) {
      return _status = SherpaOnnxRuntimeStatus.failed(
        AppFailure(
          code: 'asr.official.bindings_initialization_failed',
          stage: FailureStage.asrInitialization,
          recoverability: FailureRecoverability.retryable,
          userAction: FailureUserAction.retry,
          diagnosticContext: {'errorType': error.runtimeType.toString()},
        ),
      );
    }
  }
}

final sherpaOnnxRuntimeInitializer = SherpaOnnxRuntimeInitializer(
  bindings: const OfficialSherpaOnnxBindings(),
);
