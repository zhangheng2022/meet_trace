import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/domain/models/summary.dart';

void main() {
  test('没有证据的总结项自动标记为待核对', () {
    final item = SummaryItem(id: 'item-1', text: '确认上线时间');

    expect(item.isPendingReview, true);
  });

  test('证据区间必须有效且总结集合不可变', () {
    expect(
      () => SummaryEvidence(
        segmentId: 'segment-1',
        startMs: 1000,
        endMs: 1000,
        quote: '证据',
      ),
      throwsArgumentError,
    );

    final keyPoints = [
      SummaryItem(
        id: 'item-1',
        text: '结论',
        evidence: [
          SummaryEvidence(
            segmentId: 'segment-1',
            startMs: 0,
            endMs: 1000,
            quote: '原文',
          ),
        ],
      ),
    ];
    final summary = Summary(
      id: 'summary-1',
      meetingId: 'meeting-1',
      transcriptSnapshotId: 'snapshot-1',
      provider: 'local',
      model: 'test',
      createdAt: DateTime.utc(2026, 7, 24),
      overview: '概览',
      keyPoints: keyPoints,
      actionItems: const [],
      status: SummaryStatus.complete,
    );

    keyPoints.clear();

    expect(summary.keyPoints, hasLength(1));
    expect(summary.keyPoints.single.isPendingReview, false);
    expect(() => summary.keyPoints.clear(), throwsUnsupportedError);
  });
}
