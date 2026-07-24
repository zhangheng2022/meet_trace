import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../domain/models/app_failure.dart';
import '../../../domain/models/asr_model.dart';
import '../../../domain/models/asr_model_registry.dart';
import '../../../domain/models/audio_source.dart';
import '../../../domain/models/model_installation.dart';
import '../../../domain/models/transcript.dart';
import '../../../domain/models/workflow_states.dart';
import 'asr_engine.dart';
import 'sherpa_onnx/sherpa_onnx_adapter.dart';

const paraformerSampleRate = 16000;
const paraformerMaximumWindowSeconds = 15;
const _maximumWindowSamples =
    paraformerSampleRate * paraformerMaximumWindowSeconds;

final class ParaformerStandardAsrEngine implements AsrEngine {
  factory ParaformerStandardAsrEngine({
    required ModelInstallation installation,
    SherpaOnnxWorkerFactory workerFactory =
        const OfficialSherpaOnnxWorkerFactory(),
    DateTime Function()? now,
  }) {
    final descriptor = AsrModelRegistry.alpha.requireById(
      paraformerStandardModelId,
    );
    _validateModel(descriptor, installation);
    return ParaformerStandardAsrEngine._(
      descriptor: descriptor,
      installation: installation,
      adapter: SherpaOnnxAdapter(workerFactory: workerFactory),
      now: now ?? DateTime.now,
    );
  }

  ParaformerStandardAsrEngine._({
    required this.descriptor,
    required this._installation,
    required this._adapter,
    required this._now,
  });

  @override
  final AsrModelDescriptor descriptor;
  final ModelInstallation _installation;
  final SherpaOnnxAdapter _adapter;
  final DateTime Function() _now;
  final StreamController<TranscriptEvent> _events =
      StreamController<TranscriptEvent>.broadcast(sync: true);
  final StreamController<AsrFinalizationProgress> _progress =
      StreamController<AsrFinalizationProgress>.broadcast(sync: true);
  final List<AsrWindowDiagnostic> _diagnostics = [];

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
  Future<void> initialize() async {
    _throwIfDisposed();
    _throwIfCancelled();
    if (_initialized) {
      return;
    }
    final modelRoot = _installation.installedPath!;
    final config = SherpaOnnxRecognizerConfig.paraformer(
      modelId: descriptor.modelId,
      modelVersion: descriptor.version,
      modelPath: p.join(modelRoot, 'model.int8.onnx'),
      tokensPath: p.join(modelRoot, 'tokens.txt'),
    );
    try {
      await _adapter.initialize(config);
      _initialized = true;
      _lastErrorCode = null;
    } on SherpaOnnxAdapterException catch (error) {
      _lastErrorCode = error.failure.code;
      throw AsrEngineException(error.failure);
    }
  }

