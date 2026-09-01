import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../../domain/models/app_failure.dart';
import '../../monitoring/sentry_isolate_error_monitor.dart';

enum SherpaOnnxRecognizerKind { senseVoice }

final class SherpaOnnxRecognizerConfig {
  SherpaOnnxRecognizerConfig._({
    required this.kind,
    required this.modelId,
    required this.modelVersion,
    required this.numThreads,
    required this.modelPath,
    required this.tokensPath,
    required this.language,
    required this.useInverseTextNormalization,
  }) {
    _requireText(modelId, 'modelId');
    _requireText(modelVersion, 'modelVersion');
    if (numThreads <= 0) {
      throw ArgumentError.value(numThreads, 'numThreads', '必须大于 0');
    }
    _requireText(modelPath, 'modelPath');
    _requireText(tokensPath, 'tokensPath');
    _requireText(language, 'language');
  }

  factory SherpaOnnxRecognizerConfig.senseVoice({
    required String modelId,
    required String modelVersion,
    required String modelPath,
    required String tokensPath,
    String language = 'auto',
    bool useInverseTextNormalization = true,
    int numThreads = 2,
  }) {
    return SherpaOnnxRecognizerConfig._(
      kind: SherpaOnnxRecognizerKind.senseVoice,
      modelId: modelId,
      modelVersion: modelVersion,
      numThreads: numThreads,
      modelPath: modelPath,
      tokensPath: tokensPath,
      language: language,
      useInverseTextNormalization: useInverseTextNormalization,
    );
  }

  factory SherpaOnnxRecognizerConfig.fromMessage(Map<Object?, Object?> map) {
    final kind = SherpaOnnxRecognizerKind.values.byName(map['kind']! as String);
    return switch (kind) {
      SherpaOnnxRecognizerKind.senseVoice =>
        SherpaOnnxRecognizerConfig.senseVoice(
          modelId: map['modelId']! as String,
          modelVersion: map['modelVersion']! as String,
          modelPath: map['modelPath']! as String,
          tokensPath: map['tokensPath']! as String,
          numThreads: map['numThreads']! as int,
          language: map['language']! as String,
          useInverseTextNormalization:
              map['useInverseTextNormalization']! as bool,
        ),
    };
  }

  final SherpaOnnxRecognizerKind kind;
  final String modelId;
  final String modelVersion;
  final int numThreads;
  final String modelPath;
  final String tokensPath;
  final String language;
  final bool useInverseTextNormalization;

  Map<String, Object> toMessage() => {
    'kind': kind.name,
    'modelId': modelId,
    'modelVersion': modelVersion,
    'numThreads': numThreads,
    'modelPath': modelPath,
    'tokensPath': tokensPath,
    'language': language,
    'useInverseTextNormalization': useInverseTextNormalization,
  };
}

final class SherpaOnnxRecognition {
  const SherpaOnnxRecognition({
    required this.text,
    required this.sampleCount,
    required this.elapsed,
  });

  final String text;
  final int sampleCount;
  final Duration elapsed;
}

final class SherpaOnnxAdapterException implements Exception {
  const SherpaOnnxAdapterException(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'SherpaOnnxAdapterException(${failure.code})';
}

abstract interface class SherpaOnnxWorker {
  Future<SherpaOnnxRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  });

  Future<void> dispose();
}

abstract interface class SherpaOnnxWorkerFactory {
  Future<SherpaOnnxWorker> create(SherpaOnnxRecognizerConfig config);
}

final class SherpaOnnxAdapter {
  factory SherpaOnnxAdapter({
    SherpaOnnxWorkerFactory workerFactory =
        const OfficialSherpaOnnxWorkerFactory(),
  }) {
    return SherpaOnnxAdapter._(workerFactory);
  }

  SherpaOnnxAdapter._(this._workerFactory);

  final SherpaOnnxWorkerFactory _workerFactory;
  SherpaOnnxRecognizerConfig? _config;
  SherpaOnnxWorker? _worker;
  Future<void> _tail = Future<void>.value();
  bool _cancelled = false;
  bool _disposed = false;

  bool get isInitialized => _worker != null && !_disposed;

