part of '../meeting_list_previews.dart';

final class _PreviewMeetingReadinessChecker implements MeetingReadinessChecker {
  const _PreviewMeetingReadinessChecker();

  @override
  Future<MeetingReadiness> check({
    bool requestMicrophonePermission = false,
  }) async => MeetingReadiness(
    microphonePermissionGranted: true,
    freeBytes: minimumRecordingFreeBytes,
    defaultModelId: senseVoiceDefaultModelId,
    defaultModelVersion: AsrModelRegistry.alpha.defaultModel.version,
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
