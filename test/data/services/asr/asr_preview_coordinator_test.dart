import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';
import 'package:meettrace/data/services/asr/asr_preview_coordinator.dart';
import 'package:meettrace/data/services/vad/silero_vad_segmenter.dart';
import 'package:meettrace/domain/models/app_failure.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/recording.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/use_cases/plan_asr_preview_windows.dart';

void main() {
  test('连续讲话在 VAD 闭段前给临时字幕并以同一片段稳定修订', () async {
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      results: const ['临时内容', '完整内容'],
    );
    final coordinator = AsrPreviewCoordinator(vad: _LiveVad(), engine: engine);
    final events = <TranscriptSegmentEvent>[];
    final subscription = coordinator.events.listen((event) {
      if (event is TranscriptSegmentEvent) events.add(event);
    });
    await coordinator.initialize();
    await coordinator.add(
      _chunk(startSample: 0, sampleCount: 2 * recordingSampleRate),
    );
    await _waitFor(() => events.isNotEmpty);
    expect(events.single.isFinalForWindow, isFalse);
    expect(events.single.text, '临时内容');
    await coordinator.flush();
    await _waitFor(() => events.length == 2);
    expect(events.last.segmentId, events.first.segmentId);
    expect(events.last.isFinalForWindow, isTrue);
    expect(events.last.text, '完整内容');
    await coordinator.dispose();
    await subscription.cancel();
  });

  test('慢推理只保留最新临时任务且迟到临时结果不覆盖稳定段', () async {
    final gate = Completer<void>();
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      firstGate: gate,
      results: const ['已过期', '稳定结果'],
    );
    final coordinator = AsrPreviewCoordinator(vad: _LiveVad(), engine: engine);
    final events = <TranscriptSegmentEvent>[];
    final subscription = coordinator.events.listen((event) {
      if (event is TranscriptSegmentEvent) events.add(event);
    });
    await coordinator.initialize();
    for (var second = 0; second < 6; second += 2) {
      await coordinator.add(
        _chunk(
          startSample: second * recordingSampleRate,
          sampleCount: 2 * recordingSampleRate,
        ),
      );
    }
    expect(engine.windows, [(0, 2000)]);
    expect(coordinator.metrics.queuedAudioMs, 6000);
    expect(coordinator.coalescedPartialWindows, 1);
    final watch = Stopwatch()..start();
    await coordinator.flush();
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 200)));
    expect(coordinator.coalescedPartialWindows, 2);
    gate.complete();
    await _waitFor(() => events.isNotEmpty);
    expect(events.single.text, '稳定结果');
    expect(events.single.isFinalForWindow, isTrue);
    expect(engine.windows, [(0, 2000), (0, 6000)]);
    await coordinator.dispose();
    await subscription.cancel();
  });

  test('稳定空结果撤回已显示的临时文字', () async {
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      results: const ['临时误识别', ''],
    );
    final coordinator = AsrPreviewCoordinator(vad: _LiveVad(), engine: engine);
    final events = <TranscriptSegmentEvent>[];
    final subscription = coordinator.events.listen((event) {
      if (event is TranscriptSegmentEvent) events.add(event);
    });
    await coordinator.initialize();
    await coordinator.add(
      _chunk(startSample: 0, sampleCount: 2 * recordingSampleRate),
    );
    await _waitFor(() => events.isNotEmpty);
    await coordinator.flush();
    await _waitFor(() => events.length == 2);
    expect(events.last.text, isEmpty);
    expect(events.last.isFinalForWindow, isTrue);
    expect(events.last.segmentId, events.first.segmentId);
    await coordinator.dispose();
    await subscription.cancel();
  });

  test('VAD 软上限不闭段时应用仍硬限窗口并持续处理 30 秒语音', () async {
    final vad = _LiveVad();
    final engine = _FakeAsrEngine(AsrModelRegistry.alpha.defaultModel);
    final coordinator = AsrPreviewCoordinator(vad: vad, engine: engine);
    await coordinator.initialize();
    for (var second = 0; second < 30; second++) {
      await coordinator.add(
        _chunk(
          startSample: second * recordingSampleRate,
          sampleCount: recordingSampleRate,
        ),
      );
      await _waitFor(
        () =>
            !coordinator.isRecognizing &&
            coordinator.metrics.queuedAudioMs == 0,
      );
    }
    await coordinator.flush();
    await _waitFor(
      () =>
          !coordinator.isRecognizing && coordinator.metrics.queuedAudioMs == 0,
    );
    expect(vad.flushCalls, greaterThanOrEqualTo(3));
    expect(
      engine.windows.every((window) => window.$2 - window.$1 <= 15000),
      isTrue,
    );
    expect(engine.windows.last.$2, 30000);
    expect(coordinator.metrics.state, AsrPreviewState.ready);
    expect(coordinator.metrics.droppedPreviewWindows, 0);
    await coordinator.dispose();
  });

  test('等待 VAD 的语音计入新鲜度，单个活动窗不误报积压', () async {
    final partialGate = Completer<void>();
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      firstGate: partialGate,
    );
    final coordinator = AsrPreviewCoordinator(vad: _LiveVad(), engine: engine);
    await coordinator.initialize();
    await coordinator.add(
      _chunk(startSample: 0, sampleCount: recordingSampleRate),
    );
    expect(coordinator.metrics.previewLagMs, 1000);
    expect(coordinator.metrics.queuedAudioMs, 0);
    expect(coordinator.metrics.isRecognizing, isFalse);
    await coordinator.add(
      _chunk(
        startSample: recordingSampleRate,
        sampleCount: recordingSampleRate,
      ),
    );
    expect(coordinator.metrics.queuedAudioMs, 0);
    expect(coordinator.metrics.state, AsrPreviewState.ready);
    expect(coordinator.metrics.previewLagMs, 2000);
    expect(coordinator.metrics.isRecognizing, isTrue);
    partialGate.complete();
    await _waitFor(() => !coordinator.isRecognizing);
    expect(coordinator.metrics.isRecognizing, isFalse);
    await coordinator.dispose();
  });

  test('输入缺口使旧活动推理失效并记录缺失样本数', () async {
    final gate = Completer<void>();
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      firstGate: gate,
      results: const ['缺口前的过期结果', '缺口后'],
    );
    final coordinator = AsrPreviewCoordinator(vad: _LiveVad(), engine: engine);
    final events = <TranscriptSegmentEvent>[];
    final subscription = coordinator.events.listen((event) {
      if (event is TranscriptSegmentEvent) events.add(event);
    });
    await coordinator.initialize();
    await coordinator.add(
      _chunk(startSample: 0, sampleCount: 2 * recordingSampleRate),
    );
    await coordinator.add(
      _chunk(
        startSample: 5 * recordingSampleRate,
        sampleCount: 2 * recordingSampleRate,
      ),
    );
    await coordinator.flush();
    gate.complete();
    await _waitFor(() => events.isNotEmpty);
    expect(events.single.text, '缺口后');
    expect(events.single.startMs, 5000);
    expect(coordinator.missingInputSamples, 3 * recordingSampleRate);
    await coordinator.dispose();
    await subscription.cancel();
  });

  test('两个模型使用完全相同的 VAD 全局区间', () async {
    final standard = _FakeAsrEngine(AsrModelRegistry.alpha.defaultModel);
    final advanced = _FakeAsrEngine(
      AsrModelRegistry.alpha.requireById(senseVoiceDefaultModelId),
    );
    final standardCoordinator = _coordinator(
      engine: standard,
      vad: _ScriptedVad([
        const [VadSpeechSegment(startSample: 1600, endSample: 14400)],
      ]),
    );
    final advancedCoordinator = _coordinator(
      engine: advanced,
      vad: _ScriptedVad([
        const [VadSpeechSegment(startSample: 1600, endSample: 14400)],
      ]),
    );
    await Future.wait([
      standardCoordinator.initialize(),
      advancedCoordinator.initialize(),
    ]);
    final chunk = _chunk(startSample: 0, sampleCount: 16000);

    await standardCoordinator.add(chunk);
    await advancedCoordinator.add(chunk);
    await Future.wait([
      standardCoordinator.flush(),
      advancedCoordinator.flush(),
    ]);

    await _waitFor(
      () =>
          !standardCoordinator.isRecognizing &&
          !advancedCoordinator.isRecognizing,
    );
    expect(standard.windows, advanced.windows);
    expect(standard.windows, [(100, 900)]);
    await standardCoordinator.dispose();
    await advancedCoordinator.dispose();
  });

  test('15 秒重叠窗口产生同一稳定片段的确定性修订', () async {
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      results: const ['今天讨论项目计划', '项目计划已经确认'],
    );
    final coordinator = _coordinator(
      engine: engine,
      vad: _ScriptedVad([
        const [
          VadSpeechSegment(startSample: 0, endSample: 16 * recordingSampleRate),
        ],
      ]),
    );
    await coordinator.initialize();
    final events = <TranscriptSegmentEvent>[];
    final subscription = coordinator.events
        .where((event) => event is TranscriptSegmentEvent)
        .cast<TranscriptSegmentEvent>()
        .listen(events.add);

    await coordinator.add(
      _chunk(startSample: 0, sampleCount: 16 * recordingSampleRate),
    );
    await coordinator.flush();
    await _waitFor(
      () =>
          !coordinator.isRecognizing && coordinator.metrics.queuedAudioMs == 0,
    );

    expect(engine.windows, [(0, 15000), (14500, 16000)]);
    expect(events, hasLength(2));
    expect(events.first.segmentId, events.last.segmentId);
    expect(events.last.text, '今天讨论项目计划已经确认');
    expect(events.last.isFinalForWindow, true);
    await subscription.cancel();
    await coordinator.dispose();
  });

  test('非毫秒对齐窗口仍按 Engine 时间戳归入原分组', () async {
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      results: const ['偏移窗口'],
    );
    final coordinator = _coordinator(
      engine: engine,
      vad: _ScriptedVad([
        const [VadSpeechSegment(startSample: 1, endSample: 16001)],
      ]),
    );
    final events = <TranscriptSegmentEvent>[];
    final subscription = coordinator.events
        .where((event) => event is TranscriptSegmentEvent)
        .cast<TranscriptSegmentEvent>()
        .listen(events.add);
    await coordinator.initialize();

    await coordinator.add(_chunk(startSample: 0, sampleCount: 16001));
    await coordinator.flush();
    await _waitFor(
      () =>
          !coordinator.isRecognizing && coordinator.metrics.queuedAudioMs == 0,
    );

    expect(events.single.segmentId, startsWith('vad-'));
    expect(events.single.text, '偏移窗口');
    await subscription.cancel();
    await coordinator.dispose();
  });

  test('空识别窗口仍完成分组并让最后结果成为最终修订', () async {
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      results: const ['', '后半段'],
    );
    final coordinator = _coordinator(
      engine: engine,
      vad: _ScriptedVad([
        const [
          VadSpeechSegment(startSample: 0, endSample: 16 * recordingSampleRate),
        ],
      ]),
    );
    await coordinator.initialize();
    final events = <TranscriptSegmentEvent>[];
    final subscription = coordinator.events
        .where((event) => event is TranscriptSegmentEvent)
        .cast<TranscriptSegmentEvent>()
        .listen(events.add);

    await coordinator.add(
      _chunk(startSample: 0, sampleCount: 16 * recordingSampleRate),
    );
    await coordinator.flush();
    await _waitFor(
      () =>
          !coordinator.isRecognizing && coordinator.metrics.queuedAudioMs == 0,
    );

    expect(events, hasLength(1));
    expect(events.single.text, '后半段');
    expect(events.single.isFinalForWindow, true);
    await subscription.cancel();
    await coordinator.dispose();
  });

  test('积压按音频时长丢弃最旧待处理窗口并在低水位恢复', () async {
    final firstGate = Completer<void>();
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      firstGate: firstGate,
    );
    final coordinator = _coordinator(
      engine: engine,
      vad: _ScriptedVad([
        const [VadSpeechSegment(startSample: 0, endSample: 16000)],
        const [VadSpeechSegment(startSample: 16000, endSample: 32000)],
        const [VadSpeechSegment(startSample: 32000, endSample: 48000)],
      ]),
      maximumQueuedAudioMs: 2000,
      highWaterMs: 1000,
      lowWaterMs: 500,
    );
    await coordinator.initialize();

    await coordinator.add(_chunk(startSample: 0, sampleCount: 16000));
    await coordinator.add(_chunk(startSample: 16000, sampleCount: 16000));
    await coordinator.add(_chunk(startSample: 32000, sampleCount: 16000));

    expect(coordinator.metrics.state, AsrPreviewState.backlogged);
    expect(coordinator.metrics.queuedAudioMs, 1000);
    expect(coordinator.metrics.droppedPreviewWindows, 1);
    expect(coordinator.metrics.previewLagMs, 3000);

    firstGate.complete();
    await coordinator.flush();
    await _waitFor(
      () =>
          !coordinator.isRecognizing && coordinator.metrics.queuedAudioMs == 0,
    );

    expect(engine.windows, [(0, 1000), (2000, 3000)]);
    expect(coordinator.metrics.state, AsrPreviewState.ready);
    expect(coordinator.metrics.queuedAudioMs, 0);
    expect(coordinator.metrics.processedPreviewWindows, 2);
    expect(coordinator.metrics.previewLagMs, 0);
    await coordinator.dispose();
  });

  test('Engine 故障切换到仅录音且后续音频不再进入推理', () async {
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      failures: {
        0: AsrEngineException(
          AppFailure(
            code: 'asr.preview.test_failure',
            stage: FailureStage.asrInference,
            recoverability: FailureRecoverability.retryable,
            userAction: FailureUserAction.retry,
          ),
        ),
      },
    );
    final vad = _ScriptedVad([
      const [VadSpeechSegment(startSample: 0, endSample: 16000)],
      const [VadSpeechSegment(startSample: 16000, endSample: 32000)],
    ]);
    final coordinator = _coordinator(engine: engine, vad: vad);
    await coordinator.initialize();

    await coordinator.add(_chunk(startSample: 0, sampleCount: 16000));
    await _waitFor(
      () => coordinator.metrics.state == AsrPreviewState.recordingOnly,
    );
    await coordinator.add(_chunk(startSample: 16000, sampleCount: 16000));

    expect(coordinator.metrics.lastErrorCode, 'asr.preview.test_failure');
    expect(engine.windows, [(0, 1000)]);
    expect(vad.acceptCalls, 1);
    await coordinator.dispose();
  });

  test('停止会丢弃积压并在活动推理阻塞时有界返回', () async {
    final firstGate = Completer<void>();
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      firstGate: firstGate,
    );
    final coordinator = _coordinator(
      engine: engine,
      vad: _ScriptedVad([
        const [VadSpeechSegment(startSample: 0, endSample: 16000)],
        const [VadSpeechSegment(startSample: 16000, endSample: 32000)],
      ]),
      stopTimeout: const Duration(milliseconds: 20),
    );
    await coordinator.initialize();

    await coordinator.add(_chunk(startSample: 0, sampleCount: 16000));
    await coordinator.add(_chunk(startSample: 16000, sampleCount: 16000));
    final watch = Stopwatch()..start();

    await coordinator.stop();

    expect(watch.elapsed, lessThan(const Duration(milliseconds: 200)));
    expect(engine.canceled, isTrue);
    expect(coordinator.metrics.state, AsrPreviewState.disposed);
    expect(coordinator.metrics.droppedPreviewWindows, 1);
    await coordinator.stop();
    firstGate.complete();
    await coordinator.dispose();
  });

  test('VAD 释放失败仍继续释放 Engine 且停止保持幂等', () async {
    final engine = _FakeAsrEngine(AsrModelRegistry.alpha.defaultModel);
    final coordinator = _coordinator(
      engine: engine,
      vad: _ScriptedVad(const [], disposeError: StateError('free failed')),
    );

    await coordinator.stop();
    await coordinator.stop();

    expect(engine.canceled, isTrue);
    expect(engine.disposeCalls, 1);
  });

  test('模型初始化完成前保留有界预览队列且不调用未就绪 Engine', () async {
    final initializeGate = Completer<void>();
    final engine = _FakeAsrEngine(
      AsrModelRegistry.alpha.defaultModel,
      initializeGate: initializeGate,
    );
    final coordinator = _coordinator(
      engine: engine,
      vad: _ScriptedVad([
        const [VadSpeechSegment(startSample: 0, endSample: 16000)],
      ]),
    );

    final initializing = coordinator.initialize();
    await coordinator.add(_chunk(startSample: 0, sampleCount: 16000));
    await Future<void>.delayed(Duration.zero);

    expect(engine.windows, isEmpty);
    expect(coordinator.metrics.queuedAudioMs, 1000);

    initializeGate.complete();
    await initializing;
    await coordinator.flush();
    await _waitFor(
      () =>
          !coordinator.isRecognizing && coordinator.metrics.queuedAudioMs == 0,
    );

    expect(engine.windows, [(0, 1000)]);
    await coordinator.dispose();
  });
}

