import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meettrace_whisper_native/meettrace_whisper_native.dart';

import '../../../domain/models/asr_preview.dart';
import 'voice_activity_segmenter.dart';

const whisperVadSampleRate = 16000;

final class WhisperVadConfig {
  const WhisperVadConfig({
    required this.modelPath,
    this.threadCount = 2,
    this.threshold = 0.5,
    this.minSpeechDurationMs = 250,
    this.minSilenceDurationMs = 100,
    this.maxSpeechDurationSeconds = 15,
    this.speechPadMs = 30,
    this.samplesOverlapSeconds = 0.1,
  });

  factory WhisperVadConfig.fromMessage(Map<Object?, Object?> message) {
    return WhisperVadConfig(
      modelPath: message['modelPath']! as String,
      threadCount: message['threadCount']! as int,
      threshold: message['threshold']! as double,
      minSpeechDurationMs: message['minSpeechDurationMs']! as int,
      minSilenceDurationMs: message['minSilenceDurationMs']! as int,
      maxSpeechDurationSeconds: message['maxSpeechDurationSeconds']! as double,
      speechPadMs: message['speechPadMs']! as int,
      samplesOverlapSeconds: message['samplesOverlapSeconds']! as double,
    );
  }

  final String modelPath;
  final int threadCount;
  final double threshold;
  final int minSpeechDurationMs;
  final int minSilenceDurationMs;
  final double maxSpeechDurationSeconds;
  final int speechPadMs;
  final double samplesOverlapSeconds;

  Map<String, Object> toMessage() => {
    'modelPath': modelPath,
    'threadCount': threadCount,
    'threshold': threshold,
    'minSpeechDurationMs': minSpeechDurationMs,
    'minSilenceDurationMs': minSilenceDurationMs,
    'maxSpeechDurationSeconds': maxSpeechDurationSeconds,
    'speechPadMs': speechPadMs,
    'samplesOverlapSeconds': samplesOverlapSeconds,
  };
}

abstract interface class WhisperVadWorker {
  Future<List<WhisperVadNativeSegment>> segment(Float32List samples);

  Future<void> dispose();
}

abstract interface class WhisperVadWorkerFactory {
  Future<WhisperVadWorker> create(WhisperVadConfig config);
}

final class OfficialWhisperVadWorkerFactory implements WhisperVadWorkerFactory {
  const OfficialWhisperVadWorkerFactory();

  @override
  Future<WhisperVadWorker> create(WhisperVadConfig config) {
    return _IsolateWhisperVadWorker.start(config);
  }
}

/// 用官方 whisper.cpp Silero VAD 生成全局、稳定且与输入 chunk 边界无关的区间。
///
/// 每次只在固定的全局采样点分析，末尾保留稳定余量；原生推理始终运行在独立
/// isolate。预览调度可以丢弃输入 chunk，但不会阻塞事实 PCM 的写入链。
final class WhisperVadSegmenter implements VoiceActivitySegmenter {
  WhisperVadSegmenter({
    required String modelPath,
    this.workerFactory = const OfficialWhisperVadWorkerFactory(),
    this.analysisInterval = const Duration(seconds: 1),
    this.stabilityMargin = const Duration(seconds: 1),
    this.maximumBufferedDuration = const Duration(seconds: 30),
    WhisperVadConfig? config,
  }) : config = config ?? WhisperVadConfig(modelPath: modelPath) {
    if (this.config.modelPath.trim().isEmpty) {
      throw ArgumentError.value(modelPath, 'modelPath', '不能为空');
    }
    _analysisIntervalSamples = _samplesFor(analysisInterval);
    _stabilityMarginSamples = _samplesFor(stabilityMargin);
    _maximumBufferedSamples = _samplesFor(maximumBufferedDuration);
    if (_analysisIntervalSamples <= 0 ||
        _stabilityMarginSamples < _analysisIntervalSamples ||
        _maximumBufferedSamples <
            _stabilityMarginSamples +
                (this.config.maxSpeechDurationSeconds * sampleRate).ceil()) {
      throw ArgumentError('VAD 流式缓冲参数无效');
    }
  }

