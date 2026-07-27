import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_adapter.dart';
import 'package:meettrace/domain/models/app_failure.dart';

void main() {
  final config = SherpaOnnxRecognizerConfig.paraformer(
    modelId: 'paraformer',
    modelVersion: '1',
    modelPath: '/models/model.int8.onnx',
    tokensPath: '/models/tokens.txt',
  );

  test('fake worker 完成初始化、识别、释放并允许新 adapter 重复创建', () async {
    final factory = _FakeWorkerFactory();
    final first = SherpaOnnxAdapter(workerFactory: factory);

    await first.initialize(config);
    final result = await first.recognize(
      Float32List.fromList([0.1, -0.1]),
      sampleRate: 16000,
    );
    await first.dispose();

    final second = SherpaOnnxAdapter(workerFactory: factory);
    await second.initialize(config);
    await second.dispose();

    expect(result.text, '测试结果');
    expect(result.sampleCount, 2);
    expect(result.elapsed, const Duration(milliseconds: 12));
    expect(factory.createdWorkers, 2);
    expect(factory.workers.every((worker) => worker.disposeCalls == 1), true);
  });

  test('并发识别请求在后台 worker 上按提交顺序串行执行', () async {
    final worker = _FakeWorker();
    final adapter = SherpaOnnxAdapter(
      workerFactory: _FakeWorkerFactory(worker: worker),
    );
    await adapter.initialize(config);

    final results = await Future.wait([
      adapter.recognize(Float32List(160), sampleRate: 16000),
      adapter.recognize(Float32List(320), sampleRate: 16000),
    ]);
    await adapter.dispose();

    expect(results.map((result) => result.sampleCount), [160, 320]);
    expect(worker.maximumConcurrentRecognitions, 1);
  });

  test('worker 初始化和推理异常不会把第三方异常类型暴露给调用方', () async {
    final initializationAdapter = SherpaOnnxAdapter(
      workerFactory: _FakeWorkerFactory(
        worker: _FakeWorker(initializeError: FormatException('bad model')),
      ),
    );

    await expectLater(
      initializationAdapter.initialize(config),
      throwsA(
        isA<SherpaOnnxAdapterException>()
            .having(
              (error) => error.failure.code,
              'code',
              'asr.official.recognizer_initialization_failed',
            )
            .having(
              (error) => error.failure.stage,
              'stage',
              FailureStage.asrInitialization,
            ),
      ),
    );

    final inferenceAdapter = SherpaOnnxAdapter(
      workerFactory: _FakeWorkerFactory(
        worker: _FakeWorker(recognizeError: StateError('decode failed')),
      ),
    );
    await inferenceAdapter.initialize(config);

    await expectLater(
      inferenceAdapter.recognize(Float32List(16), sampleRate: 16000),
      throwsA(
        isA<SherpaOnnxAdapterException>()
            .having(
              (error) => error.failure.code,
              'code',
              'asr.official.inference_failed',
            )
            .having(
              (error) => error.failure.diagnosticContext['errorType'],
              'errorType',
              'StateError',
            ),
      ),
    );
    await inferenceAdapter.dispose();
  });

  test('应用级取消丢弃活动结果并拒绝后续推理', () async {
    final gate = Completer<void>();
    final worker = _FakeWorker(recognitionGate: gate);
    final adapter = SherpaOnnxAdapter(
      workerFactory: _FakeWorkerFactory(worker: worker),
    );
    await adapter.initialize(config);

    final active = adapter.recognize(Float32List(160), sampleRate: 16000);
    await worker.recognitionStarted.future;
    adapter.cancel();
    gate.complete();

    await expectLater(
      active,
      throwsA(
        isA<SherpaOnnxAdapterException>().having(
          (error) => error.failure.code,
          'code',
          'asr.official.cancelled',
        ),
      ),
    );
    await expectLater(
      adapter.recognize(Float32List(16), sampleRate: 16000),
      throwsA(isA<SherpaOnnxAdapterException>()),
    );
    await adapter.dispose();
  });
}

final class _FakeWorkerFactory implements SherpaOnnxWorkerFactory {
  _FakeWorkerFactory({this.worker});

  final _FakeWorker? worker;
  final List<_FakeWorker> workers = [];
  int createdWorkers = 0;

  @override
  Future<SherpaOnnxWorker> create(SherpaOnnxRecognizerConfig config) async {
    createdWorkers++;
    final created = worker ?? _FakeWorker();
    workers.add(created);
    await created.initialize(config);
    return created;
  }
}

final class _FakeWorker implements SherpaOnnxWorker {
  _FakeWorker({
    this.initializeError,
    this.recognizeError,
    this.recognitionGate,
  });

  final Object? initializeError;
  final Object? recognizeError;
  final Completer<void>? recognitionGate;
  final Completer<void> recognitionStarted = Completer<void>();

  int disposeCalls = 0;
  int _activeRecognitions = 0;
  int maximumConcurrentRecognitions = 0;

  Future<void> initialize(SherpaOnnxRecognizerConfig config) async {
    final error = initializeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<SherpaOnnxRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  }) async {
    _activeRecognitions++;
    if (_activeRecognitions > maximumConcurrentRecognitions) {
      maximumConcurrentRecognitions = _activeRecognitions;
    }
    if (!recognitionStarted.isCompleted) {
      recognitionStarted.complete();
    }
    try {
      final gate = recognitionGate;
      if (gate != null) {
        await gate.future;
      }
      final error = recognizeError;
      if (error != null) {
        throw error;
      }
      return SherpaOnnxRecognition(
        text: '测试结果',
        sampleCount: samples.length,
        elapsed: const Duration(milliseconds: 12),
      );
    } finally {
      _activeRecognitions--;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
