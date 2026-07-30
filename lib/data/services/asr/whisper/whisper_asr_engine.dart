import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../../../domain/models/app_failure.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/audio_source.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/models/asr_preview.dart';
import '../asr_engine.dart';
import '../../vad/voice_activity_segmenter.dart';
import 'whisper_adapter.dart';

const whisperAsrSampleRate = 16000;
const whisperMaximumWindowSeconds = 15;
const whisperMaximumWindowSamples =
    whisperAsrSampleRate * whisperMaximumWindowSeconds;

typedef AsrEngineLifecycleHook = Future<void> Function();
typedef FinalVoiceActivitySegmenterFactory = VoiceActivitySegmenter Function();

final class WhisperAsrEngine implements AsrEngine {
  WhisperAsrEngine({
    required this.descriptor,
    required WhisperRecognizerConfig config,
    required String errorPrefix,
    WhisperWorkerFactory workerFactory = const OfficialWhisperWorkerFactory(),
    this._riskMonitor,
    this._beforeOperation,
    this._onDispose,
    this.finalVadFactory,
    DateTime Function()? now,
  }) : _config = config,
       _errorPrefix = errorPrefix,
       _adapter = WhisperAdapter(workerFactory: workerFactory),
       _now = now ?? DateTime.now {
    if (config.modelId != descriptor.modelId ||
        config.modelVersion != descriptor.version) {
      throw ArgumentError('识别配置必须与 Engine descriptor 完全一致');
    }
    if (errorPrefix.trim().isEmpty) {
      throw ArgumentError.value(errorPrefix, 'errorPrefix', '不能为空');
    }
  }

  @override
  final AsrModelDescriptor descriptor;
  final WhisperRecognizerConfig _config;
  final String _errorPrefix;
  final WhisperAdapter _adapter;
  final AsrDeviceRiskMonitor? _riskMonitor;
  final AsrEngineLifecycleHook? _beforeOperation;
  final AsrEngineLifecycleHook? _onDispose;
  final FinalVoiceActivitySegmenterFactory? finalVadFactory;
  final DateTime Function() _now;
  final StreamController<TranscriptEvent> _events =
      StreamController<TranscriptEvent>.broadcast(sync: true);
  final StreamController<AsrFinalizationProgress> _progress =
      StreamController<AsrFinalizationProgress>.broadcast(sync: true);
  final StreamController<AsrDeviceRiskState> _risks =
      StreamController<AsrDeviceRiskState>.broadcast(sync: true);
  final List<AsrWindowDiagnostic> _diagnostics = [];

  Future<void> _operationTail = Future<void>.value();
  Future<void>? _initializing;
  StreamSubscription<AsrDeviceRiskState>? _riskSubscription;
  AsrDeviceRiskState _deviceRisk = const AsrDeviceRiskState.supported();
  bool _initialized = false;
  bool _cancelled = false;
  bool _disposed = false;
  bool _finalizing = false;
  int _nextWindowSequence = 0;
  int _finalizationCompletedSamples = 0;
  int _finalizationTotalSamples = 0;
  AsrFinalizationProgress? _lastProgress;
  int _recognizedWindowCount = 0;
  int _emptyWindowCount = 0;
  int _failedWindowCount = 0;
  int _totalAudioMicroseconds = 0;
  int _totalInferenceMicroseconds = 0;
  String? _lastErrorCode;

  @override
  Stream<TranscriptEvent> get events => _events.stream;

  @override
  Stream<AsrFinalizationProgress> get finalizationProgress => _progress.stream;

  @override
  AsrDeviceRiskState get deviceRisk => _deviceRisk;

  @override
  Stream<AsrDeviceRiskState> get deviceRisks => _risks.stream;

  @override
  List<AsrWindowDiagnostic> get diagnostics => List.unmodifiable(_diagnostics);

