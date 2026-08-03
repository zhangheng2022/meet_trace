import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/data/services/asr/asr_preview_coordinator.dart';
import 'package:meettrace/data/services/audio/reliable_recording_service.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/recording.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/use_cases/manage_recording_session.dart';
import 'package:meettrace/domain/use_cases/start_meeting.dart';
import 'package:meettrace/ui/features/meetings/view_models/recording/recording_session_view_model.dart';
import 'package:meettrace/ui/features/meetings/views/recording/recording_session_view.dart';
import 'package:meettrace/ui/features/meetings/views/recording/widgets/recording_audio_waveform.dart';

import '../../../../../support/model_selection_fakes.dart';

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
    expect(find.textContaining('SenseVoice'), findsOneWidget);
    expect(find.textContaining('本场锁定'), findsOneWidget);
    expect(find.text('事实音频正在安全写入'), findsOneWidget);
    expect(find.text('实时转录正常'), findsOneWidget);
    expect(find.text('检测到语音后在这里显示文字。'), findsOneWidget);
    expect(find.text('录音'), findsNothing);
    expect(find.text('事实录音'), findsNothing);
    expect(find.text('时'), findsNothing);
    expect(find.text('分'), findsNothing);
    expect(find.text('秒'), findsNothing);
    expect(find.byType(RecordingAudioWaveform), findsOneWidget);
    expect(find.text('麦克风输入 · 实时反馈'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recording-control-console')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('recording-fact-ledger')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recording-bottom-actions')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('recording-control-console')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('recording-bottom-actions')))
            .dy,
      ),
    );

    await tester.ensureVisible(find.text('暂停'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暂停'));
    await tester.pumpAndSettle();
    expect(find.text('事实录音已暂停'), findsOneWidget);
    expect(find.text('实时转录已随录音暂停'), findsOneWidget);
    expect(find.text('麦克风输入 · 已暂停'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    fixture.preview.emit(AsrPreviewState.recordingOnly);
    await tester.pump();
    expect(find.text('实时转录已停止，录音仍在继续'), findsOneWidget);
    expect(find.text('事实音频正在安全写入'), findsOneWidget);
    expect(find.text('结束后仍会基于完整音频生成最终转录。'), findsOneWidget);
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

    await tester.ensureVisible(find.text('结束会议'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('结束会议'));
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

  testWidgets('确认结束后按钮原位切换为封存动画', (WidgetTester tester) async {
    final fixture = _fixture();
    final stopBarrier = Completer<void>();
    fixture.recording.stopBarrier = stopBarrier;
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

    final button = find.byKey(const ValueKey('recording-end-button'));
    final initialRect = tester.getRect(button);
    await tester.tap(find.text('结束会议'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('结束并保存').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(
      find.byKey(const ValueKey('recording-end-finalizing')),
      findsOneWidget,
    );
    expect(find.text('正在封存音频'), findsOneWidget);
    expect(find.byType(FCircularProgress), findsOneWidget);
    expect(find.text('正在封存事实音频'), findsOneWidget);
    expect(tester.getRect(button), initialRect);
    expect(finished, isNull);

    stopBarrier.complete();
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 20 && finished == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pump(const Duration(milliseconds: 200));

    expect(finished?.status, MeetingState.processing);
    await fixture.dispose();
  });

  testWidgets('采集流失败但仍有事实音频时继续拦截返回并允许封存', (WidgetTester tester) async {
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
    fixture.recording
      ..durationValue = const Duration(seconds: 6)
      ..failWithFinalizableAudio();
    fixture.viewModel.refreshDuration();
    await tester.pump();

    expect(fixture.viewModel.recordingState, RecordingState.failed);
    expect(fixture.viewModel.canStop, isTrue);

    await tester.binding.handlePopRoute();
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
    expect(finished?.audioDurationMs, 6000);
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
    fixture.preview.emitSegment(
      const TranscriptSegmentEvent(
        segmentId: 'compact-segment',
        startMs: 11000,
        endMs: 14000,
        text: '这是一条用于验证窄屏时间布局的实时转录。',
        modelId: senseVoiceDefaultModelId,
        modelVersion: 'test',
        isFinalForWindow: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('事实音频正在安全写入'), findsOneWidget);
    expect(find.text('00:11'), findsOneWidget);
    final compactTimestamp = tester.widget<Text>(find.text('00:11'));
    expect(compactTimestamp.maxLines, 1);
    expect(compactTimestamp.softWrap, isFalse);
    expect(find.text('最新'), findsNothing);
    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('结束会议'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('结束会议')).dy,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
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
    expect(find.byType(RecordingAudioWaveform), findsOneWidget);
    expect(find.text('事实音频正在安全写入'), findsOneWidget);
    expect(find.text('实时转录'), findsOneWidget);
    final wideLedger = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('live-transcript-ledger')),
    );
    expect((wideLedger.decoration as BoxDecoration).border, isNotNull);
    expect(tester.takeException(), isNull);
    await fixture.dispose();
  });

  testWidgets('375、414 和 768 宽度下控制台保持单列且无溢出', (WidgetTester tester) async {
    for (final size in const [
      Size(375, 812),
      Size(414, 896),
      Size(768, 1024),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
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

      expect(
        find.byKey(const ValueKey('recording-compact-layout')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('recording-control-console')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live-transcript-ledger')),
        findsOneWidget,
      );
      final compactLedger = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('live-transcript-ledger')),
      );
      final compactDecoration = compactLedger.decoration as BoxDecoration;
      expect(compactDecoration.border, isNull);
      expect(compactDecoration.borderRadius, isNull);
      expect(tester.takeException(), isNull);
      await fixture.dispose();
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('实时转录按时间账本显示时标与文本', (WidgetTester tester) async {
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
    expect(find.byKey(const ValueKey('live-transcript-count')), findsNothing);
    fixture.preview.emitSegment(
      const TranscriptSegmentEvent(
        segmentId: 'segment-1',
        startMs: 4990000,
        endMs: 4995000,
        text: '关于本次需求的背景，我们先简单回顾一下。',
        modelId: senseVoiceDefaultModelId,
        modelVersion: 'test',
        isFinalForWindow: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1:23:10'), findsOneWidget);
    expect(find.byKey(const ValueKey('transcript-segment-1')), findsOneWidget);
    expect(find.text('1 段'), findsOneWidget);
    expect(find.text('最新'), findsNothing);
    expect(tester.takeException(), isNull);
    await fixture.dispose();
  });
}

_Fixture _fixture() {
  final meetings = TestMeetingRepository();
  final recording = _RecordingService();
  final preview = _PreviewSession();
  final descriptor = AsrModelRegistry.alpha.requireById(
    senseVoiceDefaultModelId,
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
    recording: recording,
    preview: preview,
    sessionLifecycle: ManageRecordingSessionUseCase(
      meetings: meetings,
      recording: recording,
      preview: preview,
      now: () => DateTime.utc(2026, 7, 24, 1, 30),
    ),
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
    await recording.close();
    await preview.close();
  }
}

final class _RecordingService implements RecordingSessionService {
  final StreamController<RecordingAudioLevel> _audioLevels =
      StreamController<RecordingAudioLevel>.broadcast(sync: true);
  RecordingState _state = RecordingState.idle;
  Duration durationValue = Duration.zero;
  Completer<void>? stopBarrier;
  bool _hasFinalizableAudio = false;

  @override
  Stream<RecordingAudioLevel> get audioLevelChanges => _audioLevels.stream;

  @override
  Duration get duration => durationValue;

  @override
  bool get canFinalize =>
      _hasFinalizableAudio &&
      (_state == RecordingState.recording ||
          _state == RecordingState.paused ||
          _state == RecordingState.failed);

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
    _hasFinalizableAudio = true;
    _state = RecordingState.recording;
  }

  void failWithFinalizableAudio() {
    _state = RecordingState.failed;
  }

  Future<void> close() => _audioLevels.close();

  @override
  Future<RecordingArtifact> stop() async {
    await stopBarrier?.future;
    _hasFinalizableAudio = false;
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

  void emitSegment(TranscriptSegmentEvent event) {
    _events.add(event);
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
