import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../domain/models/audio_source.dart';
import 'speaker_diarization_worker.dart';

final class OfficialSpeakerDiarizationWorkerFactory
    implements SpeakerDiarizationWorkerFactory {
  const OfficialSpeakerDiarizationWorkerFactory();

  @override
  Future<SpeakerDiarizationWorker> create(
    SherpaOnnxSpeakerDiarizationConfig config,
  ) => _IsolateSpeakerDiarizationWorker.start(config);
}

final class _IsolateSpeakerDiarizationWorker
    implements SpeakerDiarizationWorker {
  _IsolateSpeakerDiarizationWorker._({
    required this._isolate,
    required this._responses,
    required this._responseSubscription,
    required this._exits,
    required this._exitSubscription,
    required this._commandsReady,
  });

  final Isolate _isolate;
  final ReceivePort _responses;
  final StreamSubscription<Object?> _responseSubscription;
  final ReceivePort _exits;
  final StreamSubscription<Object?> _exitSubscription;
  final Completer<SendPort> _commandsReady;
  final Map<int, Completer<Map<Object?, Object?>>> _pending = {};
  int _nextRequestId = 1;
  bool _closed = false;
  bool _cleanedUp = false;
  SpeakerDiarizationWorkerException? _exitError;

  static Future<_IsolateSpeakerDiarizationWorker> start(
    SherpaOnnxSpeakerDiarizationConfig config,
  ) async {
    final responses = ReceivePort();
    final exits = ReceivePort();
    final ready = Completer<SendPort>();
    ready.future.ignore();
    final pendingResponses = <Map<Object?, Object?>>[];
    late final StreamSubscription<Object?> responseSubscription;
    late final StreamSubscription<Object?> exitSubscription;
    _IsolateSpeakerDiarizationWorker? worker;
    SpeakerDiarizationWorkerException? earlyExit;

    responseSubscription = responses.listen((message) {
      if (message is! Map<Object?, Object?>) {
        return;
      }
      switch (message['type']) {
        case 'ready':
          if (!ready.isCompleted) {
            ready.complete(message['commands']! as SendPort);
          }
        case 'initializationError':
          if (!ready.isCompleted) {
            ready.completeError(
              SpeakerDiarizationWorkerException(message['code']! as String),
            );
          }
        default:
          final current = worker;
          if (current == null) {
            pendingResponses.add(message);
          } else {
            current._handleResponse(message);
          }
      }
    });
    exitSubscription = exits.listen((_) {
      final error = const SpeakerDiarizationWorkerException(
        'speaker_diarization.worker_exited',
      );
      earlyExit = error;
      if (!ready.isCompleted) {
        ready.completeError(error);
      }
      worker?._handleUnexpectedExit(error);
    });

    final isolate = await Isolate.spawn<List<Object?>>(
      _speakerDiarizationWorkerMain,
      [responses.sendPort, config.toMessage()],
      debugName: 'meettrace-speaker-diarization',
      onExit: exits.sendPort,
    );
    try {
      worker = _IsolateSpeakerDiarizationWorker._(
        isolate: isolate,
        responses: responses,
        responseSubscription: responseSubscription,
        exits: exits,
        exitSubscription: exitSubscription,
        commandsReady: ready,
      );
      final exitBeforeConstruction = earlyExit;
      if (exitBeforeConstruction != null) {
        worker._handleUnexpectedExit(exitBeforeConstruction);
      }
      for (final response in pendingResponses) {
        worker._handleResponse(response);
      }
      return worker;
    } on Object {
      isolate.kill(priority: Isolate.immediate);
      await responseSubscription.cancel();
      await exitSubscription.cancel();
      responses.close();
      exits.close();
      rethrow;
    }
  }

  @override
  Future<List<SpeakerDiarizationWorkerSegment>> diarize(
    AudioSource source,
  ) async {
    if (_closed) {
      throw const SpeakerDiarizationWorkerException(
        'speaker_diarization.worker_closed',
      );
    }
    final response = await _request({
      'type': 'diarize',
      'path': source.path,
      'sampleRate': source.sampleRate,
      'channelCount': source.channelCount,
    });
    if (response['type'] == 'inferenceError') {
      throw SpeakerDiarizationWorkerException(response['code']! as String);
    }
    final rawSegments = response['segments']! as List<Object?>;
    return [
      for (final raw in rawSegments)
        _segmentFromMessage(raw! as Map<Object?, Object?>),
    ];
  }

  @override
  Future<void> cancel() async {
    if (_closed) {
      return;
    }
    _closed = true;
    if (!_commandsReady.isCompleted) {
      _commandsReady.completeError(
        const SpeakerDiarizationWorkerException(
          'speaker_diarization.cancelled',
        ),
      );
    }
    _isolate.kill(priority: Isolate.immediate);
    _completePending(
      const SpeakerDiarizationWorkerException('speaker_diarization.cancelled'),
    );
    await _cleanup();
  }

  @override
  Future<void> dispose() async {
    if (_closed) {
      await _cleanup();
      return;
    }
    _closed = true;
    try {
      final response = await _request({'type': 'dispose'}, allowClosed: true);
      if (response['type'] == 'disposeError') {
        throw SpeakerDiarizationWorkerException(response['code']! as String);
      }
    } finally {
      _isolate.kill(priority: Isolate.immediate);
      _completePending(
        const SpeakerDiarizationWorkerException(
          'speaker_diarization.worker_closed',
        ),
      );
      await _cleanup();
    }
  }

  Future<Map<Object?, Object?>> _request(
    Map<String, Object> message, {
    bool allowClosed = false,
  }) async {
    final exitError = _exitError;
    if (exitError != null) {
      throw exitError;
    }
    if (_closed && !allowClosed) {
      throw const SpeakerDiarizationWorkerException(
        'speaker_diarization.worker_closed',
      );
    }
    final commands = await _commandsReady.future;
    final errorAfterInitialization = _exitError;
    if (errorAfterInitialization != null) {
      throw errorAfterInitialization;
    }
    if (_closed && !allowClosed) {
      throw const SpeakerDiarizationWorkerException(
        'speaker_diarization.worker_closed',
      );
    }
    final id = _nextRequestId++;
    final completer = Completer<Map<Object?, Object?>>();
    _pending[id] = completer;
    commands.send({...message, 'id': id});
    return await completer.future;
  }

  void _handleResponse(Map<Object?, Object?> message) {
    final id = message['id'];
    if (id is int) {
      _pending.remove(id)?.complete(message);
    }
  }

  void _handleUnexpectedExit(SpeakerDiarizationWorkerException error) {
    _exitError = error;
    if (!_commandsReady.isCompleted) {
      _commandsReady.completeError(error);
    }
    _completePending(error);
  }

  void _completePending(Object error) {
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(error);
      }
    }
    _pending.clear();
  }

  Future<void> _cleanup() async {
    if (_cleanedUp) {
      return;
    }
    _cleanedUp = true;
    await _responseSubscription.cancel();
    await _exitSubscription.cancel();
    _responses.close();
    _exits.close();
  }
}