  @override
  AsrEngineMetrics get metrics => AsrEngineMetrics(
    modelId: descriptor.modelId,
    modelVersion: descriptor.version,
    totalWindowCount:
        _recognizedWindowCount + _emptyWindowCount + _failedWindowCount,
    recognizedWindowCount: _recognizedWindowCount,
    emptyWindowCount: _emptyWindowCount,
    failedWindowCount: _failedWindowCount,
    totalAudioDuration: Duration(microseconds: _totalAudioMicroseconds),
    totalInferenceDuration: Duration(microseconds: _totalInferenceMicroseconds),
    lastErrorCode: _lastErrorCode,
  );

  @override
  Future<void> initialize() {
    _throwIfDisposed();
    _throwIfCancelled();
    if (_initialized) {
      return Future<void>.value();
    }
    final current = _initializing;
    if (current != null) {
      return current;
    }
    final operation = _initialize();
    _initializing = operation;
    return operation.whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    try {
      await _runBeforeOperation();
      await _inspectRisk();
      _throwIfRiskBlocks(FailureStage.asrInitialization);
      await _adapter.initialize(_config);
      _initialized = true;
      _lastErrorCode = null;
      final monitor = _riskMonitor;
      if (monitor != null) {
        _riskSubscription = monitor.changes.listen(
          _setDeviceRisk,
          onError: (Object _) {
            _lastErrorCode = '$_errorPrefix.risk_monitor_failed';
          },
        );
      }
    } on WhisperAdapterException catch (error) {
      _lastErrorCode = error.failure.code;
      throw AsrEngineException(error.failure);
    } on AsrEngineException catch (error) {
      _lastErrorCode = error.failure.code;
      rethrow;
    } on Object catch (error) {
      final mapped = _exception(
        code: '$_errorPrefix.initialization_failed',
        stage: FailureStage.asrInitialization,
        context: {'errorType': error.runtimeType.toString()},
      );
      _lastErrorCode = mapped.failure.code;
      throw mapped;
    }
  }

