// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · previews: UI-03 recording flow · macrostructure: Recorder instrument

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../app/application.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/asr_preview.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/recording.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../domain/ports/asr_engine.dart';
import '../../../../domain/ports/asr_preview_session.dart';
import '../../../../domain/ports/recording_session.dart';
import '../../../../domain/ports/repositories.dart';
import '../../../../domain/use_cases/manage_recording_session.dart';
import '../../../../domain/use_cases/start_meeting.dart';
import '../view_models/recording_session_view_model.dart';
import 'recording_session_view.dart';

@Preview(name: '录音工作台 · 375', group: 'UI-03 录音工作台', size: Size(375, 800))
Widget recordingWorkbenchCompactPreview() =>
    _recordingPreview(AsrPreviewState.ready);

@Preview(name: '录音积压 · 414', group: 'UI-03 录音工作台', size: Size(414, 800))
Widget recordingBacklogPreview() =>
    _recordingPreview(AsrPreviewState.backlogged);

@Preview(name: '仅录音降级 · 1024', group: 'UI-03 录音工作台', size: Size(1024, 800))
Widget recordingOnlyExpandedPreview() =>
    _recordingPreview(AsrPreviewState.recordingOnly);

Widget _recordingPreview(AsrPreviewState state) {
  final descriptor = AsrModelRegistry.alpha.defaultModel;
  final meeting = Meeting(
    id: 'preview-recording-workbench',
    title: '产品 Alpha 评审',
    createdAt: DateTime(2026, 7, 25, 9, 30),
    startedAt: DateTime(2026, 7, 25, 9, 30),
    status: MeetingState.recording,
    audioDurationMs: 0,
    requestedModelId: descriptor.modelId,
    recordingModelId: descriptor.modelId,
    recordingModelVersion: descriptor.version,
  );
  final recording = _PreviewRecordingService();
  final preview = _PreviewSession(state);
  return Application(
    home: RecordingSessionView(
      viewModel: RecordingSessionViewModel(
        session: StartedMeetingSession(
          meeting: meeting,
          engine: _PreviewAsrEngine(descriptor),
        ),
        recording: recording,
        preview: preview,
        sessionLifecycle: ManageRecordingSessionUseCase(
          meetings: const _PreviewMeetingRepository(),
          recording: recording,
          preview: preview,
          now: () => DateTime(2026, 7, 25, 9, 44, 28),
        ),
        tickerFactory: (_, _) => Timer(const Duration(days: 1), () {}),
      ),
      onFinished: (_) {},
    ),
  );
}

final class _PreviewMeetingRepository implements MeetingRepository {
  const _PreviewMeetingRepository();

  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<Meeting?> getById(String meetingId) async => null;

  @override
  Future<void> save(Meeting meeting) async {}

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
  Future<void> dispose() async {}

  @override
  Future<void> flush() async {}
}

final class _PreviewAsrEngine implements AsrEngine {
  const _PreviewAsrEngine(this.descriptor);

  @override
  final AsrModelDescriptor descriptor;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('组件预览不执行真实 ASR');
}
