import '../models/domain_exception.dart';
import '../models/workflow_states.dart';
import '../ports/repositories.dart';

abstract interface class MeetingFileDeletionService {
  Future<StagedMeetingDeletion> stage(String meetingId);
}

abstract interface class StagedMeetingDeletion {
  Future<void> commit();

  Future<void> rollback();
}

final class DeleteMeetingUseCase {
  const DeleteMeetingUseCase({required this.meetings, required this.files});

  final MeetingRepository meetings;
  final MeetingFileDeletionService files;

  Future<void> execute({required String meetingId}) async {
    final meeting = await meetings.getById(meetingId);
    if (meeting == null) {
      return;
    }
    if (meeting.status case MeetingState.recording || MeetingState.processing) {
      throw const DomainInvariantViolation('录音中或后台处理中的会议不能删除');
    }
    final staged = await files.stage(meeting.id);
    try {
      await meetings.delete(meeting.id);
    } on Object {
      await staged.rollback();
      rethrow;
    }
    try {
      await staged.commit();
    } on Object {
      // 数据库删除已提交，暂存目录由启动恢复继续清理。
    }
  }
}