  @override
  Future<void> acceptAudio(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  }) async {
    _validateWindow(samples, sampleRate: sampleRate, startMs: startMs);
    await _enqueue(() async {
      await _prepareOperation(stage: FailureStage.asrInference);
      await _recognizeWindow(samples, sampleRate: sampleRate, startMs: startMs);
    });
  }

  @override
  Future<TranscriptSnapshot> finalizeMeeting(
    AudioSource source, {
    required String meetingId,
    String? snapshotId,
  }) async {
    _requireText(meetingId, 'meetingId');
    if (snapshotId != null) {
      _requireText(snapshotId, 'snapshotId');
    }
    await _prepareOperation(stage: FailureStage.finalTranscription);
    _validateAudioSource(source);
    if (_finalizing) {
      throw _exception(
        code: '$_errorPrefix.finalization_in_progress',
        stage: FailureStage.finalTranscription,
      );
    }

    _finalizing = true;
    final file = File(source.path);
    RandomAccessFile? input;
    try {
      if (!await file.exists()) {
        throw _exception(
          code: '$_errorPrefix.audio_not_found',
          stage: FailureStage.finalTranscription,
        );
      }
      final byteLength = await file.length();
      if (byteLength == 0 || byteLength.isOdd) {
        throw _exception(
          code: '$_errorPrefix.invalid_pcm16_file',
          stage: FailureStage.finalTranscription,
          context: {'bytes': byteLength},
        );
      }

      _finalizationCompletedSamples = 0;
      _finalizationTotalSamples = byteLength ~/ 2;
      _emitProgress(AsrFinalizationPhase.processing);
      input = await file.open();
      final resolvedSnapshotId =
          snapshotId ?? 'final-$meetingId-${_now().microsecondsSinceEpoch}';
      final segments = <TranscriptSegment>[];
      var segmentSequence = 0;
      final speechSegments = await _finalSpeechSegments(
        input,
        totalSamples: _finalizationTotalSamples,
      );
      for (final speech in speechSegments) {
        var windowStartSample = speech.startSample;
        while (windowStartSample < speech.endSample) {
          await _prepareOperation(stage: FailureStage.finalTranscription);
          final requestedSamples = (speech.endSample - windowStartSample).clamp(
            1,
            whisperMaximumWindowSamples,
          );
          await input.setPosition(windowStartSample * 2);
          final bytes = await input.read(requestedSamples * 2);
          if (bytes.length != requestedSamples * 2) {
            throw _exception(
              code: '$_errorPrefix.audio_read_incomplete',
              stage: FailureStage.finalTranscription,
              context: {
                'expectedBytes': requestedSamples * 2,
                'actualBytes': bytes.length,
              },
            );
          }
          final samples = _decodePcm16(bytes);
          final startMs = (windowStartSample * 1000) ~/ whisperAsrSampleRate;
          final result = await _recognizeWindow(
            samples,
            sampleRate: whisperAsrSampleRate,
            startMs: startMs,
            segmentId: '$resolvedSnapshotId-window-$windowStartSample',
          );
          windowStartSample += requestedSamples;
          _finalizationCompletedSamples = windowStartSample;
          if (result != null) {
            for (final timedSegment in result.segments) {
              segmentSequence++;
              segments.add(
                TranscriptSegment(
                  id: '$resolvedSnapshotId-segment-$segmentSequence',
                  snapshotId: resolvedSnapshotId,
                  startMs: timedSegment.startMs,
                  endMs: timedSegment.endMs,
                  text: timedSegment.text,
                  modelId: descriptor.modelId,
                  modelVersion: descriptor.version,
                ),
              );
            }
          }
          _emitProgress(AsrFinalizationPhase.processing);
        }
      }
      _finalizationCompletedSamples = _finalizationTotalSamples;

      _emitProgress(AsrFinalizationPhase.completed);
      return TranscriptSnapshot(
        id: resolvedSnapshotId,
        meetingId: meetingId,
        kind: TranscriptSnapshotKind.finalTranscript,
        actualModelId: descriptor.modelId,
        actualModelVersion: descriptor.version,
        createdAt: _now(),
        status: TranscriptSnapshotStatus.complete,
        segments: segments,
      );
    } on AsrEngineException catch (error) {
      _lastErrorCode = error.failure.code;
      _emitTerminalFailure(error.failure.code);
      rethrow;
    } on Object catch (error) {
      final mapped = _exception(
        code: '$_errorPrefix.finalization_failed',
        stage: FailureStage.finalTranscription,
        context: {'errorType': error.runtimeType.toString()},
      );
      _lastErrorCode = mapped.failure.code;
      _emitTerminalFailure(mapped.failure.code);
      throw mapped;
    } finally {
      await input?.close();
      _finalizing = false;
    }
  }

  Future<List<VadSpeechSegment>> _finalSpeechSegments(
    RandomAccessFile input, {
    required int totalSamples,
  }) async {
    final factory = finalVadFactory;
    if (factory == null) {
      return [VadSpeechSegment(startSample: 0, endSample: totalSamples)];
    }
    final vad = factory();
    if (vad.sampleRate != whisperAsrSampleRate) {
      await vad.dispose();
      throw _exception(
        code: '$_errorPrefix.vad_sample_rate_mismatch',
        stage: FailureStage.finalTranscription,
      );
    }
    final detected = <VadSpeechSegment>[];
    var sampleOffset = 0;
    try {
      await input.setPosition(0);
      while (sampleOffset < totalSamples) {
        await _prepareOperation(stage: FailureStage.finalTranscription);
        final requestedSamples = (totalSamples - sampleOffset).clamp(
          1,
          whisperAsrSampleRate,
        );
        final bytes = await input.read(requestedSamples * 2);
        if (bytes.length != requestedSamples * 2) {
          throw _exception(
            code: '$_errorPrefix.audio_read_incomplete',
            stage: FailureStage.finalTranscription,
            context: {
              'expectedBytes': requestedSamples * 2,
              'actualBytes': bytes.length,
            },
          );
        }
        detected.addAll(await vad.accept(_decodePcm16(bytes)));
        sampleOffset += requestedSamples;
      }
      detected.addAll(await vad.flush());
      return _normalizeVadSegments(detected, totalSamples: totalSamples);
    } finally {
      await vad.dispose();
    }
  }

  @override
  void cancel() {
    if (_cancelled || _disposed) {
      return;
    }
    _cancelled = true;
    _adapter.cancel();
    if (_finalizing) {
      _emitProgress(AsrFinalizationPhase.canceled);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _cancelled = true;
    _adapter.cancel();
    Object? failure;
    StackTrace? failureStack;
    try {
      await _operationTail;
      await _adapter.dispose();
    } on Object catch (error, stackTrace) {
      failure = error;
      failureStack = stackTrace;
    }
    try {
      await _riskSubscription?.cancel();
      await _onDispose?.call();
    } on Object catch (error, stackTrace) {
      failure ??= error;
      failureStack ??= stackTrace;
    } finally {
      await _events.close();
      await _progress.close();
      await _risks.close();
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure, failureStack!);
    }
  }

  Future<_WindowResult?> _recognizeWindow(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
    String? segmentId,
  }) async {
    _validateWindow(samples, sampleRate: sampleRate, startMs: startMs);
    final sequence = ++_nextWindowSequence;
    final endMs = startMs + _durationMs(samples.length, sampleRate);
    final audioMicros =
        (samples.length * Duration.microsecondsPerSecond) ~/ sampleRate;
    _totalAudioMicroseconds += audioMicros;
    final watch = Stopwatch()..start();
    try {
      final recognition = await _adapter.recognize(
        samples,
        sampleRate: sampleRate,
      );
      watch.stop();
      _totalInferenceMicroseconds += recognition.elapsed.inMicroseconds;
      final text = recognition.text.trim();
      if (text.isEmpty) {
        _emptyWindowCount++;
        _diagnostics.add(
          AsrWindowDiagnostic(
            startMs: startMs,
            endMs: endMs,
            outcome: AsrWindowOutcome.empty,
            elapsed: recognition.elapsed,
            profileId: _config.profileId,
          ),
        );
        return null;
      }

      _recognizedWindowCount++;
      _diagnostics.add(
        AsrWindowDiagnostic(
          startMs: startMs,
          endMs: endMs,
          outcome: AsrWindowOutcome.recognized,
          elapsed: recognition.elapsed,
          profileId: _config.profileId,
        ),
      );
      final eventSegmentId = segmentId ?? 'preview-$sequence-$startMs-$endMs';
      _events.add(
        TranscriptSegmentEvent(
          segmentId: eventSegmentId,
          startMs: startMs,
          endMs: endMs,
          text: text,
          modelId: descriptor.modelId,
          modelVersion: descriptor.version,
          isFinalForWindow: true,
        ),
      );
      return _WindowResult(
        text: text,
        startMs: startMs,
        endMs: endMs,
        segments: _resolveTimedSegments(
          recognition.segments,
          fallbackText: text,
          windowStartMs: startMs,
          windowEndMs: endMs,
        ),
      );
    } on WhisperAdapterException catch (error) {
      watch.stop();
      _recordWindowFailure(
        startMs: startMs,
        endMs: endMs,
        elapsed: watch.elapsed,
        errorCode: error.failure.code,
      );
      throw AsrEngineException(error.failure);
    } on AsrEngineException catch (error) {
      watch.stop();
      _recordWindowFailure(
        startMs: startMs,
        endMs: endMs,
        elapsed: watch.elapsed,
        errorCode: error.failure.code,
      );
      rethrow;
    } on Object catch (error) {
      watch.stop();
      final mapped = _exception(
        code: '$_errorPrefix.inference_failed',
        stage: FailureStage.asrInference,
        context: {'errorType': error.runtimeType.toString()},
      );
      _recordWindowFailure(
        startMs: startMs,
        endMs: endMs,
        elapsed: watch.elapsed,
        errorCode: mapped.failure.code,
      );
      throw mapped;
    }
  }

  Future<void> _prepareOperation({required FailureStage stage}) async {
    _throwIfUnavailable();
    await _runBeforeOperation();
    _throwIfRiskBlocks(stage);
  }

  Future<void> _runBeforeOperation() async {
    final hook = _beforeOperation;
    if (hook != null) {
      await hook();
    }
  }

  Future<void> _inspectRisk() async {
    final monitor = _riskMonitor;
    if (monitor == null) {
      return;
    }
    try {
      _setDeviceRisk(await monitor.inspect());
    } on Object catch (error) {
      throw _exception(
        code: '$_errorPrefix.risk_check_failed',
        stage: FailureStage.asrInitialization,
        context: {'errorType': error.runtimeType.toString()},
      );
    }
  }

  void _setDeviceRisk(AsrDeviceRiskState risk) {
    _deviceRisk = risk;
    if (!_risks.isClosed) {
      _risks.add(risk);
    }
  }

  void _throwIfRiskBlocks(FailureStage stage) {
    final risk = _deviceRisk;
    if (risk.support == AsrDeviceSupport.unsupported) {
      throw _riskException('$_errorPrefix.device_unsupported', stage);
    }
    if (risk.memoryPressure == AsrMemoryPressure.critical) {
      throw _riskException('$_errorPrefix.memory_pressure_critical', stage);
    }
    if (risk.thermalState == AsrThermalState.critical) {
      throw _riskException('$_errorPrefix.thermal_critical', stage);
    }
  }

  AsrEngineException _riskException(String code, FailureStage stage) {
    return AsrEngineException(
      AppFailure(
        code: code,
        stage: stage,
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        recoverability: FailureRecoverability.userActionRequired,
        userAction: FailureUserAction.chooseAnotherModel,
        diagnosticContext: {
          'support': _deviceRisk.support.name,
          'memoryPressure': _deviceRisk.memoryPressure.name,
          'thermalState': _deviceRisk.thermalState.name,
          'processRssBytes': _deviceRisk.processRssBytes,
          'estimatedAvailableBytes': _deviceRisk.estimatedAvailableBytes,
        },
      ),
    );
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  void _recordWindowFailure({
    required int startMs,
    required int endMs,
    required Duration elapsed,
    required String errorCode,
  }) {
    _failedWindowCount++;
    _totalInferenceMicroseconds += elapsed.inMicroseconds;
    _lastErrorCode = errorCode;
    _diagnostics.add(
      AsrWindowDiagnostic(
        startMs: startMs,
        endMs: endMs,
        outcome: AsrWindowOutcome.failed,
        elapsed: elapsed,
        errorCode: errorCode,
        profileId: _config.profileId,
      ),
    );
  }

  void _validateWindow(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  }) {
    _throwIfUnavailable();
    if (sampleRate != whisperAsrSampleRate || samples.isEmpty || startMs < 0) {
      throw _exception(
        code: '$_errorPrefix.invalid_audio_window',
        stage: FailureStage.asrInference,
        context: {
          'sampleRate': sampleRate,
          'sampleCount': samples.length,
          'startMs': startMs,
        },
      );
    }
    if (samples.length > whisperMaximumWindowSamples) {
      throw _exception(
        code: '$_errorPrefix.window_too_long',
        stage: FailureStage.asrInference,
        context: {
          'sampleCount': samples.length,
          'maximumSamples': whisperMaximumWindowSamples,
        },
      );
    }
  }

  void _validateAudioSource(AudioSource source) {
    if (source.sampleRate != whisperAsrSampleRate || source.channelCount != 1) {
      throw _exception(
        code: '$_errorPrefix.unsupported_audio_source',
        stage: FailureStage.finalTranscription,
        context: {
          'sampleRate': source.sampleRate,
          'channelCount': source.channelCount,
        },
      );
    }
  }

  void _throwIfUnavailable() {
    _throwIfDisposed();
    _throwIfCancelled();
    if (!_initialized) {
      throw _exception(
        code: '$_errorPrefix.not_initialized',
        stage: FailureStage.asrInitialization,
      );
    }
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw _exception(
        code: '$_errorPrefix.disposed',
        stage: FailureStage.asrInitialization,
      );
    }
  }

  void _throwIfCancelled() {
    if (_cancelled) {
      throw _exception(
        code: '$_errorPrefix.cancelled',
        stage: _finalizing
            ? FailureStage.finalTranscription
            : FailureStage.asrInference,
      );
    }
  }

  AsrEngineException _exception({
    required String code,
    required FailureStage stage,
    Map<String, Object?> context = const {},
  }) {
    return AsrEngineException(
      AppFailure(
        code: code,
        stage: stage,
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        recoverability: FailureRecoverability.retryable,
        userAction: FailureUserAction.retry,
        diagnosticContext: context,
      ),
    );
  }

  void _emitTerminalFailure(String errorCode) {
    final phase = errorCode.endsWith('.cancelled')
        ? AsrFinalizationPhase.canceled
        : AsrFinalizationPhase.failed;
    if (_lastProgress?.phase != phase) {
      _emitProgress(phase);
    }
  }

  void _emitProgress(AsrFinalizationPhase phase) {
    final progress = AsrFinalizationProgress(
      phase: phase,
      completedSamples: _finalizationCompletedSamples,
      totalSamples: _finalizationTotalSamples,
    );
    _lastProgress = progress;
    _progress.add(progress);
  }
}

