import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
import 'package:meetily_ai/domain/models/summary.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:meetily_ai/domain/use_cases/build_meeting_share.dart';

void main() {
  test('纯文本分享包含最终转录和 AI 标识但不含音频或本地路径', () {
    final document = const BuildMeetingShareUseCase().execute(
      meeting: _meeting(),
      snapshot: _snapshot(),
      summary: _summary(),
      format: MeetingShareFormat.plainText,
    );

    expect(document.text, contains('最终转录'));
    expect(document.text, contains('AI 生成总结'));
    expect(document.text, contains('待核对'));
    expect(document.text, isNot(contains('/private/')));
    expect(document.text, isNot(contains('fact.pcm')));
    expect(document.text, isNot(contains('音频附件')));
  });

  test('Markdown 分享保留证据时间并明确不会附带原始音频', () {
    final document = const BuildMeetingShareUseCase().execute(
      meeting: _meeting(),
      snapshot: _snapshot(),
      summary: _summary(),
      format: MeetingShareFormat.markdown,
    );

    expect(document.text, startsWith('# 周会'));
    expect(document.text, contains('证据 00:00–00:01'));
    expect(document.text, contains('不包含原始音频'));
    expect(document.fileName, endsWith('.md'));
  });
}

Meeting _meeting() => Meeting(
  id: 'meeting-1',
  title: '周会',
  createdAt: DateTime.utc(2026, 7, 25),
  status: MeetingState.completed,
  audioPath: '/private/meetings/meeting-1/audio/fact.pcm',
  audioDurationMs: 1000,
  requestedModelId: 'paraformer',
  recordingModelId: 'paraformer',
  recordingModelVersion: '1',
  activeTranscriptSnapshotId: 'final-1',
  activeSummaryId: 'summary-1',
);

TranscriptSnapshot _snapshot() => TranscriptSnapshot(
  id: 'final-1',
  meetingId: 'meeting-1',
  kind: TranscriptSnapshotKind.finalTranscript,
  actualModelId: 'paraformer',
  actualModelVersion: '1',
  createdAt: DateTime.utc(2026, 7, 25),
  status: TranscriptSnapshotStatus.complete,
  segments: [
    TranscriptSegment(
      id: 'segment-1',
      snapshotId: 'final-1',
      startMs: 0,
      endMs: 1000,
      text: '确认周五发布',
      speakerId: '张三',
      modelId: 'paraformer',
      modelVersion: '1',
    ),
  ],
);

Summary _summary() => Summary(
  id: 'summary-1',
  meetingId: 'meeting-1',
  transcriptSnapshotId: 'final-1',
  provider: 'test',
  model: 'test',
  createdAt: DateTime.utc(2026, 7, 25),
  overview: '项目按计划推进',
  keyPoints: [
    SummaryItem(
      id: 'point-1',
      text: '周五发布',
      evidence: [
        SummaryEvidence(
          segmentId: 'segment-1',
          startMs: 0,
          endMs: 1000,
          quote: '确认周五发布',
        ),
      ],
    ),
  ],
  actionItems: [SummaryItem(id: 'action-1', text: '待确定负责人')],
  status: SummaryStatus.complete,
);
