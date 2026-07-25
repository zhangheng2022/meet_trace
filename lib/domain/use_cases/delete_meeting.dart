import '../../data/repositories/repository_contracts.dart';

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
    final staged = await files.stage(meeting.id);
    try {
      await meetings.delete(meeting.id);
    } on Object {
      await staged.rollback();
      rethrow;
    }
    await staged.commit();
  }
}