List<VadSpeechSegment> _normalizeVadSegments(
  Iterable<VadSpeechSegment> segments, {
  required int totalSamples,
}) {
  final sorted =
      segments
          .map(
            (segment) => (
              start: segment.startSample.clamp(0, totalSamples),
              end: segment.endSample.clamp(0, totalSamples),
            ),
          )
          .where((segment) => segment.end > segment.start)
          .toList()
        ..sort((left, right) => left.start.compareTo(right.start));
  final result = <VadSpeechSegment>[];
  for (final segment in sorted) {
    if (result.isEmpty || segment.start > result.last.endSample) {
      result.add(
        VadSpeechSegment(startSample: segment.start, endSample: segment.end),
      );
      continue;
    }
    final previous = result.removeLast();
    result.add(
      VadSpeechSegment(
        startSample: previous.startSample,
        endSample: segment.end > previous.endSample
            ? segment.end
            : previous.endSample,
      ),
    );
  }
  return List.unmodifiable(result);
}

Float32List _decodePcm16(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final samples = Float32List(bytes.length ~/ 2);
  for (var index = 0; index < samples.length; index++) {
    samples[index] = data.getInt16(index * 2, Endian.little) / 32768;
  }
  return samples;
}

int _durationMs(int sampleCount, int sampleRate) {
  return (sampleCount * 1000 + sampleRate - 1) ~/ sampleRate;
}

