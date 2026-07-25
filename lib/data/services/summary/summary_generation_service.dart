final class SummaryGenerationCapability {
  const SummaryGenerationCapability.available({
    required this.provider,
    required this.model,
  }) : isAvailable = true,
       reasonCode = null;

  const SummaryGenerationCapability.unavailable({required this.reasonCode})
    : isAvailable = false,
      provider = null,
      model = null;

  final bool isAvailable;
  final String? provider;
  final String? model;
  final String? reasonCode;
}

final class SummaryPromptSegment {
  SummaryPromptSegment({
    required this.id,
    required this.text,
    this.speakerLabel,
  }) {
    _requireText(id, 'id');
    _requireText(text, 'text');
  }

  final String id;
  final String text;
  final String? speakerLabel;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    if (speakerLabel?.trim().isNotEmpty == true)
      'speakerLabel': speakerLabel!.trim(),
  };
}

/// 发送给总结服务的最小请求。
///
/// 类型刻意不包含会议 ID、快照 ID、音频路径、音频字节和时间戳，避免未来
/// 的云端实现意外扩大上传范围。
final class SummaryGenerationRequest {
  SummaryGenerationRequest({required List<SummaryPromptSegment> segments})
    : segments = List.unmodifiable(segments) {
    if (this.segments.isEmpty) {
      throw ArgumentError.value(segments, 'segments', '不能为空');
    }
  }

  final List<SummaryPromptSegment> segments;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'segments': [for (final segment in segments) segment.toJson()],
  };
}

final class GeneratedSummaryItem {
  const GeneratedSummaryItem({
    required this.text,
    required this.evidenceSegmentIds,
  });

  final String text;
  final List<String> evidenceSegmentIds;
}

final class GeneratedSummaryDraft {
  GeneratedSummaryDraft({
    required this.overview,
    required List<GeneratedSummaryItem> keyPoints,
    required List<GeneratedSummaryItem> actionItems,
  }) : keyPoints = List.unmodifiable(keyPoints),
       actionItems = List.unmodifiable(actionItems) {
    _requireText(overview, 'overview');
    for (final item in [...this.keyPoints, ...this.actionItems]) {
      _requireText(item.text, 'item.text');
      for (final segmentId in item.evidenceSegmentIds) {
        _requireText(segmentId, 'evidenceSegmentId');
      }
    }
  }

  final String overview;
  final List<GeneratedSummaryItem> keyPoints;
  final List<GeneratedSummaryItem> actionItems;
}

abstract interface class SummaryGenerationService {
  SummaryGenerationCapability get capability;

  Future<GeneratedSummaryDraft> generate(SummaryGenerationRequest request);
}

final class SummaryGenerationServiceException implements Exception {
  const SummaryGenerationServiceException(this.code);

  final String code;
}

/// 当前 Alpha 未配置安全网关，生产环境显式关闭云端总结。
final class UnavailableSummaryGenerationService
    implements SummaryGenerationService {
  const UnavailableSummaryGenerationService();

  @override
  SummaryGenerationCapability get capability =>
      const SummaryGenerationCapability.unavailable(
        reasonCode: 'summary.gateway_unavailable',
      );

  @override
  Future<GeneratedSummaryDraft> generate(SummaryGenerationRequest request) {
    throw const SummaryGenerationServiceException(
      'summary.gateway_unavailable',
    );
  }
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, '不能为空');
  }
}
