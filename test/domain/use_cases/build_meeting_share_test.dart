import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/use_cases/build_meeting_share.dart';

void main() {
  test('纯文本分享只包含带时间戳和说话人的最终转录', () {
    final document = const BuildMeetingShareUseCase().execute(
      meeting: _meeting(),
      snapshot: _snapshot(),
      format: MeetingShareFormat.plainText,
    );

    expect(document.text, contains('最终转录'));
    expect(document.text, contains('会议时间：2026-07-25 09:30'));
    expect(document.text, contains('[00:00–00:01] 张三：确认周五发布'));
    expect(document.text, isNot(contains('AI')));
    expect(document.text, isNot(contains('/private/')));
    expect(document.text, isNot(contains('fact.pcm')));
    expect(document.text, isNot(contains('音频附件')));
  });

  test('Markdown 分享保留片段时间并明确不会附带原始音频', () {
    final document = const BuildMeetingShareUseCase().execute(
      meeting: _meeting(),
      snapshot: _snapshot(),
      format: MeetingShareFormat.markdown,
    );

    expect(document.text, startsWith('# 周会'));
    expect(document.text, contains('**会议时间**：2026-07-25 09:30'));
    expect(document.text, contains('00:00–00:01 · 张三'));
    expect(document.text, contains('不包含原始音频'));
  });
}

Meeting _meeting() => Meeting(
  id: 'meeting-1',
  title: '周会',
  createdAt: DateTime(2026, 7, 25, 9, 30),
  status: MeetingState.completed,
  audioPath: '/private/meetings/meeting-1/audio/fact.pcm',
  audioDurationMs: 1000,
  recordingModelId: 'paraformer',
  recordingModelVersion: '1',
  activeTranscriptSnapshotId: 'final-1',
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
