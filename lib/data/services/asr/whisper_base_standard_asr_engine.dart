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
import 'whisper/whisper_adapter.dart';
import 'whisper/whisper_asr_engine.dart';

const whisperBaseSampleRate = whisperAsrSampleRate;
const whisperBaseMaximumWindowSeconds = whisperMaximumWindowSeconds;

final class WhisperBaseStandardAsrEngine implements AsrEngine {
  factory WhisperBaseStandardAsrEngine({
    required ModelInstallation installation,
    WhisperWorkerFactory workerFactory = const OfficialWhisperWorkerFactory(),
    DateTime Function()? now,
  }) {
    final descriptor = AsrModelRegistry.alpha.requireById(
      whisperBaseStandardModelId,
    );
    _validateModel(descriptor, installation);
    final modelRoot = installation.installedPath!;
    return WhisperBaseStandardAsrEngine._(
      WhisperAsrEngine(
        descriptor: descriptor,
        config: WhisperRecognizerConfig(
          modelId: descriptor.modelId,
          modelVersion: descriptor.version,
          modelPath: p.join(modelRoot, 'ggml-base-q5_1.bin'),
        ),
        errorPrefix: 'asr.whisper_base',
        workerFactory: workerFactory,
        now: now,
      ),
    );
  }

  const WhisperBaseStandardAsrEngine._(this._core);

  final WhisperAsrEngine _core;

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
    String? snapshotId,
  }) {
    return _core.finalizeMeeting(
      source,
      meetingId: meetingId,
      snapshotId: snapshotId,
    );
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
      descriptor.modelId == whisperBaseStandardModelId &&
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
        code: 'asr.whisper_base.model_not_verified',
        stage: FailureStage.modelVerification,
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        recoverability: FailureRecoverability.userActionRequired,
        userAction: FailureUserAction.downloadModel,
      ),
    );
  }
}