SpeakerDiarizationWorkerSegment _segmentFromMessage(
  Map<Object?, Object?> message,
) => SpeakerDiarizationWorkerSegment(
  startSeconds: message['startSeconds']! as double,
  endSeconds: message['endSeconds']! as double,
  speakerIndex: message['speakerIndex']! as int,
);

void _speakerDiarizationWorkerMain(List<Object?> bootstrap) async {
  final responses = bootstrap[0]! as SendPort;
  final config = SherpaOnnxSpeakerDiarizationConfig.fromMessage(
    bootstrap[1]! as Map<Object?, Object?>,
  );
  final commands = ReceivePort();
  sherpa.OfflineSpeakerDiarization? diarizer;

  try {
    sherpa.initBindings();
    diarizer = sherpa.OfflineSpeakerDiarization(_officialConfig(config));
    if (diarizer.sampleRate != config.sampleRate) {
      throw StateError(
        '模型采样率 ${diarizer.sampleRate} 与 ${config.sampleRate} 不一致',
      );
    }
    responses.send({'type': 'ready', 'commands': commands.sendPort});

    await for (final raw in commands) {
      if (raw is! Map<Object?, Object?>) {
        continue;
      }
      final id = raw['id']! as int;
      switch (raw['type']) {
        case 'diarize':
          try {
            final active = diarizer;
            if (active == null) {
              throw StateError('说话人分离器已经释放');
            }
            final sampleRate = raw['sampleRate']! as int;
            final channelCount = raw['channelCount']! as int;
            if (sampleRate != active.sampleRate || channelCount != 1) {
              throw const SpeakerDiarizationWorkerException(
                'speaker_diarization.invalid_audio',
              );
            }
            final samples = _readPcm16Mono(raw['path']! as String);
            final segments = active.process(samples: samples);
            responses.send({
              'type': 'result',
              'id': id,
              'segments': [
                for (final segment in segments)
                  {
                    'startSeconds': segment.start,
                    'endSeconds': segment.end,
                    'speakerIndex': segment.speaker,
                  },
              ],
            });
          } on Object catch (error) {
            responses.send({
              'type': 'inferenceError',
              'id': id,
              'code': switch (error) {
                SpeakerDiarizationWorkerException(:final code) => code,
                FileSystemException() =>
                  'speaker_diarization.audio_read_failed',
                FormatException() => 'speaker_diarization.invalid_audio',
                _ => 'speaker_diarization.inference_failed',
              },
            });
          }
        case 'dispose':
          try {
            diarizer?.free();
            diarizer = null;
            responses.send({'type': 'disposed', 'id': id});
          } on Object {
            responses.send({
              'type': 'disposeError',
              'id': id,
              'code': 'speaker_diarization.dispose_failed',
            });
          } finally {
            commands.close();
          }
      }
    }
  } on Object {
    responses.send({
      'type': 'initializationError',
      'code': 'speaker_diarization.initialization_failed',
    });
  } finally {
    diarizer?.free();
    commands.close();
  }
}

