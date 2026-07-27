import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/asr_preview_coordinator.dart';
import 'package:meettrace/data/services/audio/reliable_recording_service.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/recording.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/ui/features/meetings/view_models/recording_session_view_model.dart';
import 'package:meettrace/ui/features/meetings/view_models/start_meeting_view_model.dart';

import '../../../../support/model_selection_fakes.dart';

void main() {
  test('暂停恢复后封存事实音频并进入处理状态', () async {
    final meetings = TestMeetingRepository();
    final recording = _RecordingService();
    final preview = _PreviewSession();
    final viewModel = _viewModel(
      meetings: meetings,
      recording: recording,
      preview: preview,
    );

    expect(await viewModel.start(), isTrue);
    recording.durationValue = const Duration(seconds: 12);
    viewModel.refreshDuration();
    await viewModel.pause();
    expect(viewModel.recordingState, RecordingState.paused);
    await viewModel.resume();
    expect(viewModel.recordingState, RecordingState.recording);

    final completed = await viewModel.stop();

    expect(completed?.status, MeetingState.processing);
    expect(completed?.audioPath, '/meetings/meeting-1/fact.pcm');
    expect(completed?.audioDurationMs, 12000);
    expect(preview.flushCalls, 1);
    expect(preview.disposeCalls, 1);
    expect(meetings.saved.last.status, MeetingState.processing);
    viewModel.dispose();
    await preview.close();
  });

  test('预览降级和乱序事件不会停止录音，片段按时间排序', () async {
    final preview = _PreviewSession();
    final recording = _RecordingService();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
    );
    await viewModel.start();

    preview.emitSegment(id: 'late', startMs: 2000, text: '第二段');
    preview.emitSegment(id: 'early', startMs: 1000, text: '第一段');
    preview.emitMetrics(AsrPreviewState.recordingOnly);

    expect(viewModel.segments.map((event) => event.segmentId), [
      'early',
      'late',
    ]);
    expect(viewModel.previewMetrics.state, AsrPreviewState.recordingOnly);
    expect(viewModel.recordingState, RecordingState.recording);
    viewModel.dispose();
    await preview.close();
  });

  test('事实录音启动失败会持久化失败会议', () async {
    final meetings = TestMeetingRepository();
    final recording = _RecordingService()
      ..startError = const ReliableRecordingException(
        code: 'recording.permission_denied',
        message: 'denied',
      );
    final preview = _PreviewSession();
    final viewModel = _viewModel(
      meetings: meetings,
      recording: recording,
      preview: preview,
    );

    expect(await viewModel.start(), isFalse);
    expect(viewModel.meeting.status, MeetingState.failed);
    expect(viewModel.meeting.lastErrorCode, 'recording.permission_denied');
    expect(meetings.saved.last.status, MeetingState.failed);
    expect(viewModel.errorMessage, contains('麦克风权限'));
    viewModel.dispose();
    await preview.close();
  });
}

RecordingSessionViewModel _viewModel({
  required TestMeetingRepository meetings,
  required _RecordingService recording,
  required _PreviewSession preview,
}) {
  final descriptor = AsrModelRegistry.alpha.requireById(
    paraformerStandardModelId,
  );
  final meeting = Meeting(
    id: 'meeting-1',
    title: '产品评审',
    createdAt: DateTime.utc(2026, 7, 24),
    startedAt: DateTime.utc(2026, 7, 24, 1),
    status: MeetingState.recording,
    audioDurationMs: 0,
    requestedModelId: descriptor.modelId,
    recordingModelId: descriptor.modelId,
    recordingModelVersion: descriptor.version,
  );
  return RecordingSessionViewModel(
    session: StartedMeetingSession(
      meeting: meeting,
      engine: TestAsrEngine(descriptor),
    ),
    meetings: meetings,
    recording: recording,
    preview: preview,
    now: () => DateTime.utc(2026, 7, 24, 1, 30),
    tickerFactory: (_, _) => Timer(const Duration(days: 1), () {}),
  );
}

final class _RecordingService implements RecordingSessionService {
  RecordingState _state = RecordingState.idle;
  Duration durationValue = Duration.zero;
  Object? startError;

  @override
  Duration get duration => durationValue;

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
    final error = startError;
    if (error != null) {
      _state = RecordingState.failed;
      throw error;
    }
    _state = RecordingState.recording;
  }

  @override
  Future<RecordingArtifact> stop() async {
    _state = RecordingState.completed;
    return RecordingArtifact(
      meetingId: 'meeting-1',
      audioPath: '/meetings/meeting-1/fact.pcm',
      bytes: durationValue.inSeconds * recordingBytesPerSecond,
    );
  }
}

final class _PreviewSession implements AsrPreviewSession {
  final StreamController<TranscriptEvent> _events =
      StreamController<TranscriptEvent>.broadcast(sync: true);
  final StreamController<AsrPreviewMetrics> _metrics =
      StreamController<AsrPreviewMetrics>.broadcast(sync: true);
  AsrPreviewMetrics _value = _previewMetrics(AsrPreviewState.ready);
  int flushCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<TranscriptEvent> get events => _events.stream;

  @override
  AsrPreviewMetrics get metrics => _value;

  @override
  Stream<AsrPreviewMetrics> get metricsChanges => _metrics.stream;

  void emitMetrics(AsrPreviewState state) {
    _value = _previewMetrics(state);
    _metrics.add(_value);
  }

  void emitSegment({
    required String id,
    required int startMs,
    required String text,
  }) {
    _events.add(
      TranscriptSegmentEvent(
        segmentId: id,
        startMs: startMs,
        endMs: startMs + 1000,
        text: text,
        modelId: paraformerStandardModelId,
        modelVersion: '1',
        isFinalForWindow: true,
      ),
    );
  }

  @override
  Future<void> flush() async {
    flushCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  Future<void> close() async {
    await _events.close();
    await _metrics.close();
  }
}

AsrPreviewMetrics _previewMetrics(AsrPreviewState state) => AsrPreviewMetrics(
  state: state,
  vadSegmentCount: 0,
  queuedAudioMs: 0,
  processedPreviewWindows: 0,
  droppedPreviewWindows: 0,
  previewLagMs: 0,
);
