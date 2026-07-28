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
    required Map<String, String> availableVersions,
  }) {
    registry.requireById(globalDefaultModelId);
    final defaultVersion = _availableVersion(
      globalDefaultModelId,
      availableVersions,
    );
    if (defaultVersion == null) {
      throw DomainInvariantViolation('默认模型不可用：$globalDefaultModelId');
    }

    return MeetingModelSelection(
      requestedModelId: globalDefaultModelId,
      recordingModelId: globalDefaultModelId,
      recordingModelVersion: defaultVersion,
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
