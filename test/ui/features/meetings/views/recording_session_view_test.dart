import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
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
import 'package:meettrace/ui/features/meetings/views/recording_session_view.dart';
import 'package:meettrace/ui/core/app_ledger.dart';

import '../../../../support/model_selection_fakes.dart';

void main() {
  testWidgets('显示事实音频、锁定模型、暂停恢复和仅录音降级', (WidgetTester tester) async {
    final fixture = _fixture();
    Meeting? finished;

    await tester.pumpWidget(
      Application(
        home: RecordingSessionView(
          viewModel: fixture.viewModel,
          onFinished: (meeting) => finished = meeting,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    fixture.recording.durationValue = const Duration(seconds: 12);
    fixture.viewModel.refreshDuration();
    await tester.pump();

    expect(find.text('00:00:12'), findsOneWidget);
    expect(find.textContaining('标准模型（Paraformer） · 本场已锁定'), findsOneWidget);
    expect(find.text('事实音频正在安全写入'), findsOneWidget);
    expect(find.text('实时转录正常'), findsOneWidget);

    await tester.tap(find.text('暂停录音'));
    await tester.pumpAndSettle();
    expect(find.text('事实录音已暂停'), findsOneWidget);
    expect(find.text('实时转录已随录音暂停'), findsOneWidget);

    await tester.tap(find.text('恢复录音'));
    await tester.pumpAndSettle();
    fixture.preview.emit(AsrPreviewState.recordingOnly);
    await tester.pump();
    expect(find.text('实时转录已停止，录音仍在继续'), findsOneWidget);
    expect(find.textContaining('事实音频仍在安全写入'), findsOneWidget);
    expect(fixture.viewModel.recordingState, RecordingState.recording);
    expect(fixture.viewModel.canStop, isTrue);
    expect(finished, isNull);
    await fixture.dispose();
  });

  testWidgets('返回键和结束按钮进入同一确认流程，确认后封存会议', (WidgetTester tester) async {
    final fixture = _fixture();
    Meeting? finished;

    await tester.pumpWidget(
      Application(
        home: RecordingSessionView(
          viewModel: fixture.viewModel,
          onFinished: (meeting) => finished = meeting,
        ),
      ),
    );
    await tester.pumpAndSettle();
    fixture.recording.durationValue = const Duration(seconds: 12);
    fixture.viewModel.refreshDuration();
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('结束并保存会议？'), findsOneWidget);
    expect(find.text('继续录音'), findsOneWidget);
    expect(finished, isNull);

    await tester.tap(find.text('继续录音'));
    await tester.pumpAndSettle();
    expect(find.text('结束并保存会议？'), findsNothing);

    await tester.tap(find.text('结束并保存').last);
    await tester.pumpAndSettle();
    expect(find.text('结束并保存会议？'), findsOneWidget);
    await tester.tap(find.text('结束并保存').last);
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 20 && finished == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pump(const Duration(milliseconds: 200));
    expect(finished?.status, MeetingState.processing);
    expect(fixture.meetings.saved.last.audioDurationMs, 12000);
    await fixture.dispose();
  });

  testWidgets('320 宽度和 2.0 字体缩放下关键状态与操作不溢出', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final fixture = _fixture();

    await tester.pumpWidget(
      Application(
        home: RecordingSessionView(
          viewModel: fixture.viewModel,
          onFinished: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('事实音频正在安全写入'), findsOneWidget);
    expect(find.text('暂停录音'), findsOneWidget);
    expect(find.text('结束并保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await fixture.dispose();
  });

  testWidgets('1024 宽度下事实状态与实时转录使用双列工作台', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _fixture();

    await tester.pumpWidget(
      Application(
        home: RecordingSessionView(
          viewModel: fixture.viewModel,
          onFinished: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('recording-wide-layout')), findsOneWidget);
    expect(find.byType(AppTimeRuler), findsOneWidget);
    expect(find.text('事实音频正在安全写入'), findsOneWidget);
    expect(find.text('实时转录'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await fixture.dispose();
  });
}

_Fixture _fixture() {
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
  return _Fixture(
    meetings: meetings,
    recording: recording,
    preview: preview,
    viewModel: viewModel,
  );
}

final class _Fixture {
  const _Fixture({
    required this.meetings,
    required this.recording,
    required this.preview,
    required this.viewModel,
  });

  final TestMeetingRepository meetings;
  final _RecordingService recording;
  final _PreviewSession preview;
  final RecordingSessionViewModel viewModel;

  Future<void> dispose() async {
    viewModel.dispose();
    await preview.close();
  }
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
