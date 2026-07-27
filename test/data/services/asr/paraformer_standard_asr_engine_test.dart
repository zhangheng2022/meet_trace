import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/asr_engine.dart';
import 'package:meettrace/data/services/asr/paraformer_standard_asr_engine.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_adapter.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'meettrace-paraformer-engine-',
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('descriptor 固定使用 Registry 的标准模型并从已验证目录生成配置', () async {
    final workerFactory = _FakeWorkerFactory();
    final engine = _engine(tempDirectory, workerFactory);

    await engine.initialize();

    expect(engine.descriptor, same(AsrModelRegistry.alpha.defaultModel));
    expect(workerFactory.configs, hasLength(1));
    expect(
      workerFactory.configs.single.modelPath,
      p.join(tempDirectory.path, 'model.int8.onnx'),
    );
    expect(
      workerFactory.configs.single.tokensPath,
      p.join(tempDirectory.path, 'tokens.txt'),
    );
    await engine.dispose();
  });

  test('未验证或字节数不匹配的安装记录不能创建 Engine', () {
    final descriptor = AsrModelRegistry.alpha.defaultModel;

    expect(
      () => ParaformerStandardAsrEngine(
        installation: ModelInstallation(
          modelId: descriptor.modelId,
          version: descriptor.version,
          installationType: descriptor.installationType,
          state: ModelInstallationState.failed,
          bytes: descriptor.requiredBytes - 1,
          lastErrorCode: 'model.verification.sha256_mismatch',
        ),
      ),
      throwsA(
        isA<AsrEngineException>().having(
          (error) => error.failure.code,
          'code',
          'asr.paraformer.model_not_verified',
        ),
      ),
    );
  });

  test('输入窗口产生带模型身份和全局区间的转录事件', () async {
    final engine = _engine(
      tempDirectory,
      _FakeWorkerFactory(results: const ['会议结论']),
    );
    final events = <TranscriptEvent>[];
    final subscription = engine.events.listen(events.add);
    await engine.initialize();

    await engine.acceptAudio(
      Float32List(16000),
      sampleRate: 16000,
      startMs: 42000,
    );

    final event = events.single as TranscriptSegmentEvent;
    expect(event.startMs, 42000);
    expect(event.endMs, 43000);
    expect(event.text, '会议结论');
    expect(event.modelId, paraformerStandardModelId);
    expect(event.modelVersion, '2024-03-09');
    expect(event.isFinalForWindow, true);
    await subscription.cancel();
    await engine.dispose();
  });

  test('超过 15 秒的窗口会在进入 adapter 前被拒绝', () async {
    final workerFactory = _FakeWorkerFactory();
    final engine = _engine(tempDirectory, workerFactory);
    await engine.initialize();

    await expectLater(
      engine.acceptAudio(
        Float32List(15 * 16000 + 1),
        sampleRate: 16000,
        startMs: 0,
      ),
      throwsA(
        isA<AsrEngineException>().having(
          (error) => error.failure.code,
          'code',
          'asr.paraformer.window_too_long',
        ),
      ),
    );

    expect(workerFactory.workers.single.recognizeCalls, 0);
    await engine.dispose();
  });

  test('初始化失败返回可恢复错误并允许原实例重试', () async {
    final workerFactory = _FakeWorkerFactory(
      initializationErrors: [StateError('第一次失败'), null],
    );
    final engine = _engine(tempDirectory, workerFactory);

    await expectLater(
      engine.initialize(),
      throwsA(
        isA<AsrEngineException>()
            .having(
              (error) => error.failure.code,
              'code',
              'asr.official.recognizer_initialization_failed',
            )
            .having(
              (error) => error.failure.recoverability.name,
              'recoverability',
              'retryable',
            ),
      ),
    );
    await engine.initialize();

    expect(workerFactory.createCalls, 2);
    expect(engine.metrics.lastErrorCode, isNull);
    await engine.dispose();
  });

  test('并发提交窗口仍按提交顺序发出确定结果', () async {
    final firstGate = Completer<void>();
    final engine = _engine(
      tempDirectory,
      _FakeWorkerFactory(
        results: const ['第一段', '第二段'],
        firstRecognitionGate: firstGate,
      ),
    );
    final texts = <String>[];
    final subscription = engine.events
        .where((event) => event is TranscriptSegmentEvent)
        .cast<TranscriptSegmentEvent>()
        .listen((event) => texts.add(event.text));
    await engine.initialize();

    final first = engine.acceptAudio(
      Float32List(1600),
      sampleRate: 16000,
      startMs: 0,
    );
    final second = engine.acceptAudio(
      Float32List(1600),
      sampleRate: 16000,
      startMs: 100,
    );
    firstGate.complete();
    await Future.wait([first, second]);

    expect(texts, ['第一段', '第二段']);
    await subscription.cancel();
    await engine.dispose();
  });

  test('逐窗口记录空结果、错误、RTF 和版本', () async {
    final engine = _engine(
      tempDirectory,
      _FakeWorkerFactory(
        results: const ['', '不会使用'],
        recognitionErrors: [null, StateError('decode failed')],
        elapsed: const Duration(milliseconds: 200),
      ),
    );
    await engine.initialize();

    await engine.acceptAudio(Float32List(16000), sampleRate: 16000, startMs: 0);
    await expectLater(
      engine.acceptAudio(Float32List(16000), sampleRate: 16000, startMs: 1000),
      throwsA(isA<AsrEngineException>()),
    );

    expect(engine.diagnostics.map((item) => item.outcome), [
      AsrWindowOutcome.empty,
      AsrWindowOutcome.failed,
    ]);
    expect(engine.metrics.totalWindowCount, 2);
    expect(engine.metrics.emptyWindowCount, 1);
    expect(engine.metrics.failedWindowCount, 1);
    expect(engine.metrics.modelVersion, '2024-03-09');
    expect(engine.metrics.realTimeFactor, closeTo(0.1, 0.01));
    expect(engine.metrics.lastErrorCode, 'asr.official.inference_failed');
    await engine.dispose();
  });

  test('完整 PCM16 音频按 15 秒切窗并产生最终快照与进度', () async {
    final audioFile = File(p.join(tempDirectory.path, 'meeting.pcm'));
    await audioFile.writeAsBytes(_pcm16Bytes(16 * 16000), flush: true);
    final engine = _engine(
      tempDirectory,
      _FakeWorkerFactory(results: const ['前十五秒', '最后一秒']),
    );
    final progress = <AsrFinalizationProgress>[];
    final subscription = engine.finalizationProgress.listen(progress.add);
    await engine.initialize();

    final snapshot = await engine.finalizeMeeting(
      AudioSource(path: audioFile.path, durationMs: 16000),
      meetingId: 'meeting-1',
    );

    expect(snapshot.meetingId, 'meeting-1');
    expect(snapshot.actualModelId, paraformerStandardModelId);
    expect(snapshot.status, TranscriptSnapshotStatus.complete);
    expect(snapshot.segments.map((segment) => segment.text), ['前十五秒', '最后一秒']);
    expect(
      snapshot.segments.map((segment) => (segment.startMs, segment.endMs)),
      [(0, 15000), (15000, 16000)],
    );
    expect(progress.map((item) => item.phase), [
      AsrFinalizationPhase.processing,
      AsrFinalizationPhase.processing,
      AsrFinalizationPhase.processing,
      AsrFinalizationPhase.completed,
    ]);
    expect(progress.last.fraction, 1);
    await subscription.cancel();
    await engine.dispose();
  });

  test('取消会标记最终处理进度并拒绝后续窗口', () async {
    final gate = Completer<void>();
    final engine = _engine(
      tempDirectory,
      _FakeWorkerFactory(firstRecognitionGate: gate),
    );
    await engine.initialize();
    final active = engine.acceptAudio(
      Float32List(16000),
      sampleRate: 16000,
      startMs: 0,
    );

    engine.cancel();
    gate.complete();

    await expectLater(active, throwsA(isA<AsrEngineException>()));
    await expectLater(
      engine.acceptAudio(Float32List(16000), sampleRate: 16000, startMs: 1000),
      throwsA(
        isA<AsrEngineException>().having(
          (error) => error.failure.code,
          'code',
          'asr.paraformer.cancelled',
        ),
      ),
    );
    await engine.dispose();
  });
}

