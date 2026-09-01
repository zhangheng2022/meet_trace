import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/recording.dart';
import 'package:meettrace/domain/models/recording_input.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/asr_preview_session.dart';
import 'package:meettrace/domain/ports/desktop_lifecycle.dart';
import 'package:meettrace/domain/ports/recording_session.dart';
import 'package:meettrace/domain/ports/recording_system_lifecycle.dart';
import 'package:meettrace/domain/ports/recording_telemetry.dart';
import 'package:meettrace/domain/use_cases/manage_recording_session.dart';
import 'package:meettrace/domain/use_cases/start_meeting.dart';
import 'package:meettrace/ui/features/meetings/view_models/recording/recording_session_view_model.dart';

import '../../../../../support/model_selection_fakes.dart';

void main() {
  test('暂停恢复后封存事实音频并进入处理状态', () async {
    final meetings = TestMeetingRepository();
    final recording = _RecordingService();
    final preview = _PreviewSession();
    final telemetry = _RecordingTelemetryGate();
    final viewModel = _viewModel(
      meetings: meetings,
      recording: recording,
      preview: preview,
      telemetry: telemetry,
    );

    expect(await viewModel.start(), isTrue);
    expect(telemetry.recordingActive, isTrue);
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
    expect(preview.stopCalls, 1);
    await Future<void>.delayed(Duration.zero);
    expect(preview.disposeCalls, 1);
    expect(meetings.saved.last.status, MeetingState.processing);
    expect(telemetry.recordingActive, isFalse);
    viewModel.dispose();
    await preview.close();
  });

  test('封存期间暴露 finalizing 状态并阻止重复结束', () async {
    final meetings = TestMeetingRepository();
    final recording = _RecordingService()
      ..stopBarrier = Completer<void>()
      ..durationValue = const Duration(seconds: 12);
    final preview = _PreviewSession();
    final viewModel = _viewModel(
      meetings: meetings,
      recording: recording,
      preview: preview,
    );
    await viewModel.start();

    final stopping = viewModel.stop();

    expect(viewModel.isFinalizing, isTrue);
    expect(viewModel.canStop, isFalse);
    expect(await viewModel.stop(), isNull);

    recording.stopBarrier!.complete();
    final completed = await stopping;

    expect(completed?.status, MeetingState.processing);
    expect(viewModel.isFinalizing, isFalse);
    viewModel.dispose();
    await recording.close();
    await preview.close();
  });

  test('预览降级和乱序事件不会停止录音，片段按时间排序', () async {
    final preview = _PreviewSession();
    final recording = _RecordingService();
    final telemetry = _RecordingTelemetryGate()
      ..throwOnPreview = true
      ..throwOnSetActive = true;
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
      telemetry: telemetry,
    );
    await viewModel.start();
    var transcriptNotifications = 0;
    viewModel.transcriptListenable.addListener(() => transcriptNotifications++);

    preview.emitSegment(id: 'late', startMs: 2000, text: '第二段');
    preview.emitSegment(id: 'early', startMs: 1000, text: '第一段');
    preview.emitMetrics(AsrPreviewState.recordingOnly);

    expect(viewModel.segments.map((event) => event.segmentId), [
      'early',
      'late',
    ]);
    expect(viewModel.previewMetrics.state, AsrPreviewState.recordingOnly);
    expect(viewModel.recordingState, RecordingState.recording);
    expect(transcriptNotifications, greaterThan(0));
    viewModel.dispose();
    await preview.close();
  });

  test('音量反馈保持固定窗口且不受实时转录降级影响', () async {
    final recording = _RecordingService();
    final preview = _PreviewSession();
    final audioLevelTicker = _ManualPeriodicTicker();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
      audioLevelTickerFactory: audioLevelTicker.create,
    );
    await viewModel.start();

    for (var index = 0; index < 60; index++) {
      recording.emitAudioLevel(index / 59);
      audioLevelTicker.tick();
    }
    preview.emitMetrics(AsrPreviewState.recordingOnly);

    expect(viewModel.audioLevels, hasLength(recordingWaveformSampleCapacity));
    expect(viewModel.audioLevels.first, closeTo(12 / 59, 0.0001));
    expect(viewModel.audioLevels.last, 1);
    expect(viewModel.previewMetrics.state, AsrPreviewState.recordingOnly);
    expect(viewModel.recordingState, RecordingState.recording);
    viewModel.dispose();
    await recording.close();
    await preview.close();
  });

  test('时长、音量和转录高频事件不触发控制层整页通知', () async {
    final recording = _RecordingService();
    final preview = _PreviewSession();
    final audioLevelTicker = _ManualPeriodicTicker();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
      audioLevelTickerFactory: audioLevelTicker.create,
    );
    await viewModel.start();
    var controlNotifications = 0;
    viewModel.addListener(() => controlNotifications++);

    recording.durationValue = const Duration(seconds: 1);
    viewModel.refreshDuration();
    recording.emitAudioLevel(0.5);
    audioLevelTicker.tick();
    preview.emitSegment(id: 'segment-1', startMs: 0, text: '局部刷新');
    preview.emitMetrics(AsrPreviewState.recordingOnly);

    expect(controlNotifications, 0);
    expect(viewModel.duration, const Duration(seconds: 1));
    expect(viewModel.audioLevels, [0.5]);
    expect(viewModel.segments.single.text, '局部刷新');
    expect(viewModel.previewMetrics.state, AsrPreviewState.recordingOnly);
    viewModel.dispose();
    await recording.close();
    await preview.close();
  });

  test('突发音量按固定节拍逐个发布且积压时保留最新样本', () async {
    final recording = _RecordingService();
    final preview = _PreviewSession();
    final audioLevelTicker = _ManualPeriodicTicker();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
      audioLevelTickerFactory: audioLevelTicker.create,
    );
    await viewModel.start();

    for (final level in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7]) {
      recording.emitAudioLevel(level);
    }

    expect(viewModel.audioLevels, isEmpty);
    audioLevelTicker.tick();
    expect(viewModel.audioLevels, [0.3]);
    audioLevelTicker.tick();
    expect(viewModel.audioLevels, [0.3, 0.4]);
    audioLevelTicker.tick();
    expect(viewModel.audioLevels, [0.3, 0.4, 0.5]);

    viewModel.dispose();
    expect(audioLevelTicker.isActive, isFalse);
    await recording.close();
    await preview.close();
  });

  test('暂停时清空待展示音量并在恢复后继续发布新样本', () async {
    final recording = _RecordingService();
    final preview = _PreviewSession();
    final audioLevelTicker = _ManualPeriodicTicker();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
      audioLevelTickerFactory: audioLevelTicker.create,
    );
    await viewModel.start();

    recording.emitAudioLevel(0.4);
    await viewModel.pause();
    audioLevelTicker.tick();
    expect(viewModel.audioLevels, isEmpty);

    await viewModel.resume();
    recording.emitAudioLevel(0.6);
    audioLevelTicker.tick();
    expect(viewModel.audioLevels, [0.6]);

    viewModel.dispose();
    await recording.close();
    await preview.close();
  });

  test('预览初始化阻塞时事实录音启动仍立即完成', () async {
    final recording = _RecordingService();
    final preview = _PreviewSession()..initializeBarrier = Completer<void>();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
    );

    expect(await viewModel.start(), isTrue);
    expect(recording.state, RecordingState.recording);
    expect(preview.initializeCalls, 1);

    preview.initializeBarrier!.complete();
    viewModel.dispose();
    await recording.close();
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
    final telemetry = _RecordingTelemetryGate();
    final viewModel = _viewModel(
      meetings: meetings,
      recording: recording,
      preview: preview,
      telemetry: telemetry,
    );

    expect(await viewModel.start(), isFalse);
    expect(viewModel.meeting.status, MeetingState.failed);
    expect(viewModel.meeting.lastErrorCode, 'recording.permission_denied');
    expect(meetings.saved.last.status, MeetingState.failed);
    expect(viewModel.errorMessage, contains('麦克风权限'));
    expect(telemetry.recordingActive, isFalse);
    viewModel.dispose();
    await preview.close();
  });

  test('录音启动时输入设备消失会显示准确恢复提示', () async {
    final meetings = TestMeetingRepository();
    final recording = _RecordingService()
      ..startError = const ReliableRecordingException(
        code: 'recording.input_unavailable',
        message: 'no input',
      );
    final preview = _PreviewSession();
    final viewModel = _viewModel(
      meetings: meetings,
      recording: recording,
      preview: preview,
    );

    expect(await viewModel.start(), isFalse);
    expect(viewModel.meeting.lastErrorCode, 'recording.input_unavailable');
    expect(viewModel.errorMessage, contains('未检测到可用麦克风'));

    viewModel.dispose();
    await preview.close();
  });

  test('预览停止和释放失败不回滚已封存的事实音频', () async {
    final meetings = TestMeetingRepository();
    final recording = _RecordingService()
      ..durationValue = const Duration(seconds: 8);
    final preview = _PreviewSession()
      ..stopError = StateError('stop failed')
      ..disposeError = StateError('dispose failed');
    final viewModel = _viewModel(
      meetings: meetings,
      recording: recording,
      preview: preview,
    );

    expect(await viewModel.start(), isTrue);

    final completed = await viewModel.stop();

    expect(completed?.status, MeetingState.processing);
    expect(completed?.audioPath, '/meetings/meeting-1/fact.pcm');
    expect(completed?.audioDurationMs, 8000);
    expect(meetings.saved.last.status, MeetingState.processing);
    expect(viewModel.errorMessage, isNull);
    expect(preview.stopCalls, 1);
    await Future<void>.delayed(Duration.zero);
    expect(preview.disposeCalls, 1);
    viewModel.dispose();
    await preview.close();
  });

  test('录音开始前保护窗口并在安全封存后解除保护', () async {
    final desktopLifecycle = _DesktopLifecycle();
    final recording = _RecordingService()
      ..durationValue = const Duration(seconds: 5);
    final preview = _PreviewSession();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
      desktopLifecycle: desktopLifecycle,
    );

    expect(await viewModel.start(), isTrue);
    expect(desktopLifecycle.recordingStates, [true]);

    expect(await viewModel.stop(), isNotNull);
    expect(desktopLifecycle.recordingStates, [true, false]);

    viewModel.dispose();
    await desktopLifecycle.close();
    await recording.close();
    await preview.close();
  });

  test('解除桌面窗口保护失败不回滚已封存会议', () async {
    final desktopLifecycle = _DesktopLifecycle();
    final recording = _RecordingService()
      ..durationValue = const Duration(seconds: 5);
    final preview = _PreviewSession();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
      desktopLifecycle: desktopLifecycle,
    );
    await viewModel.start();
    desktopLifecycle.failWhenDeactivating = true;

    final completed = await viewModel.stop();

    expect(completed?.status, MeetingState.processing);
    expect(desktopLifecycle.recordingStates, [true, false]);
    expect(viewModel.errorMessage, isNull);

    viewModel.dispose();
    await desktopLifecycle.close();
    await recording.close();
    await preview.close();
  });

  test('事实录音启动失败后立即解除窗口退出保护', () async {
    final desktopLifecycle = _DesktopLifecycle();
    final recording = _RecordingService()
      ..startError = const ReliableRecordingException(
        code: 'recording.permission_denied',
        message: 'denied',
      );
    final preview = _PreviewSession();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
      desktopLifecycle: desktopLifecycle,
    );

    expect(await viewModel.start(), isFalse);
    expect(desktopLifecycle.recordingStates, [true, false]);

    viewModel.dispose();
    await desktopLifecycle.close();
    await recording.close();
    await preview.close();
  });

  test('托盘停止并退出先封存会议再允许 Win32 退出', () async {
    final meetings = TestMeetingRepository();
    final desktopLifecycle = _DesktopLifecycle();
    final recording = _RecordingService()
      ..durationValue = const Duration(seconds: 9);
    final preview = _PreviewSession();
    final viewModel = _viewModel(
      meetings: meetings,
      recording: recording,
      preview: preview,
      desktopLifecycle: desktopLifecycle,
    );
    await viewModel.start();

    desktopLifecycle.requestStopAndExit();
    await pumpEventQueue(times: 10);

    expect(meetings.saved.last.status, MeetingState.processing);
    expect(desktopLifecycle.confirmExitCalls, 1);
    expect(desktopLifecycle.cancelExitReasons, isEmpty);
    expect(desktopLifecycle.recordingStates, [true, false]);

    viewModel.dispose();
    await desktopLifecycle.close();
    await recording.close();
    await preview.close();
  });

  test('托盘封存失败时取消退出并保留窗口保护', () async {
    final desktopLifecycle = _DesktopLifecycle();
    final recording = _RecordingService()
      ..stopError = const ReliableRecordingException(
        code: 'recording.stop_failed',
        message: 'stop failed',
      );
    final preview = _PreviewSession();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
      desktopLifecycle: desktopLifecycle,
    );
    await viewModel.start();

    desktopLifecycle.requestStopAndExit();
    await pumpEventQueue(times: 10);

    expect(desktopLifecycle.confirmExitCalls, 0);
    expect(desktopLifecycle.cancelExitReasons.single, contains('封存失败'));
    expect(desktopLifecycle.recordingStates, [true]);

    viewModel.dispose();
    await desktopLifecycle.close();
    await recording.close();
    await preview.close();
  });

  test('桌面系统事件按到达顺序串行交给录音生命周期', () async {
    final desktopLifecycle = _DesktopLifecycle();
    final recording = _RecordingService();
    final preview = _PreviewSession();
    final viewModel = _viewModel(
      meetings: TestMeetingRepository(),
      recording: recording,
      preview: preview,
      desktopLifecycle: desktopLifecycle,
    );
    await viewModel.start();
    recording.suspendBarrier = Completer<void>();

    desktopLifecycle.emitSystemEvent(DesktopSystemEvent.suspending);
    desktopLifecycle.emitSystemEvent(DesktopSystemEvent.resumed);
    await pumpEventQueue(times: 3);
    expect(recording.systemLifecycleEvents, ['suspending']);

    recording.suspendBarrier!.complete();
    await pumpEventQueue(times: 10);
    expect(recording.systemLifecycleEvents, ['suspending', 'resumed']);

    desktopLifecycle.emitSystemEvent(DesktopSystemEvent.sessionEnding);
    await pumpEventQueue(times: 10);
    expect(recording.systemLifecycleEvents, [
      'suspending',
      'resumed',
      'sessionEnding',
    ]);
    viewModel.dispose();
    await desktopLifecycle.close();
    await recording.close();
    await preview.close();
  });
}

