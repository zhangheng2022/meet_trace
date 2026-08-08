import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/diarization/speaker_diarization_service.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/speaker_diarization.dart';

void main() {
  group('SherpaOnnxSpeakerDiarizationService', () {
    test('把官方秒级片段稳定映射为排序后的说话人时间段', () async {
      final worker = _FakeWorker(
        result: const [
          SpeakerDiarizationWorkerSegment(
            startSeconds: 1,
            endSeconds: 1.8,
            speakerIndex: 1,
          ),
          SpeakerDiarizationWorkerSegment(
            startSeconds: 0,
            endSeconds: 0.9,
            speakerIndex: 0,
          ),
        ],
      );
      final factory = _FakeFactory([worker]);
      final service = _service(factory);

      final turns = await service.diarize(_source());

      expect(
        turns
            .map((turn) => (turn.startMs, turn.endMs, turn.speakerId))
            .toList(),
        [(0, 900, 'speaker-1'), (1000, 1800, 'speaker-2')],
      );
      expect(factory.configs.single.numClusters, -1);
      expect(factory.configs.single.clusteringThreshold, 0.5);
      expect(worker.disposeCalls, 1);
    });

    test('拒绝非 16 kHz 单声道输入且不创建 worker', () async {
      final factory = _FakeFactory([]);
      final service = _service(factory);

      await expectLater(
        service.diarize(
          AudioSource(
            path: '/audio/fact.pcm',
            durationMs: 2000,
            sampleRate: 8000,
          ),
        ),
        _throwsCode('speaker_diarization.invalid_audio'),
      );
      expect(factory.configs, isEmpty);
    });

    test('初始化和推理失败映射为稳定领域错误码', () async {
      final initializationFactory = _FakeFactory(
        [],
        createError: const SpeakerDiarizationWorkerException(
          'speaker_diarization.initialization_failed',
        ),
      );
      await expectLater(
        _service(initializationFactory).diarize(_source()),
        _throwsCode('speaker_diarization.initialization_failed'),
      );

      final inferenceWorker = _FakeWorker(
        error: const SpeakerDiarizationWorkerException(
          'speaker_diarization.inference_failed',
        ),
      );
      await expectLater(
        _service(_FakeFactory([inferenceWorker])).diarize(_source()),
        _throwsCode('speaker_diarization.inference_failed'),
      );
      expect(inferenceWorker.disposeCalls, 1);
    });

    test('取消活动任务会终止 worker 并等待任务收敛', () async {
      final worker = _FakeWorker(pending: true);
      final factory = _FakeFactory([worker]);
      final service = _service(factory);

      final operation = service.diarize(_source());
      await worker.started.future;
      final expectation = expectLater(
        operation,
        _throwsCode('speaker_diarization.cancelled'),
      );
      await service.cancelActive();

      await expectation;
      expect(worker.cancelCalls, 1);
      expect(worker.disposeCalls, 1);
    });

    test('重复任务分别创建和释放独立 worker', () async {
      final first = _FakeWorker(result: const []);
      final second = _FakeWorker(result: const []);
      final factory = _FakeFactory([first, second]);
      final service = _service(factory);

      expect(await service.diarize(_source()), isEmpty);
      expect(await service.diarize(_source()), isEmpty);

      expect(factory.configs, hasLength(2));
      expect(first.disposeCalls, 1);
      expect(second.disposeCalls, 1);
    });

    test('拒绝越界或非有限的原生结果', () async {
      final worker = _FakeWorker(
        result: const [
          SpeakerDiarizationWorkerSegment(
            startSeconds: 0,
            endSeconds: 2.1,
            speakerIndex: 0,
          ),
        ],
      );

      await expectLater(
        _service(_FakeFactory([worker])).diarize(_source()),
        _throwsCode('speaker_diarization.invalid_result'),
      );
    });

    test('释放服务会取消活动任务且后续能力不可用', () async {
      final worker = _FakeWorker(pending: true);
      final factory = _FakeFactory([worker]);
      final service = _service(factory);
      final operation = service.diarize(_source());
      await worker.started.future;
      final expectation = expectLater(
        operation,
        _throwsCode('speaker_diarization.cancelled'),
      );

      await service.dispose();

      await expectation;
      expect(service.capability.isAvailable, isFalse);
      await expectLater(
        service.diarize(_source()),
        _throwsCode('speaker_diarization.disposed'),
      );
    });
  });
}

SherpaOnnxSpeakerDiarizationService _service(_FakeFactory factory) {
  return SherpaOnnxSpeakerDiarizationService(
    config: SherpaOnnxSpeakerDiarizationConfig(
      segmentationModelPath: '/models/segmentation/model.int8.onnx',
      embeddingModelPath: '/models/embedding/3dspeaker.onnx',
      sampleRate: 16000,
      numThreads: 2,
      provider: 'cpu',
      numClusters: -1,
      clusteringThreshold: 0.5,
      minDurationOn: 0.2,
      minDurationOff: 0.5,
    ),
    workerFactory: factory,
  );
}

AudioSource _source() => AudioSource(path: '/audio/fact.pcm', durationMs: 2000);

Matcher _throwsCode(String code) => throwsA(
  isA<SpeakerDiarizationException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);

final class _FakeFactory implements SpeakerDiarizationWorkerFactory {
  _FakeFactory(this.workers, {this.createError});

  final List<_FakeWorker> workers;
  final Object? createError;
  final List<SherpaOnnxSpeakerDiarizationConfig> configs = [];
  final Completer<void> created = Completer<void>();

  @override
  Future<SpeakerDiarizationWorker> create(
    SherpaOnnxSpeakerDiarizationConfig config,
  ) async {
    configs.add(config);
    if (!created.isCompleted) {
      created.complete();
    }
    if (createError case final error?) {
      throw error;
    }
    return workers.removeAt(0);
  }
}

final class _FakeWorker implements SpeakerDiarizationWorker {
  _FakeWorker({this.result = const [], this.error, bool pending = false})
    : _pending = pending
          ? Completer<List<SpeakerDiarizationWorkerSegment>>()
          : null;

  final List<SpeakerDiarizationWorkerSegment> result;
  final Object? error;
  final Completer<List<SpeakerDiarizationWorkerSegment>>? _pending;
  final Completer<void> started = Completer<void>();
  int cancelCalls = 0;
  int disposeCalls = 0;

  @override
  Future<List<SpeakerDiarizationWorkerSegment>> diarize(
    AudioSource source,
  ) async {
    if (!started.isCompleted) {
      started.complete();
    }
    if (_pending case final pending?) {
      return pending.future;
    }
    if (error case final failure?) {
      throw failure;
    }
    return result;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        const SpeakerDiarizationWorkerException(
          'speaker_diarization.cancelled',
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
