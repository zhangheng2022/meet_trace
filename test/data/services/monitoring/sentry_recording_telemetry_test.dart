import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/monitoring/sentry_recording_telemetry.dart';

void main() {
  test('被抽样录音每 60 秒提交一个匿名聚合窗口', () {
    var now = DateTime.utc(2026);
    _ManualTimer? timer;
    final windows = <RecordingPerformanceWindow>[];
    final gate = SentryRecordingTelemetryGate(
      timerFactory: (duration, callback) {
        expect(duration, const Duration(seconds: 60));
        return timer = _ManualTimer(callback);
      },
      emit: windows.add,
      now: () => now,
    );

    gate.configure(enabled: true, performanceSampled: true);
    gate.setRecordingActive(true);
    gate
      ..observePcmWrite(
        latency: const Duration(milliseconds: 2),
        pendingChunks: 1,
      )
      ..observePcmWrite(
        latency: const Duration(milliseconds: 6),
        pendingChunks: 4,
      )
      ..observePreview(queuedAudioMs: 2000, droppedWindows: 0)
      ..observePreview(queuedAudioMs: 9000, droppedWindows: 3)
      ..recordInterruption()
      ..recordRecovery();
    now = now.add(const Duration(seconds: 60));
    timer!.fire();

    expect(windows, hasLength(1));
    expect(windows.single.pcmWriteLatencyMs, 4);
    expect(windows.single.writeBacklog, 4);
    expect(windows.single.previewQueueMs, 9000);
    expect(windows.single.droppedPreviewWindows, 3);
    expect(windows.single.interruptions, 1);
    expect(windows.single.recoveries, 1);
    expect(windows.single.duration, const Duration(seconds: 60));
  });

  test('关闭诊断立即丢弃当前窗口且重新开启不回填', () {
    var now = DateTime.utc(2026);
    final timers = <_ManualTimer>[];
    final windows = <RecordingPerformanceWindow>[];
    final gate = SentryRecordingTelemetryGate(
      timerFactory: (_, callback) {
        final timer = _ManualTimer(callback);
        timers.add(timer);
        return timer;
      },
      emit: windows.add,
      now: () => now,
    );

    gate.configure(enabled: true, performanceSampled: true);
    gate.setRecordingActive(true);
    gate
      ..observePreview(queuedAudioMs: 1000, droppedWindows: 0)
      ..observePreview(queuedAudioMs: 2000, droppedWindows: 2);
    gate.configure(enabled: false, performanceSampled: false);
    expect(timers.single.isActive, isFalse);

    gate.observePreview(queuedAudioMs: 5000, droppedWindows: 7);
    gate.configure(enabled: true, performanceSampled: true);
    gate
      ..observePreview(queuedAudioMs: 1000, droppedWindows: 7)
      ..observePreview(queuedAudioMs: 2000, droppedWindows: 8);
    now = now.add(const Duration(seconds: 60));
    timers.last.fire();

    expect(windows, hasLength(1));
    expect(windows.single.droppedPreviewWindows, 1);
    expect(windows.single.previewQueueMs, 2000);
  });

  test('未抽样时不创建窗口，Metrics 发送异常也不逃逸 Timer', () {
    _ManualTimer? timer;
    final gate = SentryRecordingTelemetryGate(
      timerFactory: (_, callback) => timer = _ManualTimer(callback),
      emit: (_) => throw StateError('configured metrics failure'),
    );

    gate.configure(enabled: true, performanceSampled: false);
    gate.setRecordingActive(true);
    expect(timer, isNull);

    gate.configure(enabled: true, performanceSampled: true);
    expect(() => timer!.fire(), returnsNormally);
  });
}

final class _ManualTimer implements Timer {
  _ManualTimer(this._callback);

  final void Function(Timer timer) _callback;
  bool _active = true;
  int _tick = 0;

  void fire() {
    if (!_active) {
      return;
    }
    _tick++;
    _callback(this);
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}
