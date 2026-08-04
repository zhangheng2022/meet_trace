enum TranscriptSnapshotKind { temporary, finalTranscript }

enum TranscriptSnapshotStatus { processing, complete, failed }

final class TranscriptSegment {
  TranscriptSegment({
    required this.id,
    required this.snapshotId,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.speakerId,
    this.confidence,
    required this.modelId,
    required this.modelVersion,
  }) {
    _requireText(id, 'id');
    _requireText(snapshotId, 'snapshotId');
    _requireText(text, 'text');
    _requireText(modelId, 'modelId');
    _requireText(modelVersion, 'modelVersion');
    if (startMs < 0 || endMs <= startMs) {
      throw ArgumentError('转录片段时间区间必须满足 0 <= startMs < endMs');
    }
    if (confidence != null && (confidence! < 0 || confidence! > 1)) {
      throw ArgumentError.value(confidence, 'confidence', '必须在 0 到 1 之间');
    }
  }

  final String id;
  final String snapshotId;
  final int startMs;
  final int endMs;
  final String text;
  final String? speakerId;
  final double? confidence;
  final String modelId;
  final String modelVersion;
}

sealed class TranscriptEvent {
  const TranscriptEvent();
}

final class TranscriptSegmentEvent extends TranscriptEvent {
  const TranscriptSegmentEvent({
    required this.segmentId,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.modelId,
    required this.modelVersion,
    required this.isFinalForWindow,
  });

  final String segmentId;
  final int startMs;
  final int endMs;
  final String text;
  final String modelId;
  final String modelVersion;
  final bool isFinalForWindow;
}

final class TranscriptSnapshot {
  TranscriptSnapshot({
    required this.id,
    required this.meetingId,
    required this.kind,
    required this.actualModelId,
    required this.actualModelVersion,
    required this.createdAt,
    required this.status,
    required List<TranscriptSegment> segments,
  }) : segments = List.unmodifiable(_sortedSegments(segments)) {
    _requireText(id, 'id');
    _requireText(meetingId, 'meetingId');
    _requireText(actualModelId, 'actualModelId');
    _requireText(actualModelVersion, 'actualModelVersion');

    final segmentIds = <String>{};
    for (final segment in this.segments) {
      if (segment.snapshotId != id) {
        throw ArgumentError('片段 ${segment.id} 的 snapshotId 不属于快照 $id');
      }
      if (segment.modelId != actualModelId ||
          segment.modelVersion != actualModelVersion) {
        throw ArgumentError('同一快照不能混合不同模型或版本的片段');
      }
      if (!segmentIds.add(segment.id)) {
        throw ArgumentError('同一快照不能包含重复片段 ID：${segment.id}');
      }
    }
  }

  final String id;
  final String meetingId;
  final TranscriptSnapshotKind kind;
  final String actualModelId;
  final String actualModelVersion;
  final DateTime createdAt;
  final TranscriptSnapshotStatus status;
  final List<TranscriptSegment> segments;

  bool isCurrentFinalTranscript({required String? activeSnapshotId}) {
    return kind == TranscriptSnapshotKind.finalTranscript &&
        status == TranscriptSnapshotStatus.complete &&
        activeSnapshotId == id;
  }
}

List<TranscriptSegment> _sortedSegments(List<TranscriptSegment> source) {
  final result = List<TranscriptSegment>.of(source);
  result.sort((left, right) {
    final byStart = left.startMs.compareTo(right.startMs);
    if (byStart != 0) {
      return byStart;
    }
    final byEnd = left.endMs.compareTo(right.endMs);
    if (byEnd != 0) {
      return byEnd;
    }
    return left.id.compareTo(right.id);
  });
  return result;
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, '不能为空');
  }
}