  @override
  Future<void> acceptAudio(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  }) async {
    _validateWindow(samples, sampleRate: sampleRate, startMs: startMs);
    await _recognizeWindow(samples, sampleRate: sampleRate, startMs: startMs);
  }

  @override
  Future<TranscriptSnapshot> finalizeMeeting(
    AudioSource source, {
    required String meetingId,
  }) async {
    _requireText(meetingId, 'meetingId');
    _throwIfUnavailable();
    _validateAudioSource(source);
    if (_finalizing) {
      throw _exception(
        code: 'asr.paraformer.finalization_in_progress',
        stage: FailureStage.finalTranscription,
      );
    }

    _finalizing = true;
    final file = File(source.path);
    RandomAccessFile? input;
    try {
      if (!await file.exists()) {
        throw _exception(
          code: 'asr.paraformer.audio_not_found',
          stage: FailureStage.finalTranscription,
        );
      }
      final byteLength = await file.length();
      if (byteLength == 0 || byteLength.isOdd) {
        throw _exception(
          code: 'asr.paraformer.invalid_pcm16_file',
          stage: FailureStage.finalTranscription,
          context: {'bytes': byteLength},
        );
      }

      _finalizationCompletedSamples = 0;
      _finalizationTotalSamples = byteLength ~/ 2;
      _emitProgress(AsrFinalizationPhase.processing);
      input = await file.open();
      final snapshotId = 'final-$meetingId-${_now().microsecondsSinceEpoch}';
      final segments = <TranscriptSegment>[];
      var segmentSequence = 0;

      while (_finalizationCompletedSamples < _finalizationTotalSamples) {
        _throwIfCancelled();
        final remaining =
            _finalizationTotalSamples - _finalizationCompletedSamples;
        final requestedSamples = remaining > _maximumWindowSamples
            ? _maximumWindowSamples
            : remaining;
        final bytes = await input.read(requestedSamples * 2);
        if (bytes.length != requestedSamples * 2) {
          throw _exception(
            code: 'asr.paraformer.audio_read_incomplete',
            stage: FailureStage.finalTranscription,
            context: {
              'expectedBytes': requestedSamples * 2,
              'actualBytes': bytes.length,
            },
          );
        }
        final samples = _decodePcm16(bytes);
        final startMs =
            (_finalizationCompletedSamples * 1000) ~/ paraformerSampleRate;
        final segmentId = '$snapshotId-segment-${segmentSequence + 1}';
        final result = await _recognizeWindow(
          samples,
          sampleRate: paraformerSampleRate,
          startMs: startMs,
          segmentId: segmentId,
        );
        _finalizationCompletedSamples += requestedSamples;
        if (result != null) {
          segments.add(
            TranscriptSegment(
              id: segmentId,
              snapshotId: snapshotId,
              startMs: result.startMs,
              endMs: result.endMs,
              text: result.text,
              modelId: descriptor.modelId,
              modelVersion: descriptor.version,
            ),
          );
          segmentSequence++;
        }
        _emitProgress(AsrFinalizationPhase.processing);
      }

      _emitProgress(AsrFinalizationPhase.completed);
      return TranscriptSnapshot(
        id: snapshotId,
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
        code: 'asr.paraformer.finalization_failed',
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
    await _adapter.dispose();
    await _events.close();
    await _progress.close();
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
      return _WindowResult(text: text, startMs: startMs, endMs: endMs);
    } on SherpaOnnxAdapterException catch (error) {
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
        code: 'asr.paraformer.inference_failed',
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
      ),
    );
  }

  void _validateWindow(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  }) {
    _throwIfUnavailable();
    if (sampleRate != paraformerSampleRate || samples.isEmpty || startMs < 0) {
      throw _exception(
        code: 'asr.paraformer.invalid_audio_window',
        stage: FailureStage.asrInference,
        context: {
          'sampleRate': sampleRate,
          'sampleCount': samples.length,
          'startMs': startMs,
        },
      );
    }
    if (samples.length > _maximumWindowSamples) {
      throw _exception(
        code: 'asr.paraformer.window_too_long',
        stage: FailureStage.asrInference,
        context: {
          'sampleCount': samples.length,
          'maximumSamples': _maximumWindowSamples,
        },
      );
    }
  }

  void _validateAudioSource(AudioSource source) {
    if (source.sampleRate != paraformerSampleRate || source.channelCount != 1) {
      throw _exception(
        code: 'asr.paraformer.unsupported_audio_source',
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
        code: 'asr.paraformer.not_initialized',
        stage: FailureStage.asrInitialization,
      );
    }
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw _exception(
        code: 'asr.paraformer.disposed',
        stage: FailureStage.asrInitialization,
      );
    }
  }

  void _throwIfCancelled() {
    if (_cancelled) {
      throw _exception(
        code: 'asr.paraformer.cancelled',
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

void _validateModel(
  AsrModelDescriptor descriptor,
  ModelInstallation installation,
) {
  final validDescriptor =
      descriptor.modelId == paraformerStandardModelId &&
      descriptor.tier == AsrModelTier.standard &&
      descriptor.installationType == AsrInstallationType.bundled;
  final validInstallation =
      installation.modelId == descriptor.modelId &&
      installation.version == descriptor.version &&
      installation.installationType == descriptor.installationType &&
      installation.state == ModelInstallationState.installed &&
      installation.verifiedAt != null &&
      installation.installedPath?.trim().isNotEmpty == true &&
      installation.bytes == descriptor.requiredBytes;
  if (!validDescriptor || !validInstallation) {
    throw AsrEngineException(
      AppFailure(
        code: 'asr.paraformer.model_not_verified',
        stage: FailureStage.modelVerification,
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        recoverability: FailureRecoverability.userActionRequired,
        userAction: FailureUserAction.downloadModel,
      ),
    );
  }
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
  });

  final String text;
  final int startMs;
  final int endMs;
}