sherpa.OfflineSpeakerDiarizationConfig _officialConfig(
  SherpaOnnxSpeakerDiarizationConfig config,
) {
  return sherpa.OfflineSpeakerDiarizationConfig(
    segmentation: sherpa.OfflineSpeakerSegmentationModelConfig(
      pyannote: sherpa.OfflineSpeakerSegmentationPyannoteModelConfig(
        model: config.segmentationModelPath,
      ),
      numThreads: config.numThreads,
      debug: false,
      provider: config.provider,
    ),
    embedding: sherpa.SpeakerEmbeddingExtractorConfig(
      model: config.embeddingModelPath,
      numThreads: config.numThreads,
      debug: false,
      provider: config.provider,
    ),
    clustering: sherpa.FastClusteringConfig(
      numClusters: config.numClusters,
      threshold: config.clusteringThreshold,
    ),
    minDurationOn: config.minDurationOn,
    minDurationOff: config.minDurationOff,
  );
}

Float32List _readPcm16Mono(String path) {
  final file = File(path);
  final length = file.lengthSync();
  if (length <= 0 || length.isOdd) {
    throw const FormatException('事实 PCM 必须是非空的 16-bit 样本');
  }
  if (!speakerDiarizationPcmFitsMemory(length)) {
    throw const SpeakerDiarizationWorkerException(
      'speaker_diarization.memory_limit',
    );
  }
  final samples = Float32List(length ~/ 2);
  final handle = file.openSync();
  final buffer = Uint8List(64 * 1024);
  var sampleOffset = 0;
  try {
    while (sampleOffset < samples.length) {
      final remainingBytes = (samples.length - sampleOffset) * 2;
      final requested = remainingBytes < buffer.length
          ? remainingBytes
          : buffer.length;
      final read = handle.readIntoSync(buffer, 0, requested);
      if (read <= 0 || read.isOdd) {
        throw const FormatException('事实 PCM 在读取期间被截断');
      }
      final view = ByteData.sublistView(buffer, 0, read);
      for (var byteOffset = 0; byteOffset < read; byteOffset += 2) {
        samples[sampleOffset++] =
            view.getInt16(byteOffset, Endian.little) / 32768.0;
      }
    }
  } finally {
    handle.closeSync();
  }
  return samples;
}