List<_TimedTextSegment> _resolveTimedSegments(
  List<WhisperRecognitionSegment> segments, {
  required String fallbackText,
  required int windowStartMs,
  required int windowEndMs,
}) {
  final windowDurationMs = windowEndMs - windowStartMs;
  final result = <_TimedTextSegment>[];
  var hasUnusableText = false;
  for (final segment in segments) {
    final text = segment.text.trim();
    if (text.isEmpty) {
      continue;
    }
    final relativeStart = segment.startMs.clamp(0, windowDurationMs);
    final relativeEnd = segment.endMs.clamp(0, windowDurationMs);
    if (relativeEnd <= relativeStart) {
      hasUnusableText = true;
      continue;
    }
    result.add(
      _TimedTextSegment(
        text: text,
        startMs: windowStartMs + relativeStart,
        endMs: windowStartMs + relativeEnd,
      ),
    );
  }
  if (result.isNotEmpty && !hasUnusableText) {
    return List.unmodifiable(result);
  }
  return [
    _TimedTextSegment(
      text: fallbackText,
      startMs: windowStartMs,
      endMs: windowEndMs,
    ),
  ];
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, '不能为空');
  }
}

final class _WindowResult {
  const _WindowResult({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.segments,
  });

  final String text;
  final int startMs;
  final int endMs;
  final List<_TimedTextSegment> segments;
}

final class _TimedTextSegment {
  const _TimedTextSegment({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final String text;
  final int startMs;
  final int endMs;
}
