import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../domain/models/app_failure.dart';
import '../../../domain/models/asr_model.dart';
import '../../../domain/models/asr_model_registry.dart';
import '../../../domain/models/audio_source.dart';
import '../../../domain/models/model_installation.dart';
import '../../../domain/models/model_usage_lease.dart';
import '../../../domain/models/transcript.dart';
import '../../../domain/models/workflow_states.dart';
import '../../repositories/repository_contracts.dart';
import 'asr_engine.dart';
import 'whisper/whisper_adapter.dart';
import 'whisper/whisper_asr_engine.dart';

const whisperSmallSampleRate = whisperAsrSampleRate;
const whisperSmallMaximumWindowSeconds = whisperMaximumWindowSeconds;

final class WhisperSmallAdvancedAsrEngine implements AsrEngine {
  static Future<WhisperSmallAdvancedAsrEngine> create({
    required ActiveModelInstallationRepository installations,
    required ModelUsageLeaseRepository leases,
    required AsrDeviceRiskMonitor riskMonitor,
    required String ownerId,
    WhisperWorkerFactory workerFactory = const OfficialWhisperWorkerFactory(),
    DateTime Function()? now,
    Duration leaseDuration = const Duration(hours: 1),
    Duration leaseRenewalLead = const Duration(minutes: 5),
    String Function()? leaseIdFactory,
  }) async {
    final descriptor = AsrModelRegistry.alpha.requireById(
      whisperSmallAdvancedModelId,
    );
    final clock = now ?? DateTime.now;
    _validateCreationArguments(
      ownerId: ownerId,
      leaseDuration: leaseDuration,
      leaseRenewalLead: leaseRenewalLead,
    );

    try {
      final activeVersion = await installations.getActiveVersion(
        descriptor.modelId,
      );
      if (activeVersion != descriptor.version) {
        throw _failure(
          descriptor: descriptor,
          code: 'asr.whisper_small.model_not_active',
          stage: FailureStage.modelVerification,
          action: FailureUserAction.downloadModel,
          context: {'activeVersion': activeVersion},
        );
      }
      final installation = await installations.get(
        modelId: descriptor.modelId,
        version: descriptor.version,
      );
      if (!_isVerifiedInstallation(descriptor, installation)) {
        throw _failure(
          descriptor: descriptor,
          code: 'asr.whisper_small.model_not_verified',
          stage: FailureStage.modelVerification,
          action: FailureUserAction.downloadModel,
        );
      }

      final current = clock();
      final activeLeases = await leases.listActive(
        modelId: descriptor.modelId,
        version: descriptor.version,
        now: current,
      );
      final conflictingOwners = activeLeases
          .where((lease) => lease.ownerId == ownerId)
          .map((lease) => lease.leaseId)
          .toList(growable: false);
      if (conflictingOwners.isNotEmpty) {
        throw _failure(
          descriptor: descriptor,
          code: 'asr.whisper_small.lease_conflict',
          stage: FailureStage.asrInitialization,
          action: FailureUserAction.retry,
          recoverability: FailureRecoverability.retryable,
          context: {'conflictingLeaseIds': conflictingOwners.join(',')},
        );
      }

      var lease = ModelUsageLease(
        leaseId:
            leaseIdFactory?.call() ??
            'whisper-small-$ownerId-${current.microsecondsSinceEpoch}',
        modelId: descriptor.modelId,
        version: descriptor.version,
        ownerId: ownerId,
        acquiredAt: current,
        expiresAt: current.add(leaseDuration),
      );
      await leases.save(lease);

      Future<void> ensureLease() async {
        final operationTime = clock();
        if (!lease.isActiveAt(operationTime)) {
          throw _failure(
            descriptor: descriptor,
            code: 'asr.whisper_small.lease_expired',
            stage: FailureStage.asrInitialization,
            action: FailureUserAction.retry,
            recoverability: FailureRecoverability.retryable,
          );
        }
        if (lease.expiresAt.difference(operationTime) > leaseRenewalLead) {
          return;
        }
        final renewed = lease.renew(
          renewedAt: operationTime,
          expiresAt: operationTime.add(leaseDuration),
        );
        try {
          await leases.save(renewed);
          lease = renewed;
        } on Object catch (error) {
          throw _failure(
            descriptor: descriptor,
            code: 'asr.whisper_small.lease_renewal_failed',
            stage: FailureStage.asrInitialization,
            action: FailureUserAction.retry,
            recoverability: FailureRecoverability.retryable,
            context: {'errorType': error.runtimeType.toString()},
          );
        }
      }

      Future<void> releaseLease() async {
        try {
          await leases.release(lease.leaseId);
        } on Object catch (error) {
          throw _failure(
            descriptor: descriptor,
            code: 'asr.whisper_small.lease_release_failed',
            stage: FailureStage.asrInitialization,
            action: FailureUserAction.retry,
            recoverability: FailureRecoverability.retryable,
            context: {'errorType': error.runtimeType.toString()},
          );
        }
      }

      final modelRoot = installation!.installedPath!;
      try {
        return WhisperSmallAdvancedAsrEngine._(
          WhisperAsrEngine(
            descriptor: descriptor,
            config: WhisperRecognizerConfig(
              modelId: descriptor.modelId,
              modelVersion: descriptor.version,
              modelPath: p.join(modelRoot, 'ggml-small-q5_1.bin'),
            ),
            errorPrefix: 'asr.whisper_small',
            workerFactory: workerFactory,
            riskMonitor: riskMonitor,
            beforeOperation: ensureLease,
            onDispose: releaseLease,
            now: clock,
          ),
        );
      } on Object {
        await leases.release(lease.leaseId);
        rethrow;
      }
    } on AsrEngineException {
      rethrow;
    } on Object catch (error) {
      throw _failure(
        descriptor: descriptor,
        code: 'asr.whisper_small.lifecycle_failed',
        stage: FailureStage.asrInitialization,
        action: FailureUserAction.retry,
        recoverability: FailureRecoverability.retryable,
        context: {'errorType': error.runtimeType.toString()},
      );
    }
  }

