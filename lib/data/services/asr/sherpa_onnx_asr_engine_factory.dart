import '../../../domain/models/app_failure.dart';
import '../../../domain/models/asr_model.dart';
import '../../../domain/models/asr_model_registry.dart';
import '../../../domain/ports/asr_engine.dart';
import '../../../domain/ports/repositories.dart';
import 'sense_voice_asr_engine.dart';
import 'sherpa_onnx/sherpa_onnx_adapter.dart';
import '../vad/silero_vad_segmenter.dart';

/// 只根据会议已经确认并锁定的模型 ID/版本组装具体 Engine。
///
/// Factory 不读取全局默认值、不做回退，也不持有任何 UI 状态。
final class SherpaOnnxAsrEngineFactory implements AsrEngineFactory {
  SherpaOnnxAsrEngineFactory({
    required this.installations,
    required this.leases,
    required this.riskMonitor,
    required this.ownerId,
    AsrModelRegistry? registry,
    this.workerFactory = const OfficialSherpaOnnxWorkerFactory(),
    DateTime Function()? now,
    this.leaseDuration = const Duration(hours: 1),
    this.leaseRenewalLead = const Duration(minutes: 5),
    this.leaseIdFactory,
    this.vadModelPath,
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
  final SherpaOnnxWorkerFactory workerFactory;
  final DateTime Function() now;
  final Duration leaseDuration;
  final Duration leaseRenewalLead;
  final String Function()? leaseIdFactory;
  final String? vadModelPath;

  @override
  Future<AsrEngine> create({
    required String modelId,
    required String modelVersion,
    String language = 'auto',
    bool useInverseTextNormalization = true,
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
    if (language != descriptor.language ||
        useInverseTextNormalization != descriptor.useInverseTextNormalization) {
      throw _failure(
        code: 'asr.factory.configuration_mismatch',
        modelId: modelId,
        modelVersion: modelVersion,
        action: FailureUserAction.downloadModel,
      );
    }

    return _createSenseVoice(descriptor);
  }

  Future<AsrEngine> _createSenseVoice(AsrModelDescriptor descriptor) async {
    final installation = await installations.get(
      modelId: descriptor.modelId,
      version: descriptor.version,
    );
    if (installation == null) {
      throw _failure(
        code: 'asr.senseVoice.model_not_verified',
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        action: FailureUserAction.downloadModel,
      );
    }
    return SenseVoiceAsrEngine(
      installation: installation,
      workerFactory: workerFactory,
      finalVadFactory: vadModelPath == null
          ? null
          : () => SileroVadSegmenter.official(modelPath: vadModelPath!),
      now: now,
    );
  }
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
