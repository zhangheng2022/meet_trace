part of '../recording_previews.dart';

final class _PreviewMeetingRepository implements MeetingRepository {
  const _PreviewMeetingRepository();

  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<Meeting?> getById(String meetingId) async => null;

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Future<Meeting> updateTitle({
    required String meetingId,
    required String title,
  }) async => throw UnsupportedError('not used in recording preview');

  @override
  Stream<List<Meeting>> watchAll() => const Stream.empty();
}

final class _PreviewRecordingService implements RecordingSessionService {
  RecordingState _state = RecordingState.idle;

  @override
  Stream<RecordingAudioLevel> get audioLevelChanges => Stream.fromIterable(
    const [
      0.08,
      0.14,
      0.28,
      0.46,
      0.72,
      0.38,
      0.22,
      0.54,
      0.86,
      0.44,
      0.18,
      0.64,
    ].map(
      (level) => RecordingAudioLevel(
        level: level,
        capturedThrough: Duration(milliseconds: (level * 10000).round()),
      ),
    ),
  );

  @override
  Duration get duration => const Duration(minutes: 14, seconds: 28);

  @override
  bool get canFinalize =>
      _state == RecordingState.recording || _state == RecordingState.paused;

  @override
  RecordingState get state => _state;

  @override
  Future<void> pause() async {
    _state = RecordingState.paused;
  }

  @override
  Future<void> resume() async {
    _state = RecordingState.recording;
  }

  @override
  Future<void> start({required String meetingId}) async {
    _state = RecordingState.recording;
  }

  @override
  Future<RecordingArtifact> stop() async {
    _state = RecordingState.completed;
    return const RecordingArtifact(
      meetingId: 'preview-recording-workbench',
      audioPath: 'preview://fact.pcm',
      bytes: 27776000,
    );
  }
}

final class _PreviewSession implements AsrPreviewSession {
  _PreviewSession(AsrPreviewState state)
    : _metrics = AsrPreviewMetrics(
        state: state,
        vadSegmentCount: 12,
        queuedAudioMs: state == AsrPreviewState.backlogged ? 4200 : 0,
        processedPreviewWindows: 10,
        droppedPreviewWindows: 0,
        previewLagMs: state == AsrPreviewState.backlogged ? 6800 : 0,
      );

  final AsrPreviewMetrics _metrics;
  final StreamController<TranscriptEvent> _events =
      StreamController<TranscriptEvent>.broadcast();
  final StreamController<AsrPreviewMetrics> _changes =
      StreamController<AsrPreviewMetrics>.broadcast();

  @override
  Stream<TranscriptEvent> get events => _events.stream;

  @override
  AsrPreviewMetrics get metrics => _metrics;

  @override
  Stream<AsrPreviewMetrics> get metricsChanges => _changes.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> stop() async {}
}

final class _PreviewAsrEngine implements AsrEngine {
  const _PreviewAsrEngine(this.descriptor);

  @override
  final AsrModelDescriptor descriptor;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('组件预览不执行真实 ASR');
}
