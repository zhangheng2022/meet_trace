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

  test('英文分享使用本地化标签且保持转录原文', () {
    final document =
        BuildMeetingShareUseCase(
          copy: const MeetingShareCopy(
            untitledMeeting: 'Untitled meeting',
            meetingTimeLabel: 'Meeting time',
            finalTranscriptTitle: 'Final transcript',
            speakerFallback: 'Speaker 1',
            exportFooter: 'Exported locally by MeetTrace; original audio is not included.',
            labelSeparator: ': ',
          ),
          dateTimeFormatter: (_) => 'Jul 25, 2026, 9:30 AM',
        ).execute(
          meeting: _meeting(),
          snapshot: _snapshot(),
          format: MeetingShareFormat.plainText,
        );

    expect(document.text, contains('Final transcript'));
    expect(document.text, contains('Meeting time: Jul 25, 2026, 9:30 AM'));
    expect(document.text, contains('张三: 确认周五发布'));
    expect(document.text, isNot(contains('最终转录')));
  });

  test('英文 Markdown 分享使用本地化标签和标点', () {
    final document =
        BuildMeetingShareUseCase(
          copy: const MeetingShareCopy(
            untitledMeeting: 'Untitled meeting',
            meetingTimeLabel: 'Meeting time',
            finalTranscriptTitle: 'Final transcript',
            speakerFallback: 'Speaker 1',
            exportFooter: 'Exported locally by MeetTrace; original audio is not included.',
            labelSeparator: ': ',
          ),
          dateTimeFormatter: (_) => 'Jul 25, 2026, 9:30 AM',
        ).execute(
          meeting: _meeting(),
          snapshot: _snapshot(),
          format: MeetingShareFormat.markdown,
        );

    expect(document.text, contains('**Meeting time**: Jul 25, 2026'));
    expect(document.text, contains('张三**: 确认周五发布'));
    expect(document.text, contains('original audio is not included'));
  });

  test('英文分享使用本地化的缺失说话人标签', () {
    final document =
        BuildMeetingShareUseCase(
          copy: const MeetingShareCopy(
            untitledMeeting: 'Untitled meeting',
            meetingTimeLabel: 'Meeting time',
            finalTranscriptTitle: 'Final transcript',
            speakerFallback: 'Speaker 1',
            exportFooter: 'Exported locally by MeetTrace.',
            labelSeparator: ': ',
          ),
        ).execute(
          meeting: _meeting(),
          snapshot: _snapshot(speakerId: null),
          format: MeetingShareFormat.plainText,
        );

    expect(document.text, contains('Speaker 1: 确认周五发布'));
  });

  test('英文分享将自动说话人 ID 转为本地化标签', () {
    final document =
        BuildMeetingShareUseCase(
          copy: const MeetingShareCopy(
            untitledMeeting: 'Untitled meeting',
            meetingTimeLabel: 'Meeting time',
            finalTranscriptTitle: 'Final transcript',
            speakerFallback: 'Speaker 1',
            exportFooter: 'Exported locally by MeetTrace.',
            labelSeparator: ': ',
          ),
          speakerLabelBuilder: (number) => 'Speaker $number',
        ).execute(
          meeting: _meeting(),
          snapshot: _snapshot(speakerId: 'speaker-2'),
          format: MeetingShareFormat.plainText,
        );

    expect(document.text, contains('Speaker 2: 确认周五发布'));
    expect(document.text, isNot(contains('speaker-2')));
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

TranscriptSnapshot _snapshot({String? speakerId = '张三'}) => TranscriptSnapshot(
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
      speakerId: speakerId,
      modelId: 'paraformer',
      modelVersion: '1',
    ),
  ],
);
