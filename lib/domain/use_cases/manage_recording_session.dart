import '../models/meeting.dart';
import '../models/workflow_states.dart';
import '../ports/asr_preview_session.dart';
import '../ports/recording_session.dart';
import '../ports/repositories.dart';

final class ManageRecordingSessionException implements Exception {
  const ManageRecordingSessionException({
    required this.meeting,
    required this.cause,
  });

  final Meeting meeting;
  final Object cause;
}

/// 维护事实录音与会议状态的一致性；预览始终按可降级派生数据处理。
final class ManageRecordingSessionUseCase {
  const ManageRecordingSessionUseCase({
    required this.meetings,
    required this.recording,
    required this.preview,
    required this.now,
  });

  final MeetingRepository meetings;
  final RecordingSessionService recording;
  final AsrPreviewSession preview;
  final DateTime Function() now;

  Future<void> start(Meeting meeting) async {
    try {
      await recording.start(meetingId: meeting.id);
    } on Object catch (error) {
      throw ManageRecordingSessionException(
        meeting: await _saveFailure(meeting, error),
        cause: error,
      );
    }
  }

  Future<Meeting> finish(Meeting meeting) async {
    try {
      final artifact = await recording.stop();
      try {
        await preview.flush();
      } on Object {
        // 会中预览是派生数据，失败不得改变事实音频封存结果。
      }
      final completed = meeting.finishRecording(
        endedAt: now(),
        audioPath: artifact.audioPath,
        audioDurationMs: artifact.duration.inMilliseconds,
      );
      await meetings.save(completed);
      return completed;
    } on Object catch (error) {
      if (error is ManageRecordingSessionException) {
        rethrow;
      }
      throw ManageRecordingSessionException(
        meeting: await _saveFailure(meeting, error),
        cause: error,
      );
    }
  }

  Future<Meeting> _saveFailure(Meeting meeting, Object error) async {
    if (meeting.status == MeetingState.failed) {
      return meeting;
    }
    final failed = meeting.fail(errorCode: _errorCode(error), endedAt: now());
    await meetings.save(failed);
    return failed;
  }

  String _errorCode(Object error) {
    return error is ReliableRecordingException
        ? error.code
        : 'recording.unexpected';
  }
}
