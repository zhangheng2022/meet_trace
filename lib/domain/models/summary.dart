enum SummaryStatus { processing, complete, failed, stale }

final class SummaryEvidence {
  SummaryEvidence({
    required this.segmentId,
    required this.startMs,
    required this.endMs,
    required this.quote,
  }) {
    _requireText(segmentId, 'segmentId');
    _requireText(quote, 'quote');
    if (startMs < 0 || endMs <= startMs) {
      throw ArgumentError('总结证据时间区间必须满足 0 <= startMs < endMs');
    }
  }

  final String segmentId;
  final int startMs;
  final int endMs;
  final String quote;
}

final class SummaryItem {
  SummaryItem({
    required this.id,
    required this.text,
    List<SummaryEvidence> evidence = const [],
  }) : evidence = List.unmodifiable(evidence) {
    _requireText(id, 'id');
    _requireText(text, 'text');
  }

  final String id;
  final String text;
  final List<SummaryEvidence> evidence;

  bool get isPendingReview => evidence.isEmpty;
}

final class Summary {
  Summary({
    required this.id,
    required this.meetingId,
    required this.transcriptSnapshotId,
    required this.provider,
    required this.model,
    required this.createdAt,
    required this.overview,
    required List<SummaryItem> keyPoints,
    required List<SummaryItem> actionItems,
    required this.status,
  }) : keyPoints = List.unmodifiable(keyPoints),
       actionItems = List.unmodifiable(actionItems) {
    _requireText(id, 'id');
    _requireText(meetingId, 'meetingId');
    _requireText(transcriptSnapshotId, 'transcriptSnapshotId');
    _requireText(provider, 'provider');
    _requireText(model, 'model');
  }

  final String id;
  final String meetingId;
  final String transcriptSnapshotId;
  final String provider;
  final String model;
  final DateTime createdAt;
  final String overview;
  final List<SummaryItem> keyPoints;
  final List<SummaryItem> actionItems;
  final SummaryStatus status;
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, '不能为空');
  }
}