  @override
  final int sampleRate = whisperVadSampleRate;
  final WhisperVadConfig config;
  final Duration analysisInterval;
  final Duration stabilityMargin;
  final Duration maximumBufferedDuration;
  final WhisperVadWorkerFactory workerFactory;

  late final int _analysisIntervalSamples;
  late final int _stabilityMarginSamples;
  late final int _maximumBufferedSamples;
  final List<double> _buffer = [];
  Future<WhisperVadWorker>? _worker;
  int _bufferStartSample = 0;
  int _availableEndSample = 0;
  int _analysisOriginSample = 0;
  int _lastAnalysisEndSample = 0;
  int _emittedThroughSample = 0;
  bool _disposed = false;

  @override
  Future<List<VadSpeechSegment>> accept(Float32List samples) async {
    _throwIfDisposed();
    if (samples.isEmpty) {
      return const [];
    }
    _buffer.addAll(samples);
    _availableEndSample += samples.length;
    final elapsed = _availableEndSample - _analysisOriginSample;
    final alignedElapsed =
        elapsed ~/ _analysisIntervalSamples * _analysisIntervalSamples;
    final analysisEnd = _analysisOriginSample + alignedElapsed;
    if (analysisEnd <= _lastAnalysisEndSample) {
      return const [];
    }
    if (analysisEnd - _bufferStartSample <
        _analysisIntervalSamples + _stabilityMarginSamples) {
      return const [];
    }
    _lastAnalysisEndSample = analysisEnd;
    return _analyze(analysisEnd: analysisEnd, finalizing: false);
  }

  @override
  Future<List<VadSpeechSegment>> flush() async {
    _throwIfDisposed();
    if (_buffer.isEmpty) {
      return const [];
    }
    final result = await _analyze(
      analysisEnd: _availableEndSample,
      finalizing: true,
    );
    _buffer.clear();
    _bufferStartSample = _availableEndSample;
    _lastAnalysisEndSample = _availableEndSample;
    _emittedThroughSample = _availableEndSample;
    return result;
  }

  @override
  Future<void> reset({required int nextStartSample}) async {
    _throwIfDisposed();
    if (nextStartSample < 0) {
      throw ArgumentError.value(nextStartSample, 'nextStartSample', '不能为负数');
    }
    _buffer.clear();
    _bufferStartSample = nextStartSample;
    _availableEndSample = nextStartSample;
    _analysisOriginSample = nextStartSample;
    _lastAnalysisEndSample = nextStartSample;
    _emittedThroughSample = nextStartSample;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _buffer.clear();
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      await (await worker).dispose();
    }
  }

  Future<List<VadSpeechSegment>> _analyze({
    required int analysisEnd,
    required bool finalizing,
  }) async {
    final sampleCount = analysisEnd - _bufferStartSample;
    if (sampleCount <= 0 || sampleCount > _buffer.length) {
      throw StateError('VAD 音频时间轴与缓冲区不一致');
    }
    final samples = Float32List.fromList(_buffer.take(sampleCount).toList());
    final nativeSegments = await (await _ensureWorker()).segment(samples);
    final stableEnd = finalizing
        ? analysisEnd
        : analysisEnd - _stabilityMarginSamples;
    final output = <VadSpeechSegment>[];
    for (final segment in nativeSegments) {
      final globalStart = _bufferStartSample + segment.startSample;
      final globalEnd = _bufferStartSample + segment.endSample;
      if (globalEnd > stableEnd || globalEnd <= _emittedThroughSample) {
        continue;
      }
      final start = globalStart < _emittedThroughSample
          ? _emittedThroughSample
          : globalStart;
      if (globalEnd > start) {
        output.add(VadSpeechSegment(startSample: start, endSample: globalEnd));
        _emittedThroughSample = globalEnd;
      }
    }
    if (!finalizing) {
      _trimStablePrefix(
        analysisEnd: analysisEnd,
        nativeSegments: nativeSegments,
        stableEnd: stableEnd,
      );
    }
    return List.unmodifiable(output);
  }

  void _trimStablePrefix({
    required int analysisEnd,
    required List<WhisperVadNativeSegment> nativeSegments,
    required int stableEnd,
  }) {
    var discardBefore = _emittedThroughSample;
    if (nativeSegments.isEmpty) {
      discardBefore = stableEnd;
    }
    final requiredTrim = analysisEnd - _maximumBufferedSamples;
    if (requiredTrim > discardBefore) {
      discardBefore = requiredTrim;
    }
    discardBefore = discardBefore.clamp(_bufferStartSample, stableEnd);
    final discardCount = discardBefore - _bufferStartSample;
    if (discardCount <= 0) {
      return;
    }
    _buffer.removeRange(0, discardCount);
    _bufferStartSample = discardBefore;
  }

  Future<WhisperVadWorker> _ensureWorker() {
    return _worker ??= workerFactory.create(config);
  }

  int _samplesFor(Duration duration) {
    return duration.inMicroseconds *
        sampleRate ~/
        Duration.microsecondsPerSecond;
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('Whisper VAD 分段器已释放');
    }
  }
}

