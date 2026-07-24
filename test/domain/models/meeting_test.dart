import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/domain/models/domain_exception.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';

void main() {
  group('Meeting 模型锁定', () {
    test('请求模型与实际模型不同时必须记录显式回退原因', () {
      expect(
        () =>
            _meeting(requestedModelId: 'qwen', recordingModelId: 'paraformer'),
        throwsArgumentError,
      );

      final meeting = _meeting(
        requestedModelId: 'qwen',
        recordingModelId: 'paraformer',
        modelFallbackReason: '高级模型未安装，用户确认改用标准模型',
      );

      expect(meeting.requestedModelId, 'qwen');
      expect(meeting.recordingModelId, 'paraformer');
      expect(meeting.modelFallbackReason, isNotEmpty);
    });

    test('录音开始后不能修改实际模型或版本', () {
      final recording = _meeting().startRecording(
        startedAt: DateTime.utc(2026, 7, 24, 3),
      );

      expect(
        () => recording.changeRecordingModel(
          recordingModelId: 'qwen',
          recordingModelVersion: '2',
          fallbackReason: '用户确认',
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('录音开始前改回请求模型会清除回退原因', () {
      final meeting = _meeting(
        requestedModelId: 'qwen',
        recordingModelId: 'paraformer',
        modelFallbackReason: '用户确认回退',
      );

      final updated = meeting.changeRecordingModel(
        recordingModelId: 'qwen',
        recordingModelVersion: '1',
      );

      expect(updated.modelFallbackReason, isNull);
    });
  });

  group('最终快照激活', () {
    test('完成的最终快照可以成为活动快照', () {
      final meeting = _meeting(
        activeTranscriptSnapshotId: 'old',
        activeSummaryId: 'old-summary',
      );
      final snapshot = _snapshot(
        id: 'new',
        status: TranscriptSnapshotStatus.complete,
      );

      final updated = meeting.activateFinalTranscript(snapshot);

      expect(updated.activeTranscriptSnapshotId, 'new');
      expect(updated.activeSummaryId, isNull);
      expect(meeting.activeTranscriptSnapshotId, 'old');
    });

    test('新最终快照失败时旧活动快照保持不变', () {
      final meeting = _meeting(activeTranscriptSnapshotId: 'old');
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
  String requestedModelId = 'paraformer',
  String recordingModelId = 'paraformer',
  String? modelFallbackReason,
  String? activeTranscriptSnapshotId,
  String? activeSummaryId,
}) {
  return Meeting(
    id: 'meeting-1',
    title: '周会',
    createdAt: DateTime.utc(2026, 7, 24),
    status: MeetingState.created,
    audioDurationMs: 0,
    requestedModelId: requestedModelId,
    recordingModelId: recordingModelId,
    recordingModelVersion: '1',
    modelFallbackReason: modelFallbackReason,
    activeTranscriptSnapshotId: activeTranscriptSnapshotId,
    activeSummaryId: activeSummaryId,
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
