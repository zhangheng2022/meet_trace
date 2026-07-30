import '../../../domain/models/app_failure.dart';
import '../../../domain/models/asr_model.dart';
import '../../../domain/models/asr_model_registry.dart';
import '../../../domain/models/model_installation.dart';
import '../../../domain/models/workflow_states.dart';
import 'package:path/path.dart' as p;
import '../../repositories/repository_contracts.dart';
import 'asr_engine.dart';
import 'whisper_base_standard_asr_engine.dart';
import 'whisper_small_advanced_asr_engine.dart';
import 'whisper/whisper_adapter.dart';
import 'whisper/whisper_asr_engine.dart';
import 'whisper/whisper_recognizer_profiles.dart';
import '../vad/whisper_vad_segmenter.dart';

/// 只根据会议已经确认并锁定的模型 ID/版本组装具体 Engine。
///
/// Factory 不读取全局默认值、不做回退，也不持有任何 UI 状态。
final class WhisperAsrEngineFactory implements AsrEngineFactory {
  WhisperAsrEngineFactory({
    required this.installations,
    required this.leases,
    required this.riskMonitor,
    required this.ownerId,
    AsrModelRegistry? registry,
    this.workerFactory = const OfficialWhisperWorkerFactory(),
    DateTime Function()? now,
    this.leaseDuration = const Duration(hours: 1),
    this.leaseRenewalLead = const Duration(minutes: 5),
    this.leaseIdFactory,
  }) : registry = registry ?? AsrModelRegistry.alpha,
       now = now ?? DateTime.now {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', '不能为空');
    }
  }

  final ActiveModelInstallationRepository installations;
  final ModelUsageLeaseRepository leases;
  final AsrDeviceRiskMonitor riskMonitor;
  final String ownerId;
  final AsrModelRegistry registry;
  final WhisperWorkerFactory workerFactory;
  final DateTime Function() now;
  final Duration leaseDuration;
  final Duration leaseRenewalLead;
  final String Function()? leaseIdFactory;

  @override
  Future<AsrEngine> create({
    required String modelId,
    required String modelVersion,
    AsrEnginePurpose purpose = AsrEnginePurpose.finalTranscript,
  }) async {
    final descriptor = registry.findById(modelId);
    if (descriptor == null) {
      throw _failure(
        code: 'asr.factory.model_not_registered',
        modelId: modelId,
        modelVersion: modelVersion,
        action: FailureUserAction.chooseAnotherModel,
      );
    }
    if (modelVersion != descriptor.version) {
      throw _failure(
        code: 'asr.factory.version_mismatch',
        modelId: modelId,
        modelVersion: modelVersion,
        action: FailureUserAction.chooseAnotherModel,
        context: {'expectedVersion': descriptor.version},
      );
    }

    return switch (descriptor.tier) {
      AsrModelTier.standard => _createStandard(descriptor, purpose),
      AsrModelTier.advanced => _createAdvanced(descriptor, purpose),
    };
  }

  Future<AsrEngine> _createStandard(
    AsrModelDescriptor descriptor,
    AsrEnginePurpose purpose,
  ) async {
    final installation = await installations.get(
      modelId: descriptor.modelId,
      version: descriptor.version,
    );
    if (installation == null) {
      throw _failure(
        code: 'asr.whisper_base.model_not_verified',
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        action: FailureUserAction.reinstallApp,
      );
    }
    return WhisperBaseStandardAsrEngine(
      installation: installation,
      workerFactory: workerFactory,
      now: now,
      profile: _profileFor(purpose),
      finalVadFactory: _finalVadFactory(installation),
    );
  }

  Future<AsrEngine> _createAdvanced(
    AsrModelDescriptor descriptor,
    AsrEnginePurpose purpose,
  ) async {
    final standard = registry.requireById(whisperBaseStandardModelId);
    final standardInstallation = await installations.get(
      modelId: standard.modelId,
      version: standard.version,
    );
    if (!_isVerifiedInstallation(standard, standardInstallation)) {
      throw _failure(
        code: 'asr.factory.vad_model_not_verified',
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        action: FailureUserAction.reinstallApp,
      );
    }
    return WhisperSmallAdvancedAsrEngine.create(
      installations: installations,
      leases: leases,
      riskMonitor: riskMonitor,
      ownerId: ownerId,
      workerFactory: workerFactory,
      now: now,
      leaseDuration: leaseDuration,
      leaseRenewalLead: leaseRenewalLead,
      leaseIdFactory: leaseIdFactory,
      profile: _profileFor(purpose),
      finalVadFactory: _finalVadFactory(standardInstallation!),
    );
  }

  FinalVoiceActivitySegmenterFactory _finalVadFactory(
    ModelInstallation installation,
  ) {
    final root = installation.installedPath;
    if (root == null || root.trim().isEmpty) {
      throw _failure(
        code: 'asr.factory.vad_model_not_verified',
        modelId: installation.modelId,
        modelVersion: installation.version,
        action: FailureUserAction.reinstallApp,
      );
    }
    final modelPath = p.join(root, 'vad', 'ggml-silero-v6.2.0.bin');
    return () => WhisperVadSegmenter(modelPath: modelPath);
  }
}

bool _isVerifiedInstallation(
  AsrModelDescriptor descriptor,
  ModelInstallation? installation,
) {
  return installation != null &&
      installation.modelId == descriptor.modelId &&
      installation.version == descriptor.version &&
      installation.installationType == descriptor.installationType &&
      installation.state == ModelInstallationState.installed &&
      installation.verifiedAt != null &&
      installation.installedPath?.trim().isNotEmpty == true &&
      installation.bytes == descriptor.requiredBytes;
}

WhisperRecognizerProfile _profileFor(AsrEnginePurpose purpose) {
  return switch (purpose) {
    // Preview/Beam 候选必须先通过真实 20 段语料门槛；未通过前保持基线。
    AsrEnginePurpose.preview => whisperBaselineRecognizerProfile,
    AsrEnginePurpose.finalTranscript => whisperBaselineRecognizerProfile,
  };
}

AsrEngineException _failure({
  required String code,
  required String modelId,
  required String modelVersion,
  required FailureUserAction action,
  Map<String, Object?> context = const {},
}) {
  return AsrEngineException(
    AppFailure(
      code: code,
      stage: FailureStage.modelVerification,
      modelId: modelId,
      modelVersion: modelVersion,
      recoverability: FailureRecoverability.userActionRequired,
      userAction: action,
      diagnosticContext: context,
    ),
  );
}