RecordingSessionViewModel _viewModel({
  required TestMeetingRepository meetings,
  required _RecordingService recording,
  required _PreviewSession preview,
  RecordingTickerFactory? audioLevelTickerFactory,
  RecordingTelemetryGate telemetry = const NoopRecordingTelemetryGate(),
  DesktopLifecycle desktopLifecycle = const NoopDesktopLifecycle(),
  RecordingSystemLifecycle? recordingSystemLifecycle,
}) {
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
    recordingModelId: descriptor.modelId,
    recordingModelVersion: descriptor.version,
  );
  return RecordingSessionViewModel(
    session: StartedMeetingSession(
      meeting: meeting,
      engine: TestAsrEngine(descriptor),
      recordingInput: const LockedRecordingInput.systemDefault(),
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
    audioLevelTickerFactory: audioLevelTickerFactory,
    telemetry: telemetry,
    desktopLifecycle: desktopLifecycle,
    recordingSystemLifecycle: recordingSystemLifecycle ?? recording,
  );
}

final class _DesktopLifecycle implements DesktopLifecycle {
  final StreamController<DesktopExitRequest> _requests =
      StreamController<DesktopExitRequest>.broadcast(sync: true);
  final StreamController<DesktopSystemEvent> _systemEvents =
      StreamController<DesktopSystemEvent>.broadcast(sync: true);
  final List<bool> recordingStates = [];
  final List<String> cancelExitReasons = [];
  int confirmExitCalls = 0;
  bool failWhenDeactivating = false;

