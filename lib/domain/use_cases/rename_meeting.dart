import '../models/domain_exception.dart';
import '../models/meeting.dart';
import '../ports/repositories.dart';

final class RenameMeetingUseCase {
  const RenameMeetingUseCase({required this.meetings});

  final MeetingRepository meetings;

  Future<Meeting> execute({
    required String meetingId,
    required String title,
  }) async {
    final current = await meetings.getById(meetingId);
    if (current == null) {
      throw const DomainInvariantViolation('要重命名的会议不存在');
    }
    final renamed = current.rename(title);
    if (renamed.title == current.title) {
      return current;
    }
    return meetings.updateTitle(meetingId: current.id, title: renamed.title);
  }
}
