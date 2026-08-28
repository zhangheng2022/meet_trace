import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_adapter.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_asr_engine.dart';
import 'package:meettrace/data/services/vad/silero_vad_segmenter.dart';
import 'package:meettrace/domain/models/app_failure.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';

void main() {
  late Directory root;
  late _FakeWorker worker;
  late _FakeWorkerFactory workerFactory;
  late SherpaOnnxAsrEngine engine;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-sherpa-engine-');
    worker = _FakeWorker();
    workerFactory = _FakeWorkerFactory(worker);
    engine = _createEngine(workerFactory: workerFactory);
  });

  tearDown(() async {
    await engine.dispose();
    await root.delete(recursive: true);
  });

  test('预览窗口输出修剪后的时间片段并累计诊断与 RTF', () async {
    worker.texts.add('  会议开始  ');
    await engine.initialize();
    final eventFuture = engine.events.first;

    await engine.acceptAudio(
      Float32List(sherpaOnnxAsrSampleRate),
      sampleRate: sherpaOnnxAsrSampleRate,
      startMs: 1250,
    );

    final event = await eventFuture as TranscriptSegmentEvent;
    expect(event.segmentId, 'preview-1-1250-2250');
    expect(event.startMs, 1250);
    expect(event.endMs, 2250);
    expect(event.text, '会议开始');
    expect(event.modelId, _descriptor.modelId);
    expect(event.modelVersion, _descriptor.version);
    expect(event.isFinalForWindow, isTrue);

    expect(worker.sampleWindows.single.length, sherpaOnnxAsrSampleRate);
    expect(worker.sampleRates, [sherpaOnnxAsrSampleRate]);
    expect(engine.diagnostics.single.outcome, AsrWindowOutcome.recognized);
    expect(engine.metrics.totalWindowCount, 1);
    expect(engine.metrics.recognizedWindowCount, 1);
    expect(engine.metrics.totalAudioDuration, const Duration(seconds: 1));
    expect(
      engine.metrics.totalInferenceDuration,
      const Duration(milliseconds: 8),
    );
    expect(engine.metrics.realTimeFactor, closeTo(0.008, 0.000001));
  });

  test('空识别结果不发布片段但仍记录空窗口指标', () async {
    worker.texts.add('   ');
    final events = <TranscriptEvent>[];
    final subscription = engine.events.listen(events.add);
    addTearDown(subscription.cancel);
    await engine.initialize();

    await engine.acceptAudio(
      Float32List(8000),
      sampleRate: sherpaOnnxAsrSampleRate,
      startMs: 0,
    );

    expect(events, isEmpty);
    expect(engine.metrics.emptyWindowCount, 1);
    expect(engine.metrics.recognizedWindowCount, 0);
    expect(engine.diagnostics.single.outcome, AsrWindowOutcome.empty);
    expect(engine.diagnostics.single.endMs, 500);
  });

  test('无效窗口在进入 worker 前以稳定错误码拒绝', () async {
    await engine.initialize();

    await expectLater(
      engine.acceptAudio(Float32List(16), sampleRate: 8000, startMs: 0),
      throwsA(_failure('asr.test.invalid_audio_window')),
    );
    await expectLater(
      engine.acceptAudio(
        Float32List(sherpaOnnxMaximumWindowSamples + 1),
        sampleRate: sherpaOnnxAsrSampleRate,
        startMs: 0,
      ),
      throwsA(_failure('asr.test.window_too_long')),
    );

    expect(worker.sampleWindows, isEmpty);
    expect(engine.metrics.totalWindowCount, 0);
  });

  test('worker 推理失败映射为 Engine 异常并写入失败诊断', () async {
    worker.recognizeError = StateError('decode failed');
    await engine.initialize();

    await expectLater(
      engine.acceptAudio(
        Float32List(1600),
        sampleRate: sherpaOnnxAsrSampleRate,
        startMs: 300,
      ),
      throwsA(
        _failure(
          'asr.official.inference_failed',
          stage: FailureStage.asrInference,
        ),
      ),
    );

    expect(engine.metrics.failedWindowCount, 1);
    expect(engine.metrics.lastErrorCode, 'asr.official.inference_failed');
    expect(engine.diagnostics.single.outcome, AsrWindowOutcome.failed);
    expect(
      engine.diagnostics.single.errorCode,
      'asr.official.inference_failed',
    );
    expect(engine.diagnostics.single.startMs, 300);
    expect(engine.diagnostics.single.endMs, 400);
  });

  test('最终转录解码 PCM16 并按 VAD 片段生成确定时间轴', () async {
    worker.texts.add(' 最终结果 ');
    final sampleCount = sherpaOnnxAsrSampleRate;
    final source = await _writePcm16(root, sampleCount);
    final createdAt = DateTime.utc(2026, 8, 3, 9, 30);
    await engine.dispose();
    engine = _createEngine(
      workerFactory: workerFactory,
      now: () => createdAt,
      finalVadFactory: () => _FakeVad(
        segments: [VadSpeechSegment(startSample: 0, endSample: sampleCount)],
      ),
    );
    final progress = <AsrFinalizationProgress>[];
    final subscription = engine.finalizationProgress.listen(progress.add);
    addTearDown(subscription.cancel);
    await engine.initialize();

    final snapshot = await engine.finalizeMeeting(
      source,
      meetingId: 'meeting-1',
      snapshotId: 'snapshot-1',
    );

    expect(snapshot.id, 'snapshot-1');
    expect(snapshot.meetingId, 'meeting-1');
    expect(snapshot.createdAt, createdAt);
    expect(snapshot.status, TranscriptSnapshotStatus.complete);
    expect(snapshot.segments, hasLength(1));
    expect(snapshot.segments.map((segment) => segment.id), [
      'snapshot-1-segment-1',
    ]);
    expect(
      snapshot.segments.map((segment) => (segment.startMs, segment.endMs)),
      [(0, 1000)],
    );
    expect(snapshot.segments.single.text, '最终结果');
    expect(worker.sampleWindows.single.length, sherpaOnnxAsrSampleRate);
    expect(worker.sampleWindows.first[0], -1);
    expect(worker.sampleWindows.first[1], 0.5);
    expect(progress.map((value) => value.phase), [
      AsrFinalizationPhase.processing,
      AsrFinalizationPhase.processing,
      AsrFinalizationPhase.completed,
    ]);
    expect(progress.last.completedSamples, sampleCount);
    expect(progress.last.fraction, 1);
  });

  test('全静音最终音频生成空快照且不初始化 SenseVoice', () async {
    final source = await _writePcm16(root, sherpaOnnxAsrSampleRate);
    await engine.dispose();
    engine = _createEngine(
      workerFactory: workerFactory,
      finalVadFactory: () => _FakeVad(),
    );

    final snapshot = await engine.finalizeMeeting(
      source,
      meetingId: 'silent-meeting',
      snapshotId: 'silent-snapshot',
    );

    expect(snapshot.status, TranscriptSnapshotStatus.complete);
    expect(snapshot.segments, isEmpty);
    expect(workerFactory.createCalls, 0);
    expect(worker.sampleWindows, isEmpty);
  });

  test('最终 VAD 语音区间加入上下文且延迟到首段语音初始化', () async {
    worker.texts.add('语音内容');
    final source = await _writePcm16(root, sherpaOnnxAsrSampleRate);
    await engine.dispose();
    engine = _createEngine(
      workerFactory: workerFactory,
      finalVadFactory: () => _FakeVad(
        segments: const [VadSpeechSegment(startSample: 3200, endSample: 8000)],
      ),
    );

    final snapshot = await engine.finalizeMeeting(
      source,
      meetingId: 'speech-meeting',
      snapshotId: 'speech-snapshot',
    );

    expect(workerFactory.createCalls, 1);
    expect(worker.sampleWindows.single.length, 11200);
    expect(
      snapshot.segments.map((segment) => (segment.startMs, segment.endMs)),
      [(200, 500)],
    );
  });

  test('相邻 VAD 片段保持独立窗口和最终片段', () async {
    worker.texts.addAll(['第一段', '第二段']);
    final sampleCount = 16 * sherpaOnnxAsrSampleRate;
    final source = await _writePcm16(root, sampleCount);
    await engine.dispose();
    engine = _createEngine(
      workerFactory: workerFactory,
      finalVadFactory: () => _FakeVad(
        segments: [
          const VadSpeechSegment(
            startSample: 0,
            endSample: 8 * sherpaOnnxAsrSampleRate,
          ),
          VadSpeechSegment(
            startSample: 8 * sherpaOnnxAsrSampleRate,
            endSample: sampleCount,
          ),
        ],
      ),
    );

    final snapshot = await engine.finalizeMeeting(
      source,
      meetingId: 'long-speech',
      snapshotId: 'long-snapshot',
    );

    expect(worker.sampleWindows.map((samples) => samples.length), [
      8 * sherpaOnnxAsrSampleRate + 3200,
      8 * sherpaOnnxAsrSampleRate + 3200,
    ]);
    expect(snapshot.segments, hasLength(2));
    expect(snapshot.segments.map((segment) => segment.text), ['第一段', '第二段']);
    expect(
      snapshot.segments.map((segment) => (segment.startMs, segment.endMs)),
      [(0, 8000), (8000, 16000)],
    );
  });

  test('最终 VAD 失败时拒绝发布低质量固定窗口结果', () async {
    final source = await _writePcm16(root, sherpaOnnxAsrSampleRate);
    await engine.dispose();
    engine = _createEngine(
      workerFactory: workerFactory,
      finalVadFactory: () => _FakeVad(acceptError: StateError('vad failed')),
    );

    await expectLater(
      engine.finalizeMeeting(
        source,
        meetingId: 'vad-failure',
        snapshotId: 'failed-snapshot',
      ),
      throwsA(
        _failure(
          'asr.test.final_vad_failed',
          stage: FailureStage.finalTranscription,
        ),
      ),
    );

    expect(workerFactory.createCalls, 0);
    expect(worker.sampleWindows, isEmpty);
  });

  test('最终 VAD 缺失时以稳定错误码拒绝转录', () async {
    final source = await _writePcm16(root, sherpaOnnxAsrSampleRate);

    await expectLater(
      engine.finalizeMeeting(source, meetingId: 'vad-unavailable'),
      throwsA(
        _failure(
          'asr.test.final_vad_unavailable',
          stage: FailureStage.finalTranscription,
        ),
      ),
    );

    expect(workerFactory.createCalls, 0);
  });

  test('最终 VAD 释放失败不丢弃已生成的语音片段', () async {
    worker.texts.add('释放失败仍可识别');
    final source = await _writePcm16(root, sherpaOnnxAsrSampleRate);
    await engine.dispose();
    engine = _createEngine(
      workerFactory: workerFactory,
      finalVadFactory: () => _FakeVad(
        segments: const [
          VadSpeechSegment(startSample: 0, endSample: sherpaOnnxAsrSampleRate),
        ],
        disposeError: StateError('dispose failed'),
      ),
    );

    final snapshot = await engine.finalizeMeeting(
      source,
      meetingId: 'vad-dispose-failure',
    );

    expect(snapshot.segments.single.text, '释放失败仍可识别');
    expect(engine.metrics.lastErrorCode, 'asr.test.final_vad_dispose_failed');
  });

  test('不支持的设备风险在创建 worker 前阻断初始化', () async {
    await engine.dispose();
    engine = _createEngine(
      workerFactory: workerFactory,
      riskMonitor: const _FixedRiskMonitor(
        AsrDeviceRiskState(
          support: AsrDeviceSupport.unsupported,
          memoryPressure: AsrMemoryPressure.warning,
          thermalState: AsrThermalState.serious,
          processRssBytes: 512,
          estimatedAvailableBytes: 1024,
        ),
      ),
    );

    await expectLater(
      engine.initialize(),
      throwsA(
        _failure(
          'asr.test.device_unsupported',
          stage: FailureStage.asrInitialization,
        ),
      ),
    );

    expect(workerFactory.createCalls, 0);
    expect(engine.deviceRisk.support, AsrDeviceSupport.unsupported);
    expect(engine.metrics.lastErrorCode, 'asr.test.device_unsupported');
  });

  test('取消进行中的最终转录会丢弃结果并发布 canceled 终态', () async {
    final recognitionGate = Completer<void>();
    worker.recognitionGate = recognitionGate;
    worker.texts.add('不会提交');
    final source = await _writePcm16(root, 16000);
    await engine.dispose();
    engine = _createEngine(
      workerFactory: workerFactory,
      finalVadFactory: () => _FakeVad(
        segments: const [VadSpeechSegment(startSample: 0, endSample: 16000)],
      ),
    );
    final progress = <AsrFinalizationProgress>[];
    final subscription = engine.finalizationProgress.listen(progress.add);
    addTearDown(subscription.cancel);
    await engine.initialize();

    final finalizing = engine.finalizeMeeting(
      source,
      meetingId: 'meeting-cancel',
    );
    await worker.recognitionStarted.future;
    engine.cancel();
    recognitionGate.complete();

    await expectLater(finalizing, throwsA(_failure('asr.official.cancelled')));
    expect(progress.last.phase, AsrFinalizationPhase.canceled);
    expect(engine.metrics.failedWindowCount, 1);
    expect(engine.metrics.lastErrorCode, 'asr.official.cancelled');
  });

  test('并发初始化只创建一个 worker，释放操作保持幂等', () async {
    final createGate = Completer<void>();
    workerFactory.createGate = createGate;
    var beforeOperationCalls = 0;
    var disposeHookCalls = 0;
    await engine.dispose();
    engine = _createEngine(
      workerFactory: workerFactory,
      beforeOperation: () async => beforeOperationCalls++,
      onDispose: () async => disposeHookCalls++,
    );

    final first = engine.initialize();
    final second = engine.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(workerFactory.createCalls, 1);
    createGate.complete();
    await Future.wait([first, second]);

    await engine.dispose();
    await engine.dispose();

    expect(beforeOperationCalls, 1);
    expect(worker.disposeCalls, 1);
    expect(disposeHookCalls, 1);
  });

  test('初始化尚未返回时 dispose 等待并释放随后创建的 worker', () async {
    final createGate = Completer<void>();
    workerFactory.createGate = createGate;

    final initializing = engine.initialize();
    await Future<void>.delayed(Duration.zero);
    final disposing = engine.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(worker.disposeCalls, 0);
    createGate.complete();
    await initializing;
    await disposing;

    expect(worker.disposeCalls, 1);
  });
}