  @override
  Stream<DesktopExitRequest> get exitRequests => _requests.stream;

  @override
  Stream<DesktopSystemEvent> get systemEvents => _systemEvents.stream;

  void requestStopAndExit() {
    _requests.add(DesktopExitRequest.stopRecordingAndExit);
  }

  void emitSystemEvent(DesktopSystemEvent event) {
    _systemEvents.add(event);
  }

  @override
  Future<void> setRecordingActive(bool active) async {
    recordingStates.add(active);
    if (!active && failWhenDeactivating) {
      throw StateError('desktop channel failed');
    }
  }

  @override
  Future<void> confirmExit() async {
    confirmExitCalls++;
  }

  @override
  Future<void> cancelExit({required String reason}) async {
    cancelExitReasons.add(reason);
  }

  @override
  Future<void> dispose() async {}

  Future<void> close() async {
    await _requests.close();
    await _systemEvents.close();
  }
}

final class _RecordingTelemetryGate implements RecordingTelemetryGate {
  bool throwOnPreview = false;
  bool throwOnSetActive = false;

  @override
  bool recordingActive = false;

  @override
  void setRecordingActive(bool active) {
    if (throwOnSetActive) {
      throw StateError('configured telemetry failure');
    }
    recordingActive = active;
  }

  @override
  void observePcmWrite({
    required Duration latency,
    required int pendingChunks,
  }) {}