ParaformerStandardAsrEngine _engine(
  Directory modelDirectory,
  _FakeWorkerFactory workerFactory,
) {
  final descriptor = AsrModelRegistry.alpha.defaultModel;
  return ParaformerStandardAsrEngine(
    installation: ModelInstallation(
      modelId: descriptor.modelId,
      version: descriptor.version,
      installationType: descriptor.installationType,
      state: ModelInstallationState.installed,
      installedPath: modelDirectory.path,
      verifiedAt: DateTime.utc(2026, 7, 24),
      bytes: descriptor.requiredBytes,
    ),
    workerFactory: workerFactory,
    now: () => DateTime.utc(2026, 7, 24, 12),
  );
}

Uint8List _pcm16Bytes(int sampleCount) {
  final bytes = Uint8List(sampleCount * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < sampleCount; index++) {
    data.setInt16(index * 2, index.isEven ? 1024 : -1024, Endian.little);
  }
  return bytes;
}

final class _FakeWorkerFactory implements SherpaOnnxWorkerFactory {
  _FakeWorkerFactory({
    this.results = const ['测试结果'],
    this.initializationErrors = const [],
    this.recognitionErrors = const [],
    this.elapsed = const Duration(milliseconds: 10),
    this.firstRecognitionGate,
  });

  final List<String> results;
  final List<Object?> initializationErrors;
  final List<Object?> recognitionErrors;
  final Duration elapsed;
  final Completer<void>? firstRecognitionGate;
  final List<SherpaOnnxRecognizerConfig> configs = [];
  final List<_FakeWorker> workers = [];
  int createCalls = 0;

  @override
  Future<SherpaOnnxWorker> create(SherpaOnnxRecognizerConfig config) async {
    final call = createCalls++;
    configs.add(config);
    final initializationError = call < initializationErrors.length
        ? initializationErrors[call]
        : null;
    if (initializationError != null) {
      throw initializationError;
    }
    final worker = _FakeWorker(
      results: results,
      recognitionErrors: recognitionErrors,
      elapsed: elapsed,
      firstRecognitionGate: firstRecognitionGate,
    );
    workers.add(worker);
    return worker;
  }
}

final class _FakeWorker implements SherpaOnnxWorker {
  _FakeWorker({
    required this.results,
    required this.recognitionErrors,
    required this.elapsed,
    required this.firstRecognitionGate,
  });

  final List<String> results;
  final List<Object?> recognitionErrors;
  final Duration elapsed;
  final Completer<void>? firstRecognitionGate;
  int recognizeCalls = 0;

  @override
  Future<SherpaOnnxRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  }) async {
    final call = recognizeCalls++;
    if (call == 0 && firstRecognitionGate != null) {
      await firstRecognitionGate!.future;
    }
    final error = call < recognitionErrors.length
        ? recognitionErrors[call]
        : null;
    if (error != null) {
      throw error;
    }
    final text = call < results.length ? results[call] : results.last;
    return SherpaOnnxRecognition(
      text: text,
      sampleCount: samples.length,
      elapsed: elapsed,
    );
  }

  @override
  Future<void> dispose() async {}
}