final _descriptor = AsrModelDescriptor(
  modelId: 'sense-voice-test',
  displayName: 'SenseVoice Test',
  version: '1',
  supportedLanguages: const ['zh', 'en'],
  installationType: AsrInstallationType.downloadable,
  requiredBytes: 1,
  capabilities: const {'transcription'},
);

final _config = SherpaOnnxRecognizerConfig.senseVoice(
  modelId: _descriptor.modelId,
  modelVersion: _descriptor.version,
  modelPath: '/models/model.int8.onnx',
  tokensPath: '/models/tokens.txt',
);

SherpaOnnxAsrEngine _createEngine({
  required SherpaOnnxWorkerFactory workerFactory,
  AsrDeviceRiskMonitor? riskMonitor,
  AsrEngineLifecycleHook? beforeOperation,
  AsrEngineLifecycleHook? onDispose,
  DateTime Function()? now,
  FinalVadFactory? finalVadFactory,
}) {
  return SherpaOnnxAsrEngine(
    descriptor: _descriptor,
    config: _config,
    errorPrefix: 'asr.test',
    workerFactory: workerFactory,
    riskMonitor: riskMonitor,
    beforeOperation: beforeOperation,
    onDispose: onDispose,
    finalVadFactory: finalVadFactory,
    now: now,
  );
}

