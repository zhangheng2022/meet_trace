import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/recording.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/asr_preview_session.dart';
import 'package:meettrace/domain/ports/recording_session.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/use_cases/manage_recording_session.dart';

void main() {
  final now = DateTime.utc(2026, 9, 30);
  late Meeting meeting;
  late _Meetings meetings;
  late _Recording recording;
  late _Preview preview;
  late ManageRecordingSessionUseCase useCase;

  setUp(() {
    meeting = Meeting(
      id: 'meeting',
      title: '会议',
      createdAt: now,
      status: MeetingState.created,
      audioDurationMs: 0,
      recordingModelId: 'sensevoice',
      recordingModelVersion: '1',
    ).startRecording(startedAt: now);
    meetings = _Meetings();
    recording = _Recording();
    preview = _Preview();
    useCase = ManageRecordingSessionUseCase(
      meetings: meetings,
      recording: recording,
      preview: preview,
      now: () => now.add(const Duration(seconds: 1)),
    );
  });

  test('封存后数据库单次失败仍保存完整音频引用和时长', () async {
    meetings.failuresRemaining = 1;
    ManageRecordingSessionException? failure;
    try {
      await useCase.finish(meeting);
    } on ManageRecordingSessionException catch (error) {
      failure = error;
    }

    expect(failure, isNotNull);
    expect(meetings.saved.single, same(failure!.meeting));
    expect(failure.meeting.status, MeetingState.failed);
    expect(failure.meeting.audioPath, 'audio/fact.pcm');
    expect(failure.meeting.audioDurationMs, 1000);
    expect(
      failure.meeting.beginFinalTranscription().status,
      MeetingState.processing,
    );
    expect(recording.stopCalls, 1);
  });

  test('数据库持续失败不覆盖封存结果或原始错误', () async {
    meetings.failuresRemaining = 2;
    await expectLater(
      useCase.finish(meeting),
      throwsA(
        isA<ManageRecordingSessionException>()
            .having((error) => error.cause, 'cause', same(meetings.error))
            .having(
              (error) => error.meeting.audioPath,
              'audioPath',
              'audio/fact.pcm',
            )
            .having((error) => error.meeting.audioDurationMs, 'duration', 1000),
      ),
    );
    expect(meetings.saved, isEmpty);
    expect(recording.stopCalls, 1);
  });

  test('封存失败仍保留可供启动恢复筛选的错误代码', () async {
    recording.error = const ReliableRecordingException(
      code: 'recording.finalize_failed',
      message: 'checkpoint failed',
    );
    await expectLater(
      useCase.finish(meeting),
      throwsA(isA<ManageRecordingSessionException>()),
    );
    expect(meetings.saved.single.status, MeetingState.failed);
    expect(meetings.saved.single.lastErrorCode, 'recording.finalize_failed');
    expect(meetings.saved.single.audioPath, isNull);
  });

  test('预览停止失败不改变已封存会议', () async {
    preview.error = StateError('preview unavailable');
    final completed = await useCase.finish(meeting);
    expect(completed.status, MeetingState.processing);
    expect(completed.audioPath, 'audio/fact.pcm');
    expect(meetings.saved.single, same(completed));
  });
}

final class _Meetings implements MeetingRepository {
  final saved = <Meeting>[];
  final error = StateError('database unavailable');
  int failuresRemaining = 0;

  @override
  Future<void> save(Meeting meeting) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw error;
    }
    saved.add(meeting);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Recording implements RecordingSessionService {
  Object? error;
  int stopCalls = 0;

  @override
  Future<RecordingArtifact> stop() async {
    stopCalls++;
    if (error != null) throw error!;
    return const RecordingArtifact(
      meetingId: 'meeting',
      audioPath: 'audio/fact.pcm',
      bytes: 32000,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Preview implements AsrPreviewSession {
  Object? error;

  @override
  Future<void> stop() async {
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
