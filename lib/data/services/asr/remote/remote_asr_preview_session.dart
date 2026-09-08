import 'dart:async';
import 'dart:collection';

import '../../../../domain/models/asr_preview.dart';
import '../../../../domain/models/recording.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/ports/asr_engine.dart';
import '../../../../domain/ports/asr_preview_session.dart';
import '../../audio/recording_ports.dart';
import 'pcm16_resampler.dart';

/// 不经本地 VAD；网络消费与事实 PCM 的落盘交付分离。
final class RemoteAsrPreviewSession
    implements AsrPreviewSession, RecordingPreviewSink {
  RemoteAsrPreviewSession({
    required this.engine,
    this.enabled = true,
    this.maximumQueuedAudioMs = 5000,
    this.stopTimeout = const Duration(milliseconds: 500),
  }) {
    if (maximumQueuedAudioMs <= 0 || stopTimeout <= Duration.zero) {
      throw ArgumentError('remote.invalid_preview_limits');
    }
    if (!enabled) _state = AsrPreviewState.recordingOnly;
    _engineEvents = engine.events.listen((event) {
      if (_state != AsrPreviewState.disposed &&
          _state != AsrPreviewState.recordingOnly) {
        _events.add(event);
        if (event is TranscriptSegmentEvent && event.isFinalForWindow) {
          _coveredMs = event.endMs > _coveredMs ? event.endMs : _coveredMs;
          _emitMetrics();
        }
      }
    }, onError: (Object error) => _fail(error));
  }

  final AsrEngine engine;
  final bool enabled;
  final int maximumQueuedAudioMs;
  final Duration stopTimeout;
  final Queue<RecordingPcmChunk> _pending = Queue();
  final _events = StreamController<TranscriptEvent>.broadcast();
  final _metrics = StreamController<AsrPreviewMetrics>.broadcast();
  late final StreamSubscription<TranscriptEvent> _engineEvents;
  AsrPreviewState _state = AsrPreviewState.ready;
  Future<void>? _initializing;
  Future<void>? _draining;
  bool _initialized = false;
  bool _disposed = false;
  int _queuedBytes = 0;
  int _processed = 0;
  int _dropped = 0;
  int _latestMs = 0;
  int _audioEpoch = 0;
  int _coveredMs = 0;
  String? _lastError;

  bool get _active =>
      _state != AsrPreviewState.disposed &&
      _state != AsrPreviewState.recordingOnly;
  @override
  Stream<TranscriptEvent> get events => _events.stream;
  @override
  Stream<AsrPreviewMetrics> get metricsChanges => _metrics.stream;
  @override
  AsrPreviewMetrics get metrics => AsrPreviewMetrics(
    state: _state,
    vadSegmentCount: 0,
    queuedAudioMs: _queuedBytes * 1000 ~/ recordingBytesPerSecond,
    processedPreviewWindows: _processed,
    droppedPreviewWindows: _dropped,
    previewLagMs: (_latestMs - _coveredMs).clamp(0, _latestMs),
    lastErrorCode: _lastError,
  );

  @override
  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    if (!_active) return;
    try {
      await engine.initialize();
      _initialized = true;
      _startDrain();
    } on Object catch (error) {
      _fail(error);
    }
  }

  @override
  Future<void> add(RecordingPcmChunk chunk) async {
    if (!_active) return;
    _audioEpoch++;
    _latestMs = chunk.end.inMilliseconds;
    if ((_queuedBytes + chunk.bytes.length) * 1000 >
        maximumQueuedAudioMs * recordingBytesPerSecond) {
      _dropped++;
      _fail(null, code: 'asr.remote.backlog_exceeded');
      return;
    }
    _pending.add(chunk);
    _queuedBytes += chunk.bytes.length;
    _state = _queuedBytes * 1000 >= recordingBytesPerSecond * 1000
        ? AsrPreviewState.backlogged
        : AsrPreviewState.ready;
    _emitMetrics();
    _startDrain();
  }

  void _startDrain() {
    if (!_initialized || !_active || _draining != null || _pending.isEmpty) {
      return;
    }
    _draining = _drain().whenComplete(() {
      _draining = null;
      _startDrain();
    });
  }

  Future<void> _drain() async {
    while (_active && _pending.isNotEmpty) {
      final chunk = _pending.removeFirst();
      _queuedBytes -= chunk.bytes.length;
      try {
        await engine.acceptAudio(
          decodeRemotePcm16(chunk.bytes),
          sampleRate: recordingSampleRate,
          startMs: chunk.start.inMilliseconds,
        );
        _processed++;
      } on Object catch (error) {
        _fail(error);
      }
      if (_active && _pending.isEmpty) _state = AsrPreviewState.ready;
      _emitMetrics();
    }
  }

  @override
  Future<void> flush() async {
    if (!_active || !_initialized) return;
    final epoch = _audioEpoch;
    await _draining;
    if (!_active || epoch != _audioEpoch) return;
    try {
      if (engine case final AsrPreviewControl control) {
        await control.flushPreview();
      }
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _fail(Object? error, {String? code}) {
    if (!_active) return;
    _lastError =
        code ??
        (error is AsrEngineException
            ? error.failure.code
            : 'asr.remote.preview_failed');
    _state = AsrPreviewState.recordingOnly;
    _dropped += _pending.length;
    _pending.clear();
    _queuedBytes = 0;
    engine.cancel();
    _emitMetrics();
  }

  void _emitMetrics() {
    if (!_metrics.isClosed) _metrics.add(metrics);
  }

  @override
  Future<void> stop() async {
    if (_state == AsrPreviewState.disposed) return;
    _state = AsrPreviewState.disposed;
    _dropped += _pending.length;
    _pending.clear();
    _queuedBytes = 0;
    engine.cancel();
    _emitMetrics();
    try {
      await _draining?.timeout(stopTimeout);
    } on Object {
      // 结束录音不等待派生网络队列。
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _engineEvents.cancel();
    await engine.dispose();
    await _events.close();
    await _metrics.close();
  }
}
