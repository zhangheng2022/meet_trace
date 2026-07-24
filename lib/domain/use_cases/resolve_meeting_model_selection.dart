import '../models/asr_model_registry.dart';
import '../models/domain_exception.dart';

final class MeetingModelSelection {
  const MeetingModelSelection({
    required this.requestedModelId,
    required this.recordingModelId,
    required this.recordingModelVersion,
    this.fallbackReason,
  });

  final String requestedModelId;
  final String recordingModelId;
  final String recordingModelVersion;
  final String? fallbackReason;
}

final class ResolveMeetingModelSelection {
  const ResolveMeetingModelSelection({required this.registry});

  final AsrModelRegistry registry;

  MeetingModelSelection call({
    required String globalDefaultModelId,
    String? meetingOverrideModelId,
    required Map<String, String> availableVersions,
    String? confirmedFallbackModelId,
    String? fallbackReason,
  }) {
    registry.requireById(globalDefaultModelId);
    final requestedModelId = meetingOverrideModelId ?? globalDefaultModelId;
    registry.requireById(requestedModelId);

    final requestedVersion = _availableVersion(
      requestedModelId,
      availableVersions,
    );
    if (requestedVersion != null) {
      if (confirmedFallbackModelId != null || fallbackReason != null) {
        throw const DomainInvariantViolation('请求模型可用时不能记录回退');
      }
      return MeetingModelSelection(
        requestedModelId: requestedModelId,
        recordingModelId: requestedModelId,
        recordingModelVersion: requestedVersion,
      );
    }

    if (confirmedFallbackModelId == null) {
      throw DomainInvariantViolation('请求模型不可用：$requestedModelId');
    }
    registry.requireById(confirmedFallbackModelId);
    final reason = fallbackReason?.trim();
    if (reason == null || reason.isEmpty) {
      throw const DomainInvariantViolation('显式模型回退必须记录用户确认原因');
    }
    final fallbackVersion = _availableVersion(
      confirmedFallbackModelId,
      availableVersions,
    );
    if (fallbackVersion == null) {
      throw DomainInvariantViolation('确认的回退模型不可用：$confirmedFallbackModelId');
    }

    return MeetingModelSelection(
      requestedModelId: requestedModelId,
      recordingModelId: confirmedFallbackModelId,
      recordingModelVersion: fallbackVersion,
      fallbackReason: reason,
    );
  }

  String? _availableVersion(
    String modelId,
    Map<String, String> availableVersions,
  ) {
    final version = availableVersions[modelId]?.trim();
    if (version == null || version.isEmpty) {
      return null;
    }
    final descriptor = registry.requireById(modelId);
    if (version != descriptor.version) {
      throw DomainInvariantViolation('可用模型版本与 Registry 不一致：$modelId@$version');
    }
    return version;
  }
}