final class _IsolateWhisperVadWorker implements WhisperVadWorker {
  _IsolateWhisperVadWorker._({
    required this._isolate,
    required this._responses,
    required this._subscription,
    required this._exits,
    required this._exitSubscription,
    required this._commands,
  });

  final Isolate _isolate;
  final ReceivePort _responses;
  final StreamSubscription<Object?> _subscription;
  final ReceivePort _exits;
  final StreamSubscription<Object?> _exitSubscription;
  final SendPort _commands;
  final Map<int, Completer<Map<Object?, Object?>>> _pending = {};
  int _nextRequestId = 1;
  bool _disposed = false;
  Object? _exitError;

  static Future<_IsolateWhisperVadWorker> start(WhisperVadConfig config) async {
    final responses = ReceivePort();
    final exits = ReceivePort();
    final ready = Completer<SendPort>();
    _IsolateWhisperVadWorker? worker;
    Object? earlyExitError;
    late final StreamSubscription<Object?> subscription;
    subscription = responses.listen((message) {
      if (message is! Map<Object?, Object?>) {
        return;
      }
      if (message['type'] == 'ready') {
        ready.complete(message['commands']! as SendPort);
        return;
      }
      if (message['type'] == 'initializationError') {
        ready.completeError(StateError(message['errorCode']! as String));
        return;
      }
      final id = message['id'];
      if (id is int) {
        worker?._pending.remove(id)?.complete(message);
      }
    });
    late final StreamSubscription<Object?> exitSubscription;
    exitSubscription = exits.listen((_) {
      final error = StateError('VAD worker isolate 意外退出');
      earlyExitError = error;
      if (!ready.isCompleted) {
        ready.completeError(error);
      }
      worker?._handleUnexpectedExit(error);
    });
    final isolate = await Isolate.spawn<List<Object?>>(
      _whisperVadWorkerMain,
      [responses.sendPort, config.toMessage()],
      debugName: 'meettrace-whisper-vad',
      onExit: exits.sendPort,
    );
    try {
      final commands = await ready.future;
      final created = _IsolateWhisperVadWorker._(
        isolate: isolate,
        responses: responses,
        subscription: subscription,
        exits: exits,
        exitSubscription: exitSubscription,
        commands: commands,
      );
      worker = created;
      final exitError = earlyExitError;
      if (exitError != null) {
        created._handleUnexpectedExit(exitError);
      }
      return created;
    } on Object {
      isolate.kill(priority: Isolate.immediate);
      await subscription.cancel();
      await exitSubscription.cancel();
      responses.close();
      exits.close();
      rethrow;
    }
  }

