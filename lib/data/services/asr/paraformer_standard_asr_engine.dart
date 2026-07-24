import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../domain/models/app_failure.dart';
import '../../../domain/models/asr_model.dart';
import '../../../domain/models/asr_model_registry.dart';
import '../../../domain/models/audio_source.dart';
import '../../../domain/models/model_installation.dart';
import '../../../domain/models/transcript.dart';
import '../../../domain/models/workflow_states.dart';
import 'asr_engine.dart';
import 'sherpa_onnx/sherpa_onnx_adapter.dart';
import 'sherpa_onnx/sherpa_onnx_asr_engine.dart';

const paraformerSampleRate = sherpaOnnxAsrSampleRate;
const paraformerMaximumWindowSeconds = sherpaOnnxMaximumWindowSeconds;

final class ParaformerStandardAsrEngine implements AsrEngine {
  factory ParaformerStandardAsrEngine({
    required ModelInstallation installation,
    SherpaOnnxWorkerFactory workerFactory =
        const OfficialSherpaOnnxWorkerFactory(),
    DateTime Function()? now,
  }) {
    final descriptor = AsrModelRegistry.alpha.requireById(
      paraformerStandardModelId,
    );
    _validateModel(descriptor, installation);
    final modelRoot = installation.installedPath!;
    return ParaformerStandardAsrEngine._(
      SherpaOnnxAsrEngine(
        descriptor: descriptor,
        config: SherpaOnnxRecognizerConfig.paraformer(
          modelId: descriptor.modelId,
          modelVersion: descriptor.version,
          modelPath: p.join(modelRoot, 'model.int8.onnx'),
          tokensPath: p.join(modelRoot, 'tokens.txt'),
        ),
        errorPrefix: 'asr.paraformer',
        workerFactory: workerFactory,
        now: now,
      ),
    );
  }

  const ParaformerStandardAsrEngine._(this._core);

  final SherpaOnnxAsrEngine _core;

  @override
  AsrModelDescriptor get descriptor => _core.descriptor;

  @override
  Stream<TranscriptEvent> get events => _core.events;

  @override
  Stream<AsrFinalizationProgress> get finalizationProgress =>
      _core.finalizationProgress;

  @override
  AsrDeviceRiskState get deviceRisk => _core.deviceRisk;

  @override
  Stream<AsrDeviceRiskState> get deviceRisks => _core.deviceRisks;

  @override
  List<AsrWindowDiagnostic> get diagnostics => _core.diagnostics;

  @override
  AsrEngineMetrics get metrics => _core.metrics;

  @override
  Future<void> initialize() => _core.initialize();

  @override
  Future<void> acceptAudio(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  }) {
    return _core.acceptAudio(samples, sampleRate: sampleRate, startMs: startMs);
  }

  @override
  Future<TranscriptSnapshot> finalizeMeeting(
    AudioSource source, {
    required String meetingId,
  }) {
    return _core.finalizeMeeting(source, meetingId: meetingId);
  }

  @override
  void cancel() => _core.cancel();

  @override
  Future<void> dispose() => _core.dispose();
}

void _validateModel(
  AsrModelDescriptor descriptor,
  ModelInstallation installation,
) {
  final validDescriptor =
      descriptor.modelId == paraformerStandardModelId &&
      descriptor.tier == AsrModelTier.standard &&
      descriptor.installationType == AsrInstallationType.bundled;
  final validInstallation =
      installation.modelId == descriptor.modelId &&
      installation.version == descriptor.version &&
      installation.installationType == descriptor.installationType &&
      installation.state == ModelInstallationState.installed &&
      installation.verifiedAt != null &&
      installation.installedPath?.trim().isNotEmpty == true &&
      installation.bytes == descriptor.requiredBytes;
  if (!validDescriptor || !validInstallation) {
    throw AsrEngineException(
      AppFailure(
        code: 'asr.paraformer.model_not_verified',
        stage: FailureStage.modelVerification,
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        recoverability: FailureRecoverability.userActionRequired,
        userAction: FailureUserAction.downloadModel,
      ),
    );
  }
}
