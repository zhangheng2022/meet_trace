part of '../meeting_detail_previews.dart';

final class _PreviewMeetingRepository implements MeetingRepository {
  _PreviewMeetingRepository(this.meeting);

  Meeting? meeting;

  @override
  Future<void> delete(String meetingId) async {
    if (meeting?.id == meetingId) {
      meeting = null;
    }
  }

  @override
  Future<Meeting?> getById(String meetingId) async =>
      meeting?.id == meetingId ? meeting : null;

  @override
  Future<void> save(Meeting meeting) async {
    this.meeting = meeting;
  }

  @override
  Future<Meeting> updateTitle({
    required String meetingId,
    required String title,
  }) async {
    final updated = meeting!.rename(title);
    meeting = updated;
    return updated;
  }

  @override
  Stream<List<Meeting>> watchAll() => Stream.value([?meeting]);
}

final class _PreviewTranscriptRepository implements TranscriptRepository {
  _PreviewTranscriptRepository([TranscriptSnapshot? snapshot])
    : _snapshot = snapshot;

  final TranscriptSnapshot? _snapshot;

  @override
  Future<TranscriptSnapshot?> getById(String snapshotId) async =>
      _snapshot?.id == snapshotId ? _snapshot : null;

  @override
  Future<List<TranscriptSnapshot>> listByMeeting(String meetingId) async {
    final snapshot = _snapshot;
    return snapshot?.meetingId == meetingId ? [snapshot!] : const [];
  }

  @override
  Future<TranscriptSnapshot?> getLatestByMeeting({
    required String meetingId,
    required TranscriptSnapshotKind kind,
    required TranscriptSnapshotStatus status,
  }) async {
    final snapshot = _snapshot;
    return snapshot?.meetingId == meetingId &&
            snapshot?.kind == kind &&
            snapshot?.status == status
        ? snapshot
        : null;
  }

  @override
  Future<void> save(TranscriptSnapshot snapshot) async {}

  @override
  Future<void> saveFinalAndActivate({
    required TranscriptSnapshot snapshot,
    required String? expectedActiveSnapshotId,
  }) async {}

  @override
  Future<TranscriptSnapshot> updateSpeakerLabels({
    required String snapshotId,
    required Map<String, String?> labelsBySegmentId,
  }) async => _snapshot!;
}

final class _UnavailableTranscriptionRunner
    implements FinalTranscriptionRunner {
  const _UnavailableTranscriptionRunner();

  @override
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  }) => throw UnsupportedError('组件预览不运行最终转录');
}

final class _PendingTranscriptionRunner implements FinalTranscriptionRunner {
  const _PendingTranscriptionRunner();

  @override
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  }) => Completer<FinalTranscriptionResult>().future;
}
