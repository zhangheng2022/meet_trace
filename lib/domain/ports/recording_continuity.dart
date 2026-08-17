import '../models/recording_continuity_event.dart';

abstract interface class RecordingContinuityEventStore {
  Future<void> append(RecordingContinuityEvent event);

  Future<List<RecordingContinuityEvent>> read(String meetingId);
}

final class NoopRecordingContinuityEventStore
    implements RecordingContinuityEventStore {
  const NoopRecordingContinuityEventStore();

  @override
  Future<void> append(RecordingContinuityEvent event) async {}

  @override
  Future<List<RecordingContinuityEvent>> read(String meetingId) async =>
      const [];
}