  @override
  void observePreview({
    required int queuedAudioMs,
    required int droppedWindows,
  }) {
    if (throwOnPreview) {
      throw StateError('configured telemetry failure');
    }
  }

  @override
  void recordInterruption() {}

  @override
  void recordRecovery() {}
}

final class _RecordingService
    implements RecordingSessionService, RecordingSystemLifecycle {
  final StreamController<RecordingAudioLevel> _audioLevels =
      StreamController<RecordingAudioLevel>.broadcast(sync: true);
  RecordingState _state = RecordingState.idle;
  Duration durationValue = Duration.zero;
  Object? startError;
  Object? stopError;
  Completer<void>? stopBarrier;
  bool _started = false;
  Duration _audioCapturedThrough = Duration.zero;
  final List<String> systemLifecycleEvents = [];
  Completer<void>? suspendBarrier;

  @override
  Stream<RecordingAudioLevel> get audioLevelChanges => _audioLevels.stream;

  @override
  Duration get duration => durationValue;

  @override
  bool get canFinalize =>
      _started &&
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
  Future<void> handleSystemSuspending() async {
    systemLifecycleEvents.add('suspending');
    await suspendBarrier?.future;
  }

  @override
  Future<void> handleSystemResumed() async {
    systemLifecycleEvents.add('resumed');
  }

  @override
  Future<void> prepareForSystemExit() async {
    systemLifecycleEvents.add('sessionEnding');
  }

  @override
  Future<void> start({required String meetingId}) async {
    final error = startError;
    if (error != null) {
      _state = RecordingState.failed;
      throw error;
    }
    _started = true;
    _state = RecordingState.recording;
  }

  void emitAudioLevel(double level) {
    _audioCapturedThrough += recordingWaveformSampleInterval;
    _audioLevels.add(
      RecordingAudioLevel(level: level, capturedThrough: _audioCapturedThrough),
    );
  }

  Future<void> close() => _audioLevels.close();

  @override
  Future<RecordingArtifact> stop() async {
    await stopBarrier?.future;
    final error = stopError;
    if (error != null) {
      throw error;
    }
    _started = false;
    _state = RecordingState.completed;
    return RecordingArtifact(
      meetingId: 'meeting-1',
      audioPath: '/meetings/meeting-1/fact.pcm',
      bytes: durationValue.inSeconds * recordingBytesPerSecond,
    );
  }
}

