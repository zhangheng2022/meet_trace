part of '../meeting_list_previews.dart';

final class _PreviewMeetingRepository implements MeetingRepository {
  const _PreviewMeetingRepository(this.meetings);

  final List<Meeting> meetings;

  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<Meeting?> getById(String meetingId) async {
    for (final meeting in meetings) {
      if (meeting.id == meetingId) {
        return meeting;
      }
    }
    return null;
  }

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Stream<List<Meeting>> watchAll() => Stream.value(meetings);
}

final class _PreviewMeetingReadinessChecker implements MeetingReadinessChecker {
  const _PreviewMeetingReadinessChecker();

  @override
  Future<MeetingReadiness> check({
    bool requestMicrophonePermission = false,
  }) async => MeetingReadiness(
    microphonePermissionGranted: true,
    freeBytes: minimumRecordingFreeBytes,
    defaultModelId: whisperBaseStandardModelId,
    defaultModelName: AsrModelRegistry.alpha.defaultModel.displayName,
    defaultModelAvailable: true,
  );
}

final class _PreviewMeetingFileDeletionService
    implements MeetingFileDeletionService {
  const _PreviewMeetingFileDeletionService();

  @override
  Future<StagedMeetingDeletion> stage(String meetingId) async =>
      const _PreviewStagedMeetingDeletion();
}

final class _PreviewStagedMeetingDeletion implements StagedMeetingDeletion {
  const _PreviewStagedMeetingDeletion();

  @override
  Future<void> commit() async {}

  @override
  Future<void> rollback() async {}
}
