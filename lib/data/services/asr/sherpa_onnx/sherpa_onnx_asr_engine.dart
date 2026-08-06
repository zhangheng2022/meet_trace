import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../../../domain/models/app_failure.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/asr_preview.dart';
import '../../../../domain/models/audio_source.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/ports/asr_engine.dart';
import '../../../../domain/use_cases/plan_asr_preview_windows.dart';
import '../../vad/silero_vad_segmenter.dart';
import 'sherpa_onnx_adapter.dart';

const sherpaOnnxAsrSampleRate = 16000;
const sherpaOnnxMaximumWindowSeconds = 15;
const sherpaOnnxMaximumWindowSamples =
    sherpaOnnxAsrSampleRate * sherpaOnnxMaximumWindowSeconds;
const _finalVadScanSamples = sherpaOnnxAsrSampleRate;
const _finalVadMergeGapSamples =
    sherpaOnnxAsrSampleRate * 500 ~/ Duration.millisecondsPerSecond;

typedef AsrEngineLifecycleHook = Future<void> Function();
typedef FinalVadFactory = VoiceActivitySegmenter Function();

final class SherpaOnnxAsrEngine implements AsrEngine {
  SherpaOnnxAsrEngine({
    required this.descriptor,
    required SherpaOnnxRecognizerConfig config,
    required String errorPrefix,
    SherpaOnnxWorkerFactory workerFactory =
        const OfficialSherpaOnnxWorkerFactory(),
    this._riskMonitor,
    this._beforeOperation,
    this._onDispose,
    this._finalVadFactory,
    this._finalWindowPlanner = const AsrPreviewWindowPlanner(),
    DateTime Function()? now,
  }) : _config = config,
       _errorPrefix = errorPrefix,
       _adapter = SherpaOnnxAdapter(workerFactory: workerFactory),
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
  final SherpaOnnxRecognizerConfig _config;
  final String _errorPrefix;
  final SherpaOnnxAdapter _adapter;
  final AsrDeviceRiskMonitor? _riskMonitor;
  final AsrEngineLifecycleHook? _beforeOperation;
  final AsrEngineLifecycleHook? _onDispose;
  final FinalVadFactory? _finalVadFactory;
  final AsrPreviewWindowPlanner _finalWindowPlanner;
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
    } on SherpaOnnxAdapterException catch (error) {
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
    _validateAudioSource(source);
    _throwIfDisposed();
    _throwIfCancelled();
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
      final speechSegments = await _detectFinalSpeech(
        input,
        totalSamples: _finalizationTotalSamples,
      );
      final segments = speechSegments == null
          ? await _transcribeFullAudio(input, snapshotId: resolvedSnapshotId)
          : await _transcribeSpeechSegments(
              input,
              speechSegments: speechSegments,
              snapshotId: resolvedSnapshotId,
            );

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

  Future<List<VadSpeechSegment>?> _detectFinalSpeech(
    RandomAccessFile input, {
    required int totalSamples,
  }) async {
    final factory = _finalVadFactory;
    if (factory == null) {
      return null;
    }
    VoiceActivitySegmenter? vad;
    List<VadSpeechSegment>? result;
    try {
      vad = factory();
      if (vad.sampleRate != sherpaOnnxAsrSampleRate) {
        throw StateError('最终 VAD 采样率必须为 16 kHz');
      }
      await input.setPosition(0);
      var scannedSamples = 0;
      final segments = <VadSpeechSegment>[];
      while (scannedSamples < totalSamples) {
        _throwIfCancelled();
        final remaining = totalSamples - scannedSamples;
        final requested = remaining > _finalVadScanSamples
            ? _finalVadScanSamples
            : remaining;
        final bytes = await input.read(requested * 2);
        if (bytes.length != requested * 2) {
          throw StateError('最终 VAD 读取事实 PCM 不完整');
        }
        segments.addAll(vad.accept(_decodePcm16(bytes)));
        scannedSamples += requested;
      }
      segments.addAll(vad.flush());
      _validateVadSegments(segments, totalSamples: totalSamples);
      result = _mergeAdjacentSpeechSegments(segments);
    } on Object {
      result = null;
    }
    try {
      vad?.dispose();
    } on Object {
      result = null;
    }
    return result;
  }

  Future<List<TranscriptSegment>> _transcribeSpeechSegments(
    RandomAccessFile input, {
    required List<VadSpeechSegment> speechSegments,
    required String snapshotId,
  }) async {
    final segments = <TranscriptSegment>[];
    for (final speech in speechSegments) {
      final windows = _finalWindowPlanner(
        segment: speech,
        availableStartSample: 0,
        availableEndSample: _finalizationTotalSamples,
      );
      final segmentId = '$snapshotId-segment-${segments.length + 1}';
      var merged = '';
      for (final window in windows) {
        await _prepareFinalRecognition();
        final samples = await _readSamples(
          input,
          startSample: window.startSample,
          sampleCount: window.endSample - window.startSample,
        );
        final result = await _recognizeWindow(
          samples,
          sampleRate: sherpaOnnxAsrSampleRate,
          startMs: window.startSample * 1000 ~/ sherpaOnnxAsrSampleRate,
          segmentId: segmentId,
        );
        if (result != null) {
          merged = mergeOverlappingTranscriptText(merged, result.text);
        }
        if (window.endSample > _finalizationCompletedSamples) {
          _finalizationCompletedSamples = window.endSample;
        }
        _emitProgress(AsrFinalizationPhase.processing);
      }
      if (merged.isNotEmpty) {
        segments.add(
          TranscriptSegment(
            id: segmentId,
            snapshotId: snapshotId,
            startMs:
                windows.first.startSample * 1000 ~/ sherpaOnnxAsrSampleRate,
            endMs:
                (windows.last.endSample * 1000 + sherpaOnnxAsrSampleRate - 1) ~/
                sherpaOnnxAsrSampleRate,
            text: merged,
            modelId: descriptor.modelId,
            modelVersion: descriptor.version,
          ),
        );
      }
    }
    return segments;
  }

  Future<List<TranscriptSegment>> _transcribeFullAudio(
    RandomAccessFile input, {
    required String snapshotId,
  }) async {
    await input.setPosition(0);
    final segments = <TranscriptSegment>[];
    _finalizationCompletedSamples = 0;
    while (_finalizationCompletedSamples < _finalizationTotalSamples) {
      await _prepareFinalRecognition();
      final remaining =
          _finalizationTotalSamples - _finalizationCompletedSamples;
      final requestedSamples = remaining > sherpaOnnxMaximumWindowSamples
          ? sherpaOnnxMaximumWindowSamples
          : remaining;
      final samples = await _readSamples(
        input,
        startSample: _finalizationCompletedSamples,
        sampleCount: requestedSamples,
      );
      final startMs =
          (_finalizationCompletedSamples * 1000) ~/ sherpaOnnxAsrSampleRate;
      final segmentId = '$snapshotId-segment-${segments.length + 1}';
      final result = await _recognizeWindow(
        samples,
        sampleRate: sherpaOnnxAsrSampleRate,
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
      }
      _emitProgress(AsrFinalizationPhase.processing);
    }
    return segments;
  }

  Future<void> _prepareFinalRecognition() async {
    if (!_initialized) {
      await initialize();
    }
    await _prepareOperation(stage: FailureStage.finalTranscription);
  }

  Future<Float32List> _readSamples(
    RandomAccessFile input, {
    required int startSample,
    required int sampleCount,
  }) async {
    await input.setPosition(startSample * 2);
    final bytes = await input.read(sampleCount * 2);
    if (bytes.length != sampleCount * 2) {
      throw _exception(
        code: '$_errorPrefix.audio_read_incomplete',
        stage: FailureStage.finalTranscription,
        context: {
          'expectedBytes': sampleCount * 2,
          'actualBytes': bytes.length,
        },
      );
    }
    return _decodePcm16(bytes);
  }

  void _validateVadSegments(
    List<VadSpeechSegment> segments, {
    required int totalSamples,
  }) {
    VadSpeechSegment? previous;
    for (final segment in segments) {
      if (segment.endSample > totalSamples ||
          (previous != null && segment.startSample < previous.endSample)) {
        throw StateError('最终 VAD 返回了越界或重叠区间');
      }
      previous = segment;
    }
  }

  List<VadSpeechSegment> _mergeAdjacentSpeechSegments(
    List<VadSpeechSegment> segments,
  ) {
    if (segments.length < 2) {
      return List.unmodifiable(segments);
    }
    final merged = <VadSpeechSegment>[];
    var current = segments.first;
    for (final next in segments.skip(1)) {
      if (next.startSample - current.endSample < _finalVadMergeGapSamples) {
        current = VadSpeechSegment(
          startSample: current.startSample,
          endSample: next.endSample,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    return List.unmodifiable(merged);
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
      ),
    );
  }

  void _validateWindow(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  }) {
    _throwIfUnavailable();
    if (sampleRate != sherpaOnnxAsrSampleRate ||
        samples.isEmpty ||
        startMs < 0) {
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
    if (samples.length > sherpaOnnxMaximumWindowSamples) {
      throw _exception(
        code: '$_errorPrefix.window_too_long',
        stage: FailureStage.asrInference,
        context: {
          'sampleCount': samples.length,
          'maximumSamples': sherpaOnnxMaximumWindowSamples,
        },
      );
    }
  }

  void _validateAudioSource(AudioSource source) {
    if (source.sampleRate != sherpaOnnxAsrSampleRate ||
        source.channelCount != 1) {
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