final class _ManualPeriodicTicker {
  Timer? _timer;
  void Function(Timer timer)? _callback;

  bool get isActive => _timer?.isActive ?? false;

  Timer create(Duration duration, void Function(Timer timer) callback) {
    expect(duration, recordingWaveformSampleInterval);
    final timer = Timer.periodic(const Duration(days: 1), (_) {});
    _timer = timer;
    _callback = callback;
    return timer;
  }

  void tick() {
    final timer = _timer;
    final callback = _callback;
    if (timer == null || callback == null) {
      throw StateError('ticker 尚未创建');
    }
    callback(timer);
  }
}

final class _PreviewSession implements AsrPreviewSession {
  final StreamController<TranscriptEvent> _events =
      StreamController<TranscriptEvent>.broadcast(sync: true);
  final StreamController<AsrPreviewMetrics> _metrics =
      StreamController<AsrPreviewMetrics>.broadcast(sync: true);
  AsrPreviewMetrics _value = _previewMetrics(AsrPreviewState.ready);
  int initializeCalls = 0;
  int flushCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  Object? stopError;
  Object? disposeError;
  Completer<void>? initializeBarrier;

  @override
  Stream<TranscriptEvent> get events => _events.stream;

  @override
  AsrPreviewMetrics get metrics => _value;

  @override
  Stream<AsrPreviewMetrics> get metricsChanges => _metrics.stream;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    await initializeBarrier?.future;
  }

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
        modelId: senseVoiceDefaultModelId,
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
  Future<void> stop() async {
    stopCalls++;
    final error = stopError;
    stopError = null;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    final error = disposeError;
    disposeError = null;
    if (error != null) {
      throw error;
    }
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