  @override
  Future<List<WhisperVadNativeSegment>> segment(Float32List samples) async {
    final response = await _request({
      'type': 'segment',
      'samples': TransferableTypedData.fromList([
        samples.buffer.asUint8List(
          samples.offsetInBytes,
          samples.lengthInBytes,
        ),
      ]),
    });
    if (response['type'] == 'error') {
      throw StateError(response['errorCode']! as String);
    }
    return List.unmodifiable([
      for (final raw in response['segments']! as List<Object?>)
        _segmentFromMessage(raw! as List<Object?>),
    ]);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    try {
      await _request({'type': 'dispose'});
    } finally {
      _disposed = true;
      _isolate.kill(priority: Isolate.immediate);
      await _subscription.cancel();
      await _exitSubscription.cancel();
      _responses.close();
      _exits.close();
      for (final pending in _pending.values) {
        pending.completeError(StateError('VAD worker 已释放'));
      }
      _pending.clear();
    }
  }

  Future<Map<Object?, Object?>> _request(Map<String, Object> message) {
    if (_disposed) {
      return Future.error(StateError('VAD worker 已释放'));
    }
    final exitError = _exitError;
    if (exitError != null) {
      return Future.error(exitError);
    }
    final id = _nextRequestId++;
    final completer = Completer<Map<Object?, Object?>>();
    _pending[id] = completer;
    _commands.send({...message, 'id': id});
    return completer.future;
  }

  void _handleUnexpectedExit(Object error) {
    if (_disposed) {
      return;
    }
    _exitError = error;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(error);
      }
    }
    _pending.clear();
  }
}

void _whisperVadWorkerMain(List<Object?> bootstrap) async {
  final responses = bootstrap[0]! as SendPort;
  final config = WhisperVadConfig.fromMessage(
    bootstrap[1]! as Map<Object?, Object?>,
  );
  final commands = ReceivePort();
  WhisperVadNativeContext? context;
  try {
    context = WhisperVadNativeContext.open(
      modelPath: config.modelPath,
      threadCount: config.threadCount,
      threshold: config.threshold,
      minSpeechDurationMs: config.minSpeechDurationMs,
      minSilenceDurationMs: config.minSilenceDurationMs,
      maxSpeechDurationSeconds: config.maxSpeechDurationSeconds,
      speechPadMs: config.speechPadMs,
      samplesOverlapSeconds: config.samplesOverlapSeconds,
    );
    responses.send({'type': 'ready', 'commands': commands.sendPort});
    await for (final raw in commands) {
      if (raw is! Map<Object?, Object?>) {
        continue;
      }
      final id = raw['id']! as int;
      if (raw['type'] == 'segment') {
        try {
          final bytes = (raw['samples']! as TransferableTypedData)
              .materialize()
              .asUint8List();
          final samples = Float32List.view(
            bytes.buffer,
            bytes.offsetInBytes,
            bytes.lengthInBytes ~/ Float32List.bytesPerElement,
          );
          final segments = context!.segment(samples);
          responses.send({
            'type': 'result',
            'id': id,
            'segments': [
              for (final segment in segments)
                [segment.startSample, segment.endSample],
            ],
          });
        } on Object catch (error) {
          responses.send({
            'type': 'error',
            'id': id,
            'errorCode': error.toString(),
          });
        }
        continue;
      }
      if (raw['type'] == 'dispose') {
        context!.dispose();
        context = null;
        responses.send({'type': 'disposed', 'id': id});
        commands.close();
      }
    }
  } on Object catch (error) {
    responses.send({
      'type': 'initializationError',
      'errorCode': error.toString(),
    });
  } finally {
    context?.dispose();
    commands.close();
  }
}

WhisperVadNativeSegment _segmentFromMessage(List<Object?> message) {
  return WhisperVadNativeSegment(
    startSample: message[0]! as int,
    endSample: message[1]! as int,
  );
}