final class _FakeVad implements VoiceActivitySegmenter {
  _FakeVad({this.segments = const [], this.acceptError, this.disposeError});

  final List<VadSpeechSegment> segments;
  final Object? acceptError;
  final Object? disposeError;

  @override
  int get sampleRate => sherpaOnnxAsrSampleRate;

  @override
  List<VadSpeechSegment> accept(Float32List samples) {
    final error = acceptError;
    if (error != null) {
      throw error;
    }
    return const [];
  }

  @override
  List<VadSpeechSegment> flush() => segments;

  @override
  void reset({required int nextStartSample}) {}

  @override
  void dispose() {
    final error = disposeError;
    if (error != null) {
      throw error;
    }
  }
}

Matcher _failure(String code, {FailureStage? stage}) {
  var matcher = isA<AsrEngineException>().having(
    (error) => error.failure.code,
    'code',
    code,
  );
  if (stage != null) {
    matcher = matcher.having((error) => error.failure.stage, 'stage', stage);
  }
  return matcher;
}

Future<AudioSource> _writePcm16(Directory root, int sampleCount) async {
  final bytes = Uint8List(sampleCount * 2);
  final pcm = ByteData.sublistView(bytes);
  pcm.setInt16(0, -32768, Endian.little);
  if (sampleCount > 1) {
    pcm.setInt16(2, 16384, Endian.little);
  }
  final file = File('${root.path}${Platform.pathSeparator}audio.pcm');
  await file.writeAsBytes(bytes, flush: true);
  return AudioSource(
    path: file.path,
    durationMs:
        (sampleCount * 1000 + sherpaOnnxAsrSampleRate - 1) ~/
        sherpaOnnxAsrSampleRate,
  );
}

