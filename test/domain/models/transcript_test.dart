import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/transcript.dart';

void main() {
  group('TranscriptSegment', () {
    test('拒绝倒序或零长度时间区间', () {
      expect(() => _segment(startMs: 1000, endMs: 1000), throwsArgumentError);
      expect(() => _segment(startMs: 2000, endMs: 1000), throwsArgumentError);
    });
  });

  group('TranscriptSnapshot', () {
    test('临时快照不能作为总结输入', () {
      final snapshot = _snapshot(
        kind: TranscriptSnapshotKind.temporary,
        status: TranscriptSnapshotStatus.complete,
      );

      expect(
        snapshot.isEligibleForSummary(activeSnapshotId: snapshot.id),
        false,
      );
    });

    test('只有已完成且当前激活的最终快照能作为总结输入', () {
      final snapshot = _snapshot(
        kind: TranscriptSnapshotKind.finalTranscript,
        status: TranscriptSnapshotStatus.complete,
      );

      expect(
        snapshot.isEligibleForSummary(activeSnapshotId: snapshot.id),
        true,
      );
      expect(snapshot.isEligibleForSummary(activeSnapshotId: 'other'), false);
    });

    test('拒绝混入其他快照或其他模型的片段', () {
      expect(
        () => _snapshot(
          kind: TranscriptSnapshotKind.finalTranscript,
          status: TranscriptSnapshotStatus.complete,
          segments: [_segment(snapshotId: 'other')],
        ),
        throwsArgumentError,
      );
      expect(
        () => _snapshot(
          kind: TranscriptSnapshotKind.finalTranscript,
          status: TranscriptSnapshotStatus.complete,
          segments: [_segment(modelId: 'qwen')],
        ),
        throwsArgumentError,
      );
    });
  });
}

TranscriptSegment _segment({
  String snapshotId = 'snapshot-1',
  int startMs = 0,
  int endMs = 1000,
  String modelId = 'paraformer',
}) {
  return TranscriptSegment(
    id: 'segment-1',
    snapshotId: snapshotId,
    startMs: startMs,
    endMs: endMs,
    text: '测试',
    modelId: modelId,
    modelVersion: '1',
  );
}

TranscriptSnapshot _snapshot({
  required TranscriptSnapshotKind kind,
  required TranscriptSnapshotStatus status,
  List<TranscriptSegment> segments = const [],
}) {
  return TranscriptSnapshot(
    id: 'snapshot-1',
    meetingId: 'meeting-1',
    kind: kind,
    actualModelId: 'paraformer',
    actualModelVersion: '1',
    createdAt: DateTime.utc(2026, 7, 24),
    status: status,
    segments: segments,
  );
}
