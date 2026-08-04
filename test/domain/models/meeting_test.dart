import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/domain_exception.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';

void main() {
  group('Meeting 模型锁定', () {
    test('录音开始后不能修改实际模型或版本', () {
      final recording = _meeting().startRecording(
        startedAt: DateTime.utc(2026, 7, 24, 3),
      );

      expect(
        () => recording.changeRecordingModel(
          recordingModelId: 'qwen',
          recordingModelVersion: '2',
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('录音开始前可以更改实际模型与版本', () {
      final meeting = _meeting();

      final updated = meeting.changeRecordingModel(
        recordingModelId: 'qwen',
        recordingModelVersion: '2',
      );

      expect(updated.recordingModelId, 'qwen');
      expect(updated.recordingModelVersion, '2');
    });
  });

  group('最终快照激活', () {
    test('完成的最终快照可以成为活动快照', () {
      final meeting = _meeting(
        status: MeetingState.processing,
        activeTranscriptSnapshotId: 'old',
      );
      final snapshot = _snapshot(
        id: 'new',
        status: TranscriptSnapshotStatus.complete,
      );

      final updated = meeting.activateFinalTranscript(snapshot);

      expect(updated.activeTranscriptSnapshotId, 'new');
      expect(updated.status, MeetingState.completed);
      expect(meeting.activeTranscriptSnapshotId, 'old');
    });

    test('新最终快照失败时旧活动快照保持不变', () {
      final meeting = _meeting(
        status: MeetingState.processing,
        activeTranscriptSnapshotId: 'old',
      );
      final failed = _snapshot(
        id: 'failed',
        status: TranscriptSnapshotStatus.failed,
      );

      expect(
        () => meeting.activateFinalTranscript(failed),
        throwsA(isA<DomainInvariantViolation>()),
      );
      expect(meeting.activeTranscriptSnapshotId, 'old');
    });
  });

  test('重新转录进入 processing 时保留旧快照和事实音频', () {
    final meeting = Meeting(
      id: 'meeting-1',
      title: '周会',
      createdAt: DateTime.utc(2026, 7, 24),
      startedAt: DateTime.utc(2026, 7, 24, 3),
      endedAt: DateTime.utc(2026, 7, 24, 3, 30),
      status: MeetingState.completed,
      audioPath: '/private/meetings/meeting-1/audio/fact.pcm',
      audioDurationMs: 1800000,
      recordingModelId: 'paraformer',
      recordingModelVersion: '1',
      activeTranscriptSnapshotId: 'old',
    );

    final processing = meeting.beginFinalTranscription();

    expect(processing.status, MeetingState.processing);
    expect(processing.activeTranscriptSnapshotId, 'old');
    expect(processing.audioPath, meeting.audioPath);
  });

  test('会议标题由本地开始时间确定生成并补齐两位数字', () {
    expect(
      meetingTitleForStartTime(DateTime(2026, 8, 3, 9, 5)),
      '2026-08-03 09:05 会议',
    );
  });

  test('事实音频封存后记录结束时间、路径和时长并进入待处理', () {
    final recording = _meeting().startRecording(
      startedAt: DateTime.utc(2026, 7, 24, 3),
    );

    final completed = recording.finishRecording(
      endedAt: DateTime.utc(2026, 7, 24, 3, 30),
      audioPath: '/private/meetings/meeting-1/audio/fact.pcm',
      audioDurationMs: 1800000,
    );

    expect(completed.status, MeetingState.processing);
    expect(completed.endedAt, DateTime.utc(2026, 7, 24, 3, 30));
    expect(completed.audioPath, '/private/meetings/meeting-1/audio/fact.pcm');
    expect(completed.audioDurationMs, 1800000);
  });

  test('录音失败时记录稳定错误码和结束时间', () {
    final recording = _meeting().startRecording(
      startedAt: DateTime.utc(2026, 7, 24, 3),
    );

    final failed = recording.fail(
      errorCode: 'recording.permission_denied',
      endedAt: DateTime.utc(2026, 7, 24, 3, 1),
    );

    expect(failed.status, MeetingState.failed);
    expect(failed.lastErrorCode, 'recording.permission_denied');
    expect(failed.endedAt, DateTime.utc(2026, 7, 24, 3, 1));
  });
}

Meeting _meeting({
  String recordingModelId = 'paraformer',
  String? activeTranscriptSnapshotId,
  MeetingState status = MeetingState.created,
}) {
  return Meeting(
    id: 'meeting-1',
    title: '周会',
    createdAt: DateTime.utc(2026, 7, 24),
    status: status,
    audioDurationMs: 0,
    recordingModelId: recordingModelId,
    recordingModelVersion: '1',
    activeTranscriptSnapshotId: activeTranscriptSnapshotId,
  );
}

TranscriptSnapshot _snapshot({
  required String id,
  required TranscriptSnapshotStatus status,
}) {
  return TranscriptSnapshot(
    id: id,
    meetingId: 'meeting-1',
    kind: TranscriptSnapshotKind.finalTranscript,
    actualModelId: 'paraformer',
    actualModelVersion: '1',
    createdAt: DateTime.utc(2026, 7, 24, 4),
    status: status,
    segments: const [],
  );
}