final class _FakeWorkerFactory implements SherpaOnnxWorkerFactory {
  _FakeWorkerFactory(this.worker);

  final _FakeWorker worker;
  Completer<void>? createGate;
  int createCalls = 0;

  @override
  Future<SherpaOnnxWorker> create(SherpaOnnxRecognizerConfig config) async {
    createCalls++;
    final gate = createGate;
    if (gate != null) {
      await gate.future;
    }
    return worker;
  }
}

final class _FakeWorker implements SherpaOnnxWorker {
  final List<String> texts = [];
  final List<Float32List> sampleWindows = [];
  final List<int> sampleRates = [];
  final Completer<void> recognitionStarted = Completer<void>();
  Object? recognizeError;
  Completer<void>? recognitionGate;
  int disposeCalls = 0;

  @override
  Future<SherpaOnnxRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  }) async {
    sampleWindows.add(Float32List.fromList(samples));
    sampleRates.add(sampleRate);
    if (!recognitionStarted.isCompleted) {
      recognitionStarted.complete();
    }
    final gate = recognitionGate;
    if (gate != null) {
      await gate.future;
    }
    final error = recognizeError;
    if (error != null) {
      throw error;
    }
    return SherpaOnnxRecognition(
      text: texts.isEmpty ? '识别结果' : texts.removeAt(0),
      sampleCount: samples.length,
      elapsed: const Duration(milliseconds: 8),
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

final class _FixedRiskMonitor implements AsrDeviceRiskMonitor {
  const _FixedRiskMonitor(this.risk);

  final AsrDeviceRiskState risk;

  @override
  Stream<AsrDeviceRiskState> get changes => const Stream.empty();

  @override
  Future<AsrDeviceRiskState> inspect() async => risk;
}