final class _LiveVad implements VoiceActivitySegmenter {
  int _origin = 0;
  int _end = 0;
  int flushCalls = 0;
  @override
  int get sampleRate => recordingSampleRate;
  @override
  bool get isSpeechDetected => _end > _origin;
  @override
  List<VadSpeechSegment> accept(Float32List samples) {
    _end += samples.length;
    return const [];
  }

  @override
  List<VadSpeechSegment> flush() {
    flushCalls++;
    if (_end == _origin) return const [];
    final segment = VadSpeechSegment(startSample: _origin, endSample: _end);
    _origin = _end;
    return [segment];
  }

  @override
  void reset({required int nextStartSample}) {
    _origin = _end = nextStartSample;
  }

  @override
  void dispose() {}
}

AsrPreviewCoordinator _coordinator({
  required _FakeAsrEngine engine,
  required _ScriptedVad vad,
  int maximumQueuedAudioMs = 30000,
  int highWaterMs = 15000,
  int lowWaterMs = 5000,
  Duration stopTimeout = defaultPreviewStopTimeout,
}) {
  return AsrPreviewCoordinator(
    vad: vad,
    engine: engine,
    planner: const AsrPreviewWindowPlanner(
      contextBeforeMs: 0,
      contextAfterMs: 0,
    ),
    maximumQueuedAudioMs: maximumQueuedAudioMs,
    highWaterMs: highWaterMs,
    lowWaterMs: lowWaterMs,
    stopTimeout: stopTimeout,
  );
}

