import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meettrace_whisper_native/meettrace_whisper_native.dart';

import '../../../../domain/models/app_failure.dart';

final class WhisperRecognizerConfig {
  WhisperRecognizerConfig({
    required this.modelId,
    required this.modelVersion,
    required this.modelPath,
    this.threadCount = 2,
    this.language = 'auto',
  }) {
    _requireText(modelId, 'modelId');
    _requireText(modelVersion, 'modelVersion');
    _requireText(modelPath, 'modelPath');
    _requireText(language, 'language');
    if (threadCount <= 0) {
      throw ArgumentError.value(threadCount, 'threadCount', '必须大于 0');
    }
  }

  factory WhisperRecognizerConfig.fromMessage(Map<Object?, Object?> map) {
    return WhisperRecognizerConfig(
      modelId: map['modelId']! as String,
      modelVersion: map['modelVersion']! as String,
      modelPath: map['modelPath']! as String,
      threadCount: map['threadCount']! as int,
      language: map['language']! as String,
    );
  }

  final String modelId;
  final String modelVersion;
  final String modelPath;
  final int threadCount;
  final String language;

  Map<String, Object> toMessage() => {
    'modelId': modelId,
    'modelVersion': modelVersion,
    'modelPath': modelPath,
    'threadCount': threadCount,
    'language': language,
  };
}

final class WhisperRecognition {
  const WhisperRecognition({
    required this.text,
    required this.sampleCount,
    required this.elapsed,
    this.segments = const [],
  });

  final String text;
  final int sampleCount;
  final Duration elapsed;
  final List<WhisperRecognitionSegment> segments;
}

final class WhisperRecognitionSegment {
  const WhisperRecognitionSegment({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  factory WhisperRecognitionSegment.fromMessage(Map<Object?, Object?> map) {
    return WhisperRecognitionSegment(
      text: map['text']! as String,
      startMs: map['startMs']! as int,
      endMs: map['endMs']! as int,
    );
  }

  final String text;
  final int startMs;
  final int endMs;
}

final class WhisperAdapterException implements Exception {
  const WhisperAdapterException(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'WhisperAdapterException(${failure.code})';
}

abstract interface class WhisperWorker {
  int get nativeContextAddress;

  Future<WhisperRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  });

  void cancel();

  Future<void> dispose();
}

abstract interface class WhisperWorkerFactory {
  Future<WhisperWorker> create(WhisperRecognizerConfig config);
}

final class WhisperAdapter {
  WhisperAdapter({this._workerFactory = const OfficialWhisperWorkerFactory()});

  final WhisperWorkerFactory _workerFactory;
  WhisperRecognizerConfig? _config;
  WhisperWorker? _worker;
  Future<void> _tail = Future<void>.value();
  bool _cancelled = false;
  bool _disposed = false;

  bool get isInitialized => _worker != null && !_disposed;

  Future<void> initialize(WhisperRecognizerConfig config) async {
    if (_disposed) {
      throw StateError('adapter 已释放');
    }
    if (_worker != null) {
      throw StateError('adapter 已初始化');
    }
    _config = config;
    try {
      _worker = await _workerFactory.create(config);
    } on Object catch (error) {
      throw _exception(
        code: 'asr.whisper.recognizer_initialization_failed',
        stage: FailureStage.asrInitialization,
        error: error,
      );
    }
  }

  Future<WhisperRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  }) {
    if (samples.isEmpty || sampleRate != 16000) {
      return Future.error(
        _exception(
          code: 'asr.whisper.invalid_audio',
          stage: FailureStage.asrInference,
          error: ArgumentError('Whisper 只接受非空 16 kHz Float32 PCM'),
        ),
      );
    }
    final result = Completer<WhisperRecognition>();
    final ownedSamples = Float32List.fromList(samples);
    _tail = _tail.then((_) async {
      try {
        _throwIfUnavailable();
        final recognition = await _worker!.recognize(
          ownedSamples,
          sampleRate: sampleRate,
        );
        _throwIfUnavailable();
        result.complete(recognition);
      } on Object catch (error, stackTrace) {
        if (!result.isCompleted) {
          result.completeError(_mapInferenceError(error), stackTrace);
        }
      }
    });
    return result.future;
  }

  void cancel() {
    if (_cancelled || _disposed) {
      return;
    }
    _cancelled = true;
    _worker?.cancel();
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _cancelled = true;
    _worker?.cancel();
    await _tail;
    final worker = _worker;
    _worker = null;
    if (worker == null) {
      return;
    }
    try {
      await worker.dispose();
    } on Object catch (error) {
      throw _exception(
        code: 'asr.whisper.dispose_failed',
        stage: FailureStage.asrInitialization,
        error: error,
      );
    }
  }

  void _throwIfUnavailable() {
    if (_cancelled) {
      throw _exception(
        code: 'asr.whisper.cancelled',
        stage: FailureStage.asrInference,
      );
    }
    if (_disposed) {
      throw _exception(
        code: 'asr.whisper.disposed',
        stage: FailureStage.asrInference,
      );
    }
    if (_worker == null) {
      throw _exception(
        code: 'asr.whisper.not_initialized',
        stage: FailureStage.asrInitialization,
      );
    }
  }

  WhisperAdapterException _mapInferenceError(Object error) {
    if (error is WhisperAdapterException) {
      return error;
    }
    return _exception(
      code: error is _RemoteWhisperError && error.errorCode == 'cancelled'
          ? 'asr.whisper.cancelled'
          : 'asr.whisper.inference_failed',
      stage: FailureStage.asrInference,
      error: error,
    );
  }

  WhisperAdapterException _exception({
    required String code,
    required FailureStage stage,
    Object? error,
  }) {
    final config = _config;
    return WhisperAdapterException(
      AppFailure(
        code: code,
        stage: stage,
        modelId: config?.modelId,
        modelVersion: config?.modelVersion,
        recoverability: FailureRecoverability.retryable,
        userAction: FailureUserAction.retry,
        diagnosticContext: {
          if (error != null) 'errorType': _workerErrorType(error),
        },
      ),
    );
  }
}

