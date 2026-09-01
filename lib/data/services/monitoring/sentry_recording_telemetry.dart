import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meettrace/domain/ports/recording_telemetry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef RecordingWindowTimerFactory = Timer Function(
  Duration duration,
  void Function(Timer timer) callback,
);

typedef RecordingPerformanceWindowEmitter = void Function(
  RecordingPerformanceWindow window,
);

final class RecordingPerformanceWindow {
  const RecordingPerformanceWindow({
    required this.pcmWriteLatencyMs,
    required this.writeBacklog,
    required this.previewQueueMs,
    required this.droppedPreviewWindows,
    required this.interruptions,
    required this.recoveries,
    required this.duration,
  });

  final double pcmWriteLatencyMs;
  final int writeBacklog;
  final int previewQueueMs;
  final int droppedPreviewWindows;
  final int interruptions;
  final int recoveries;
  final Duration duration;
}

final class SentryRecordingTelemetryGate implements RecordingTelemetryGate {
  SentryRecordingTelemetryGate({
    this.windowDuration = const Duration(seconds: 60),
    this._timerFactory = Timer.periodic,
    RecordingPerformanceWindowEmitter? emit,
    DateTime Function()? now,
  }) : _emit = emit ?? _emitToSentry,
       _now = now ?? DateTime.now {
    if (windowDuration <= Duration.zero) {
      throw ArgumentError.value(windowDuration, 'windowDuration');
    }
  }

  final Duration windowDuration;
  final RecordingWindowTimerFactory _timerFactory;
  final RecordingPerformanceWindowEmitter _emit;
  final DateTime Function() _now;

  bool _diagnosticsEnabled = false;
  bool _performanceSampled = false;
  bool _recordingActive = false;
  Timer? _timer;
  DateTime? _windowStartedAt;
  int _pcmWriteCount = 0;
  int _pcmWriteLatencyMicros = 0;
  int _writeBacklog = 0;
  int _previewQueueMs = 0;
  int _lastDroppedPreviewWindows = 0;
  bool _skipNextPreviewDelta = true;
  int _droppedPreviewWindows = 0;
  int _interruptions = 0;
  int _recoveries = 0;

  @override
  bool get recordingActive => _recordingActive;

  @visibleForTesting
  bool get isCollecting => _canCollect;

  void configure({required bool enabled, required bool performanceSampled}) {
    _diagnosticsEnabled = enabled;
    _performanceSampled = performanceSampled;
    if (_canCollect) {
      _startWindow();
    } else {
      _stopWindow();
    }
  }

  @override
  void setRecordingActive(bool active) {
    if (_recordingActive == active) {
      return;
    }
    _recordingActive = active;
    _lastDroppedPreviewWindows = 0;
    if (_canCollect) {
      _startWindow();
    } else {
      _stopWindow();
    }
  }

  @override
  void observePcmWrite({
    required Duration latency,
    required int pendingChunks,
  }) {
    if (!_canCollect) {
      return;
    }
    _pcmWriteCount++;
    _pcmWriteLatencyMicros += latency.inMicroseconds;
    if (pendingChunks > _writeBacklog) {
      _writeBacklog = pendingChunks;
    }
  }

  @override
  void observePreview({
    required int queuedAudioMs,
    required int droppedWindows,
  }) {
    if (!_canCollect) {
      _lastDroppedPreviewWindows = droppedWindows;
      return;
    }
    if (queuedAudioMs > _previewQueueMs) {
      _previewQueueMs = queuedAudioMs;
    }
    if (_skipNextPreviewDelta) {
      _skipNextPreviewDelta = false;
    } else if (droppedWindows >= _lastDroppedPreviewWindows) {
      _droppedPreviewWindows += droppedWindows - _lastDroppedPreviewWindows;
    }
    _lastDroppedPreviewWindows = droppedWindows;
  }

  @override
  void recordInterruption() {
    if (_canCollect) {
      _interruptions++;
    }
  }

  @override
  void recordRecovery() {
    if (_canCollect) {
      _recoveries++;
    }
  }

  bool get _canCollect =>
      _diagnosticsEnabled && _performanceSampled && _recordingActive;

  void _startWindow() {
    if (_timer != null) {
      return;
    }
    _resetWindow();
    _skipNextPreviewDelta = true;
    _timer = _timerFactory(windowDuration, (_) => _emitWindow());
  }

  void _stopWindow() {
    _timer?.cancel();
    _timer = null;
    _resetWindow();
  }

  void _emitWindow() {
    if (!_canCollect) {
      _stopWindow();
      return;
    }
    final startedAt = _windowStartedAt ?? _now();
    final window = RecordingPerformanceWindow(
      pcmWriteLatencyMs: _pcmWriteCount == 0
          ? 0
          : _pcmWriteLatencyMicros / _pcmWriteCount / 1000,
      writeBacklog: _writeBacklog,
      previewQueueMs: _previewQueueMs,
      droppedPreviewWindows: _droppedPreviewWindows,
      interruptions: _interruptions,
      recoveries: _recoveries,
      duration: _now().difference(startedAt),
    );
    _resetWindow();
    try {
      _emit(window);
    } on Object {
      // Metrics 失败不得进入录音调用链或 Timer 的未处理错误区。
    }
  }

  void _resetWindow() {
    _windowStartedAt = _now();
    _pcmWriteCount = 0;
    _pcmWriteLatencyMicros = 0;
    _writeBacklog = 0;
    _previewQueueMs = 0;
    _droppedPreviewWindows = 0;
    _interruptions = 0;
    _recoveries = 0;
  }

  static void _emitToSentry(RecordingPerformanceWindow window) {
    Sentry.metrics
      ..distribution(
        'recording.pcm_write_latency',
        window.pcmWriteLatencyMs,
        unit: SentryMetricUnit.millisecond,
      )
      ..gauge('recording.write_backlog', window.writeBacklog)
      ..gauge(
        'recording.preview_queue',
        window.previewQueueMs,
        unit: SentryMetricUnit.millisecond,
      )
      ..count('recording.preview_dropped', window.droppedPreviewWindows)
      ..count('recording.interruptions', window.interruptions)
      ..count('recording.recoveries', window.recoveries)
      ..distribution(
        'recording.window_duration',
        window.duration.inMilliseconds,
        unit: SentryMetricUnit.millisecond,
      );
  }
}

final sentryRecordingTelemetryGate = SentryRecordingTelemetryGate();