  Future<void> initialize(SherpaOnnxRecognizerConfig config) async {
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
        code: 'asr.official.recognizer_initialization_failed',
        stage: FailureStage.asrInitialization,
        error: error,
      );
    }
  }

  Future<SherpaOnnxRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  }) {
    if (samples.isEmpty || sampleRate <= 0) {
      return Future.error(
        _exception(
          code: 'asr.official.invalid_audio',
          stage: FailureStage.asrInference,
          error: ArgumentError('音频必须非空且采样率为正'),
        ),
      );
    }
    final result = Completer<SherpaOnnxRecognition>();
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
    _cancelled = true;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _cancelled = true;
    await _tail;
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      try {
        await worker.dispose();
      } on Object catch (error) {
        throw _exception(
          code: 'asr.official.dispose_failed',
          stage: FailureStage.asrInitialization,
          error: error,
        );
      }
    }
  }

  void _throwIfUnavailable() {
    if (_cancelled) {
      throw _exception(
        code: 'asr.official.cancelled',
        stage: FailureStage.asrInference,
      );
    }
    if (_disposed) {
      throw _exception(
        code: 'asr.official.disposed',
        stage: FailureStage.asrInference,
      );
    }
    if (_worker == null) {
      throw _exception(
        code: 'asr.official.not_initialized',
        stage: FailureStage.asrInitialization,
      );
    }
  }

  SherpaOnnxAdapterException _mapInferenceError(Object error) {
    if (error is SherpaOnnxAdapterException) {
      return error;
    }
    return _exception(
      code: 'asr.official.inference_failed',
      stage: FailureStage.asrInference,
      error: error,
    );
  }

  SherpaOnnxAdapterException _exception({
    required String code,
    required FailureStage stage,
    Object? error,
  }) {
    final config = _config;
    return SherpaOnnxAdapterException(
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

final class OfficialSherpaOnnxWorkerFactory implements SherpaOnnxWorkerFactory {
  const OfficialSherpaOnnxWorkerFactory();

  @override
  Future<SherpaOnnxWorker> create(SherpaOnnxRecognizerConfig config) {
    return _IsolateSherpaOnnxWorker.start(config);
  }
}

final class _IsolateSherpaOnnxWorker implements SherpaOnnxWorker {
  _IsolateSherpaOnnxWorker._({
    required this._isolate,
    required this._responses,
    required this._responseSubscription,
    required this._exits,
    required this._exitSubscription,
    required this._commands,
    required this._sentryErrors,
  });

  final Isolate _isolate;
  final ReceivePort _responses;
  final StreamSubscription<Object?> _responseSubscription;
  final ReceivePort _exits;
  final StreamSubscription<Object?> _exitSubscription;
  final SendPort _commands;
  final SentryIsolateErrorMonitor _sentryErrors;
  final Map<int, Completer<Map<Object?, Object?>>> _pending = {};
  int _nextRequestId = 1;
  bool _disposed = false;
  _RemoteWorkerError? _exitError;

  static Future<_IsolateSherpaOnnxWorker> start(
    SherpaOnnxRecognizerConfig config,
  ) async {
    final responses = ReceivePort();
    final exits = ReceivePort();
    final ready = Completer<SendPort>();
    final pendingResponses = <Map<Object?, Object?>>[];
    late final StreamSubscription<Object?> subscription;
    late final StreamSubscription<Object?> exitSubscription;
    _IsolateSherpaOnnxWorker? worker;
    _RemoteWorkerError? earlyExit;

    subscription = responses.listen((message) {
      if (message is! Map<Object?, Object?>) {
        return;
      }
      final type = message['type'];
      if (type == 'ready') {
        ready.complete(message['commands']! as SendPort);
        return;
      }
      if (type == 'initializationError') {
        ready.completeError(
          _RemoteWorkerError(message['errorType']! as String),
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
      final error = const _RemoteWorkerError('IsolateExit');
      earlyExit = error;
      if (!ready.isCompleted) {
        ready.completeError(error);
      }
      worker?._handleUnexpectedExit(error);
    });

    final isolate = await Isolate.spawn<List<Object?>>(
      _sherpaOnnxWorkerMain,
      [responses.sendPort, config.toMessage()],
      paused: true,
      debugName: 'meettrace-sherpa-${config.kind.name}',
      onExit: exits.sendPort,
    );
    SentryIsolateErrorMonitor? sentryErrors;
    try {
      sentryErrors = SentryIsolateErrorMonitor.attach(isolate);
      isolate.resume(isolate.pauseCapability!);
      final commands = await ready.future;
      worker = _IsolateSherpaOnnxWorker._(
        isolate: isolate,
        responses: responses,
        responseSubscription: subscription,
        exits: exits,
        exitSubscription: exitSubscription,
        commands: commands,
        sentryErrors: sentryErrors,
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
      sentryErrors?.close();
      isolate.kill(priority: Isolate.immediate);
      await subscription.cancel();
      await exitSubscription.cancel();
      responses.close();
      exits.close();
      rethrow;
    }
  }

  @override
  Future<SherpaOnnxRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  }) async {
    if (_disposed) {
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
      throw _RemoteWorkerError(response['errorType']! as String);
    }
    return SherpaOnnxRecognition(
      text: response['text']! as String,
      sampleCount: response['sampleCount']! as int,
      elapsed: Duration(microseconds: response['elapsedMicros']! as int),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      final response = await _request({'type': 'dispose'});
      if (response['type'] == 'disposeError') {
        throw _RemoteWorkerError(response['errorType']! as String);
      }
    } finally {
      _sentryErrors.close();
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
    if (id is! int) {
      return;
    }
    _pending.remove(id)?.complete(message);
  }

  void _handleUnexpectedExit(_RemoteWorkerError error) {
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

void _sherpaOnnxWorkerMain(List<Object?> bootstrap) async {
  final responses = bootstrap[0]! as SendPort;
  final config = SherpaOnnxRecognizerConfig.fromMessage(
    bootstrap[1]! as Map<Object?, Object?>,
  );
  final commands = ReceivePort();
  sherpa.OfflineRecognizer? recognizer;

  try {
    sherpa.initBindings();
    recognizer = sherpa.OfflineRecognizer(_officialConfig(config));
    responses.send({'type': 'ready', 'commands': commands.sendPort});

    await for (final raw in commands) {
      if (raw is! Map<Object?, Object?>) {
        continue;
      }
      final id = raw['id']! as int;
      if (raw['type'] == 'recognize') {
        sherpa.OfflineStream? stream;
        final watch = Stopwatch()..start();
        try {
          final activeRecognizer = recognizer;
          if (activeRecognizer == null) {
            throw StateError('识别器已经释放');
          }
          final bytes = (raw['samples']! as TransferableTypedData)
              .materialize()
              .asUint8List();
          final samples = Float32List.view(
            bytes.buffer,
            bytes.offsetInBytes,
            bytes.lengthInBytes ~/ Float32List.bytesPerElement,
          );
          stream = activeRecognizer.createStream();
          stream.acceptWaveform(
            samples: samples,
            sampleRate: raw['sampleRate']! as int,
          );
          activeRecognizer.decode(stream);
          final text = activeRecognizer.getResult(stream).text.trim();
          watch.stop();
          responses.send({
            'type': 'result',
            'id': id,
            'text': text,
            'sampleCount': samples.length,
            'elapsedMicros': watch.elapsedMicroseconds,
          });
        } on Object catch (error) {
          watch.stop();
          responses.send({
            'type': 'inferenceError',
            'id': id,
            'errorType': error.runtimeType.toString(),
          });
        } finally {
          stream?.free();
        }
        continue;
      }
      if (raw['type'] == 'dispose') {
        try {
          final activeRecognizer = recognizer;
          if (activeRecognizer != null) {
            activeRecognizer.free();
          }
          recognizer = null;
          responses.send({'type': 'disposed', 'id': id});
        } on Object catch (error) {
          responses.send({
            'type': 'disposeError',
            'id': id,
            'errorType': error.runtimeType.toString(),
          });
        } finally {
          commands.close();
        }
      }
    }
  } on Object catch (error) {
    responses.send({
      'type': 'initializationError',
      'errorType': error.runtimeType.toString(),
    });
  } finally {
    recognizer?.free();
    commands.close();
  }
}

sherpa.OfflineRecognizerConfig _officialConfig(
  SherpaOnnxRecognizerConfig config,
) {
  return switch (config.kind) {
    SherpaOnnxRecognizerKind.senseVoice => sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        senseVoice: sherpa.OfflineSenseVoiceModelConfig(
          model: config.modelPath,
          language: config.language,
          useInverseTextNormalization: config.useInverseTextNormalization,
        ),
        tokens: config.tokensPath,
        numThreads: config.numThreads,
        debug: false,
        provider: 'cpu',
      ),
    ),
  };
}

String _workerErrorType(Object error) {
  return switch (error) {
    _RemoteWorkerError(:final errorType) => errorType,
    _ => error.runtimeType.toString(),
  };
}

final class _RemoteWorkerError implements Exception {
  const _RemoteWorkerError(this.errorType);

  final String errorType;
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, '不能为空');
  }
}