  const WhisperSmallAdvancedAsrEngine._(this._core);

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

void _validateCreationArguments({
  required String ownerId,
  required Duration leaseDuration,
  required Duration leaseRenewalLead,
}) {
  if (ownerId.trim().isEmpty) {
    throw ArgumentError.value(ownerId, 'ownerId', '不能为空');
  }
  if (leaseDuration <= Duration.zero) {
    throw ArgumentError.value(leaseDuration, 'leaseDuration', '必须大于 0');
  }
  if (leaseRenewalLead < Duration.zero || leaseRenewalLead >= leaseDuration) {
    throw ArgumentError.value(
      leaseRenewalLead,
      'leaseRenewalLead',
      '必须非负且小于租约时长',
    );
  }
}

bool _isVerifiedInstallation(
  AsrModelDescriptor descriptor,
  ModelInstallation? installation,
) {
  return descriptor.modelId == whisperSmallAdvancedModelId &&
      descriptor.tier == AsrModelTier.advanced &&
      descriptor.installationType == AsrInstallationType.downloadable &&
      installation?.modelId == descriptor.modelId &&
      installation?.version == descriptor.version &&
      installation?.installationType == descriptor.installationType &&
      installation?.state == ModelInstallationState.installed &&
      installation?.verifiedAt != null &&
      installation?.installedPath?.trim().isNotEmpty == true &&
      installation?.bytes == descriptor.requiredBytes;
}

AsrEngineException _failure({
  required AsrModelDescriptor descriptor,
  required String code,
  required FailureStage stage,
  required FailureUserAction action,
  FailureRecoverability recoverability =
      FailureRecoverability.userActionRequired,
  Map<String, Object?> context = const {},
}) {
  return AsrEngineException(
    AppFailure(
      code: code,
      stage: stage,
      modelId: descriptor.modelId,
      modelVersion: descriptor.version,
      recoverability: recoverability,
      userAction: action,
      diagnosticContext: context,
    ),
  );
}
