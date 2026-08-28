import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/ports/repositories.dart';

final class PreviewMeetingRepository implements MeetingRepository {
  PreviewMeetingRepository([Iterable<Meeting> meetings = const []])
    : _meetings = {for (final meeting in meetings) meeting.id: meeting};

  final Map<String, Meeting> _meetings;

  @override
  Future<void> delete(String meetingId) async {
    _meetings.remove(meetingId);
  }

  @override
  Future<Meeting?> getById(String meetingId) async => _meetings[meetingId];

  @override
  Future<void> save(Meeting meeting) async {
    _meetings[meeting.id] = meeting;
  }

  @override
  Future<Meeting> updateTitle({
    required String meetingId,
    required String title,
  }) async {
    final updated = _meetings[meetingId]!.rename(title);
    _meetings[meetingId] = updated;
    return updated;
  }

  @override
  Stream<List<Meeting>> watchAll() =>
      Stream.value(List<Meeting>.unmodifiable(_meetings.values));
}
