import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/app/application.dart';
import 'package:meetily_ai/data/services/asr/asr_preview_coordinator.dart';
import 'package:meetily_ai/data/services/audio/reliable_recording_service.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/asr_preview.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
import 'package:meetily_ai/domain/models/recording.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:meetily_ai/ui/features/meetings/view_models/recording_session_view_model.dart';
import 'package:meetily_ai/ui/features/meetings/view_models/start_meeting_view_model.dart';
import 'package:meetily_ai/ui/features/meetings/views/recording_session_view.dart';

import '../../../../support/model_selection_fakes.dart';

void main() {
  testWidgets('显示时长、暂停/恢复、仅录音降级并结束会议', (WidgetTester tester) async {
    final meetings = TestMeetingRepository();
    final recording = _RecordingService();
    final preview = _PreviewSession();
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
    final viewModel = RecordingSessionViewModel(
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
    Meeting? finished;

    await tester.pumpWidget(
      Application(
        home: RecordingSessionView(
          viewModel: viewModel,
          onFinished: (meeting) => finished = meeting,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    recording.durationValue = const Duration(seconds: 12);
    viewModel.refreshDuration();
    await tester.pump();

    expect(find.text('00:00:12'), findsOneWidget);
    expect(find.text('实时转录正常'), findsOneWidget);

    await tester.tap(find.text('暂停录音'));
    await tester.pumpAndSettle();
    expect(find.text('录音已暂停'), findsOneWidget);
    expect(find.text('转录已暂停'), findsOneWidget);

    await tester.tap(find.text('恢复录音'));
    await tester.pumpAndSettle();
    preview.emit(AsrPreviewState.recordingOnly);
    await tester.pump();
    expect(find.text('仅录音模式'), findsOneWidget);
    expect(find.textContaining('不会中断录音'), findsOneWidget);
    expect(viewModel.recordingState, RecordingState.recording);
    expect(viewModel.canStop, isTrue);

    await tester.tap(find.text('结束会议'));
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 20 && finished == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pump(const Duration(milliseconds: 200));
    expect(finished?.status, MeetingState.processing);
    expect(meetings.saved.last.audioDurationMs, 12000);
    viewModel.dispose();
    await preview.close();
  });
}

final class _RecordingService implements RecordingSessionService {
  RecordingState _state = RecordingState.idle;
  Duration durationValue = Duration.zero;

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
      StreamController<TranscriptEvent>.broadcast();
  final StreamController<AsrPreviewMetrics> _changes =
      StreamController<AsrPreviewMetrics>.broadcast(sync: true);
  AsrPreviewMetrics _metrics = _value(AsrPreviewState.ready);

  @override
  Stream<TranscriptEvent> get events => _events.stream;

  @override
  AsrPreviewMetrics get metrics => _metrics;

  @override
  Stream<AsrPreviewMetrics> get metricsChanges => _changes.stream;

  void emit(AsrPreviewState state) {
    _metrics = _value(state);
    _changes.add(_metrics);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> flush() async {}

  Future<void> close() async {
    await _events.close();
    await _changes.close();
  }
}

AsrPreviewMetrics _value(AsrPreviewState state) => AsrPreviewMetrics(
  state: state,
  vadSegmentCount: 0,
  queuedAudioMs: 0,
  processedPreviewWindows: 0,
  droppedPreviewWindows: 0,
  previewLagMs: 0,
);