final class OfficialWhisperWorkerFactory implements WhisperWorkerFactory {
  const OfficialWhisperWorkerFactory();

  @override
  Future<WhisperWorker> create(WhisperRecognizerConfig config) {
    return _IsolateWhisperWorker.start(config);
  }
}

final class _IsolateWhisperWorker implements WhisperWorker {
  _IsolateWhisperWorker._({
    required this._isolate,
    required this._responses,
    required this._responseSubscription,
    required this._exits,
    required this._exitSubscription,
    required this._commands,
    required this.nativeContextAddress,
  });

  final Isolate _isolate;
  final ReceivePort _responses;
  final StreamSubscription<Object?> _responseSubscription;
  final ReceivePort _exits;
  final StreamSubscription<Object?> _exitSubscription;
  final SendPort _commands;
  final Map<int, Completer<Map<Object?, Object?>>> _pending = {};
  @override
  final int nativeContextAddress;
  int _nextRequestId = 1;
  Future<void>? _disposing;
  bool _disposed = false;
  _RemoteWhisperError? _exitError;

  static Future<_IsolateWhisperWorker> start(
    WhisperRecognizerConfig config,
  ) async {
    final responses = ReceivePort();
    final exits = ReceivePort();
    final ready = Completer<({SendPort commands, int contextAddress})>();
    final pendingResponses = <Map<Object?, Object?>>[];
    late final StreamSubscription<Object?> subscription;
    late final StreamSubscription<Object?> exitSubscription;
    _IsolateWhisperWorker? worker;
    _RemoteWhisperError? earlyExit;

    subscription = responses.listen((message) {
      if (message is! Map<Object?, Object?>) {
        return;
      }
      final type = message['type'];
      if (type == 'ready') {
        ready.complete((
          commands: message['commands']! as SendPort,
          contextAddress: message['contextAddress']! as int,
        ));
        return;
      }
      if (type == 'initializationError') {
        ready.completeError(
          _RemoteWhisperError(message['errorCode']! as String),
        );
        return;
      }
      final currentWorker = worker;
      if (currentWorker == null) {
        pendingResponses.add(message);
      } else {
        currentWorker._handleResponse(message);
      }
    });
    exitSubscription = exits.listen((_) {
      final error = const _RemoteWhisperError('isolate_exit');
      earlyExit = error;
      if (!ready.isCompleted) {
        ready.completeError(error);
      }
      worker?._handleUnexpectedExit(error);
    });

    final isolate = await Isolate.spawn<List<Object?>>(
      _whisperWorkerMain,
      [responses.sendPort, config.toMessage()],
      debugName: 'meettrace-whisper-${config.modelId}',
      onExit: exits.sendPort,
    );
    try {
      final readyState = await ready.future;
      worker = _IsolateWhisperWorker._(
        isolate: isolate,
        responses: responses,
        responseSubscription: subscription,
        exits: exits,
        exitSubscription: exitSubscription,
        commands: readyState.commands,
        nativeContextAddress: readyState.contextAddress,
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
      await subscription.cancel();
      await exitSubscription.cancel();
      responses.close();
      exits.close();
      rethrow;
    }
  }

  @override
  Future<WhisperRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  }) async {
    if (_disposed || _disposing != null) {
      throw StateError('worker 已释放');
    }
    final response = await _request({
      'type': 'recognize',
      'sampleRate': sampleRate,
      'samples': TransferableTypedData.fromList([
        samples.buffer.asUint8List(
          samples.offsetInBytes,
          samples.lengthInBytes,
        ),
      ]),
    });
    if (response['type'] == 'inferenceError') {
      throw _RemoteWhisperError(response['errorCode']! as String);
    }
    return WhisperRecognition(
      text: response['text']! as String,
      sampleCount: response['sampleCount']! as int,
      elapsed: Duration(microseconds: response['elapsedMicros']! as int),
      segments: [
        for (final raw in response['segments']! as List<Object?>)
          WhisperRecognitionSegment.fromMessage(raw! as Map<Object?, Object?>),
      ],
    );
  }

  @override
  void cancel() {
    if (!_disposed) {
      WhisperNativeContext.cancelAddress(nativeContextAddress);
    }
  }

  @override
  Future<void> dispose() {
    if (_disposed) {
      return Future<void>.value();
    }
    return _disposing ??= _dispose();
  }

  Future<void> _dispose() async {
    try {
      final response = await _request({'type': 'dispose'});
      if (response['type'] == 'disposeError') {
        throw _RemoteWhisperError(response['errorCode']! as String);
      }
    } finally {
      _disposed = true;
      _isolate.kill(priority: Isolate.immediate);
      await _responseSubscription.cancel();
      await _exitSubscription.cancel();
      _responses.close();
      _exits.close();
      for (final pending in _pending.values) {
        if (!pending.isCompleted) {
          pending.completeError(StateError('worker 已释放'));
        }
      }
      _pending.clear();
    }
  }

  Future<Map<Object?, Object?>> _request(Map<String, Object> message) {
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

  void _handleResponse(Map<Object?, Object?> message) {
    final id = message['id'];
    if (id is int) {
      _pending.remove(id)?.complete(message);
    }
  }

  void _handleUnexpectedExit(_RemoteWhisperError error) {
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

void _whisperWorkerMain(List<Object?> bootstrap) async {
  final responses = bootstrap[0]! as SendPort;
  final config = WhisperRecognizerConfig.fromMessage(
    bootstrap[1]! as Map<Object?, Object?>,
  );
  final commands = ReceivePort();
  WhisperNativeContext? context;

  try {
    context = WhisperNativeContext.open(
      modelPath: config.modelPath,
      threadCount: config.threadCount,
      language: config.language,
    );
    responses.send({
      'type': 'ready',
      'commands': commands.sendPort,
      'contextAddress': context.address,
    });

    await for (final raw in commands) {
      if (raw is! Map<Object?, Object?>) {
        continue;
      }
      final id = raw['id']! as int;
      if (raw['type'] == 'recognize') {
        final watch = Stopwatch()..start();
        try {
          final bytes = (raw['samples']! as TransferableTypedData)
              .materialize()
              .asUint8List();
          final samples = Float32List.view(
            bytes.buffer,
            bytes.offsetInBytes,
            bytes.lengthInBytes ~/ Float32List.bytesPerElement,
          );
          final result = context!.transcribe(samples);
          watch.stop();
          responses.send({
            'type': 'result',
            'id': id,
            'text': result.text,
            'sampleCount': samples.length,
            'elapsedMicros': watch.elapsedMicroseconds,
            'segments': [
              for (final segment in result.segments)
                {
                  'text': segment.text,
                  'startMs': segment.startMs,
                  'endMs': segment.endMs,
                },
            ],
          });
        } on WhisperNativeException catch (error) {
          watch.stop();
          responses.send({
            'type': 'inferenceError',
            'id': id,
            'errorCode': error.code,
          });
        } on Object catch (error) {
          watch.stop();
          responses.send({
            'type': 'inferenceError',
            'id': id,
            'errorCode': error.runtimeType.toString(),
          });
        }
        continue;
      }
      if (raw['type'] == 'dispose') {
        try {
          context!.dispose();
          context = null;
          responses.send({'type': 'disposed', 'id': id});
        } on Object catch (error) {
          responses.send({
            'type': 'disposeError',
            'id': id,
            'errorCode': error.runtimeType.toString(),
          });
        } finally {
          commands.close();
        }
      }
    }
  } on WhisperNativeException catch (error) {
    responses.send({'type': 'initializationError', 'errorCode': error.code});
  } on Object catch (error) {
    responses.send({
      'type': 'initializationError',
      'errorCode': error.runtimeType.toString(),
    });
  } finally {
    context?.dispose();
    commands.close();
  }
}

String _workerErrorType(Object error) {
  return switch (error) {
    _RemoteWhisperError(:final errorCode) => errorCode,
    _ => error.runtimeType.toString(),
  };
}

final class _RemoteWhisperError implements Exception {
  const _RemoteWhisperError(this.errorCode);

  final String errorCode;
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, '不能为空');
  }
}
