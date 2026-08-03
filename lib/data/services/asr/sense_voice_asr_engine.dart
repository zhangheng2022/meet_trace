import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../domain/models/app_failure.dart';
import '../../../domain/models/asr_model.dart';
import '../../../domain/models/asr_model_registry.dart';
import '../../../domain/models/audio_source.dart';
import '../../../domain/models/model_installation.dart';
import '../../../domain/models/transcript.dart';
import '../../../domain/models/workflow_states.dart';
import '../../../domain/ports/asr_engine.dart';
import 'sherpa_onnx/sherpa_onnx_adapter.dart';
import 'sherpa_onnx/sherpa_onnx_asr_engine.dart';

final class SenseVoiceAsrEngine implements AsrEngine {
  factory SenseVoiceAsrEngine({
    required ModelInstallation installation,
    SherpaOnnxWorkerFactory workerFactory =
        const OfficialSherpaOnnxWorkerFactory(),
    DateTime Function()? now,
  }) {
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    _validateSenseVoice(descriptor, installation);
    final root = installation.installedPath!;
    return SenseVoiceAsrEngine._(
      SherpaOnnxAsrEngine(
        descriptor: descriptor,
        config: SherpaOnnxRecognizerConfig.senseVoice(
          modelId: descriptor.modelId,
          modelVersion: descriptor.version,
          modelPath: p.join(root, 'model.int8.onnx'),
          tokensPath: p.join(root, 'tokens.txt'),
          language: descriptor.language,
          useInverseTextNormalization: descriptor.useInverseTextNormalization,
        ),
        errorPrefix: 'asr.senseVoice',
        workerFactory: workerFactory,
        now: now,
      ),
    );
  }

  const SenseVoiceAsrEngine._(this._core);

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
  }) => _core.acceptAudio(samples, sampleRate: sampleRate, startMs: startMs);
  @override
  Future<TranscriptSnapshot> finalizeMeeting(
    AudioSource source, {
    required String meetingId,
    String? snapshotId,
  }) => _core.finalizeMeeting(
    source,
    meetingId: meetingId,
    snapshotId: snapshotId,
  );
  @override
  void cancel() => _core.cancel();
  @override
  Future<void> dispose() => _core.dispose();
}

void _validateSenseVoice(
  AsrModelDescriptor descriptor,
  ModelInstallation installation,
) {
  final valid =
      descriptor.modelId == senseVoiceDefaultModelId &&
      descriptor.installationType == AsrInstallationType.downloadable &&
      descriptor.language == 'auto' &&
      descriptor.useInverseTextNormalization &&
      installation.modelId == descriptor.modelId &&
      installation.version == descriptor.version &&
      installation.installationType == descriptor.installationType &&
      installation.state == ModelInstallationState.installed &&
      installation.verifiedAt != null &&
      installation.installedPath?.trim().isNotEmpty == true &&
      installation.bytes == descriptor.requiredBytes;
  if (!valid) {
    throw AsrEngineException(
      AppFailure(
        code: 'asr.senseVoice.model_not_verified',
        stage: FailureStage.modelVerification,
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        recoverability: FailureRecoverability.userActionRequired,
        userAction: FailureUserAction.downloadModel,
      ),
    );
  }
}