RecordingPcmChunk _chunk({required int startSample, required int sampleCount}) {
  return RecordingPcmChunk(
    bytes: Uint8List(sampleCount * recordingBytesPerSample),
    startByteOffset: startSample * recordingBytesPerSample,
  );
}

Future<void> _waitFor(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 2)) {
      fail('等待条件超时');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

final class _ScriptedVad implements VoiceActivitySegmenter {
  _ScriptedVad(Iterable<List<VadSpeechSegment>> outputs, {this.disposeError})
    : _outputs = Queue.of(outputs);

  final Queue<List<VadSpeechSegment>> _outputs;
  int _acceptedThroughSample = 0;
  int acceptCalls = 0;
  int resetCalls = 0;
  bool disposed = false;
  final Object? disposeError;

  @override
  int get sampleRate => recordingSampleRate;

  @override
  bool get isSpeechDetected => false;

  @override
  List<VadSpeechSegment> accept(Float32List samples) {
    acceptCalls++;
    _acceptedThroughSample += samples.length;
    if (_outputs.isNotEmpty &&
        _outputs.first.isNotEmpty &&
        _outputs.first.last.endSample > _acceptedThroughSample) {
      return const [];
    }
    return _outputs.isEmpty ? const [] : _outputs.removeFirst();
  }

  @override
  List<VadSpeechSegment> flush() => const [];

  @override
  void reset({required int nextStartSample}) {
    resetCalls++;
    _acceptedThroughSample = nextStartSample;
  }

  @override
  void dispose() {
    disposed = true;
    final error = disposeError;
    if (error != null) {
      throw error;
    }
  }
}

final class _FakeAsrEngine implements AsrEngine {
  _FakeAsrEngine(
    this.descriptor, {
    this.results = const ['测试文本'],
    this.failures = const {},
    this.firstGate,
    this.initializeGate,
  });

  @override
  final AsrModelDescriptor descriptor;
  final List<String> results;
  final Map<int, Object> failures;
  final Completer<void>? firstGate;
  final Completer<void>? initializeGate;
  final StreamController<TranscriptEvent> _events =
      StreamController<TranscriptEvent>.broadcast(sync: true);
  final List<(int, int)> windows = [];
  bool canceled = false;
  int disposeCalls = 0;

  @override
  Stream<TranscriptEvent> get events => _events.stream;

  @override
  Stream<AsrFinalizationProgress> get finalizationProgress =>
      const Stream.empty();

  @override
  AsrDeviceRiskState get deviceRisk => const AsrDeviceRiskState.supported();

  @override
  Stream<AsrDeviceRiskState> get deviceRisks => const Stream.empty();

  @override
  List<AsrWindowDiagnostic> get diagnostics => const [];

  @override
  AsrEngineMetrics get metrics => AsrEngineMetrics(
    modelId: descriptor.modelId,
    modelVersion: descriptor.version,
    totalWindowCount: windows.length,
    recognizedWindowCount: windows.length,
    emptyWindowCount: 0,
    failedWindowCount: 0,
    totalAudioDuration: Duration.zero,
    totalInferenceDuration: Duration.zero,
  );

  @override
  Future<void> initialize() async {
    await initializeGate?.future;
  }

  @override
  Future<void> acceptAudio(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  }) async {
    final call = windows.length;
    final endMs =
        startMs +
        (samples.length * Duration.millisecondsPerSecond + sampleRate - 1) ~/
            sampleRate;
    windows.add((startMs, endMs));
    if (call == 0 && firstGate != null) {
      await firstGate!.future;
    }
    final failure = failures[call];
    if (failure != null) {
      throw failure;
    }
    final text = call < results.length ? results[call] : results.last;
    if (text.isEmpty) {
      return;
    }
    _events.add(
      TranscriptSegmentEvent(
        segmentId: 'engine-$call',
        startMs: startMs,
        endMs: endMs,
        text: text,
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        isFinalForWindow: true,
      ),
    );
  }

  @override
  Future<TranscriptSnapshot> finalizeMeeting(
    AudioSource source, {
    required String meetingId,
    String? snapshotId,
  }) {
    throw UnimplementedError();
  }

  @override
  void cancel() {
    canceled = true;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _events.close();
  }
}
