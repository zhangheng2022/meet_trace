import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/asr/asr_engine.dart';
import 'package:meetily_ai/data/services/asr/asr_preview_coordinator.dart';
import 'package:meetily_ai/data/services/vad/silero_vad_segmenter.dart';
import 'package:meetily_ai/domain/models/app_failure.dart';
import 'package:meetily_ai/domain/models/asr_model.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/asr_preview.dart';
import 'package:meetily_ai/domain/models/audio_source.dart';
import 'package:meetily_ai/domain/models/recording.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/use_cases/plan_asr_preview_windows.dart';

void main() {
  test('两个模型使用完全相同的 VAD 全局区间', () async {
    final standard = _FakeAsrEngine(AsrModelRegistry.alpha.defaultModel);
    final advanced = _FakeAsrEngine(
      AsrModelRegistry.alpha.requireById(qwenAdvancedModelId),
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
    final chunk = _chunk(startSample: 0, sampleCount: 16000);

    await standardCoordinator.add(chunk);
    await advancedCoordinator.add(chunk);
    await Future.wait([
      standardCoordinator.flush(),
      advancedCoordinator.flush(),
    ]);

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
    final events = <TranscriptSegmentEvent>[];
    final subscription = coordinator.events
        .where((event) => event is TranscriptSegmentEvent)
        .cast<TranscriptSegmentEvent>()
        .listen(events.add);

    await coordinator.add(
      _chunk(startSample: 0, sampleCount: 16 * recordingSampleRate),
    );
    await coordinator.flush();

    expect(engine.windows, [(0, 15000), (14500, 16000)]);
    expect(events, hasLength(2));
    expect(events.first.segmentId, events.last.segmentId);
    expect(events.last.text, '今天讨论项目计划已经确认');
    expect(events.last.isFinalForWindow, true);
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
    final events = <TranscriptSegmentEvent>[];
    final subscription = coordinator.events
        .where((event) => event is TranscriptSegmentEvent)
        .cast<TranscriptSegmentEvent>()
        .listen(events.add);

    await coordinator.add(
      _chunk(startSample: 0, sampleCount: 16 * recordingSampleRate),
    );
    await coordinator.flush();

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

    await coordinator.add(_chunk(startSample: 0, sampleCount: 16000));
    await coordinator.add(_chunk(startSample: 16000, sampleCount: 16000));
    await coordinator.add(_chunk(startSample: 32000, sampleCount: 16000));

    expect(coordinator.metrics.state, AsrPreviewState.backlogged);
    expect(coordinator.metrics.queuedAudioMs, 2000);
    expect(coordinator.metrics.droppedPreviewWindows, 1);

    firstGate.complete();
    await coordinator.flush();

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
}

AsrPreviewCoordinator _coordinator({
  required _FakeAsrEngine engine,
  required _ScriptedVad vad,
  int maximumQueuedAudioMs = 30000,
  int highWaterMs = 15000,
  int lowWaterMs = 5000,
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
  _ScriptedVad(Iterable<List<VadSpeechSegment>> outputs)
    : _outputs = Queue.of(outputs);

  final Queue<List<VadSpeechSegment>> _outputs;
  int acceptCalls = 0;
  int resetCalls = 0;
  bool disposed = false;

  @override
  int get sampleRate => recordingSampleRate;

  @override
  List<VadSpeechSegment> accept(Float32List samples) {
    acceptCalls++;
    return _outputs.isEmpty ? const [] : _outputs.removeFirst();
  }

  @override
  List<VadSpeechSegment> flush() => const [];

  @override
  void reset({required int nextStartSample}) {
    resetCalls++;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

final class _FakeAsrEngine implements AsrEngine {
  _FakeAsrEngine(
    this.descriptor, {
    this.results = const ['测试文本'],
    this.failures = const {},
    this.firstGate,
  });

  @override
  final AsrModelDescriptor descriptor;
  final List<String> results;
  final Map<int, Object> failures;
  final Completer<void>? firstGate;
  final StreamController<TranscriptEvent> _events =
      StreamController<TranscriptEvent>.broadcast(sync: true);
  final List<(int, int)> windows = [];
  bool canceled = false;

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
  Future<void> initialize() async {}

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
  }) {
    throw UnimplementedError();
  }

  @override
  void cancel() {
    canceled = true;
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}
