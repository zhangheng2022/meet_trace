const minimumRecordingFreeBytes = 128 * 1024 * 1024;

enum MeetingReadinessIssue {
  microphonePermission,
  insufficientStorage,
  defaultModelUnavailable,
}

final class MeetingReadiness {
  const MeetingReadiness({
    required this.microphonePermissionGranted,
    required this.freeBytes,
    required this.defaultModelId,
    required this.defaultModelName,
    required this.defaultModelAvailable,
  });

  final bool microphonePermissionGranted;
  final int freeBytes;
  final String defaultModelId;
  final String defaultModelName;
  final bool defaultModelAvailable;

  List<MeetingReadinessIssue> get issues => List.unmodifiable([
    if (!microphonePermissionGranted)
      MeetingReadinessIssue.microphonePermission,
    if (freeBytes < minimumRecordingFreeBytes)
      MeetingReadinessIssue.insufficientStorage,
    if (!defaultModelAvailable) MeetingReadinessIssue.defaultModelUnavailable,
  ]);

  bool get canStart => issues.isEmpty;
}
