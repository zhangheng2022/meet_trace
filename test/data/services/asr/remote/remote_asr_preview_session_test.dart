import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/remote/remote_asr_preview_session.dart';
import 'package:meettrace/data/services/audio/recording_ports.dart';
import 'package:meettrace/domain/models/app_failure.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:meettrace/domain/models/recording.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';

void main() {
  RecordingPcmChunk chunk(int offset, {int milliseconds = 200}) =>
      RecordingPcmChunk(
        bytes: Uint8List(milliseconds * 32),
        startByteOffset: offset,
      );

  test(
    'file-only source creates no initialization or preview traffic',
    () async {
      final engine = _PreviewEngine();
      final preview = RemoteAsrPreviewSession(engine: engine, enabled: false);
      addTearDown(preview.dispose);
      await preview.initialize();
      await preview.add(chunk(0));
      await preview.flush();
      expect(engine.initialized, 0);
      expect(engine.samples, isEmpty);
      expect(preview.metrics.state, AsrPreviewState.recordingOnly);
      expect(preview.metrics.isRecognizing, isFalse);
    },
  );

  test(
    'silence and speech bytes reach realtime in order without VAD gating',
    () async {
      final engine = _PreviewEngine();
      final preview = RemoteAsrPreviewSession(engine: engine);
      addTearDown(preview.dispose);
      await preview.initialize();
      await preview.add(chunk(0));
      await preview.add(chunk(6400));
      await preview.flush();
      expect(engine.samples.map((s) => s.$1), [0, 200]);
      expect(engine.samples.map((s) => s.$2.length), [3200, 3200]);
      expect(engine.sampleRates, [16000, 16000]);
      expect(engine.flushes, 1);
      expect(preview.metrics.vadSegmentCount, 0);
    },
  );

  test(
    'pause before initialization flushes once after queued audio drains',
    () async {
      final ready = Completer<void>();
      final accepted = Completer<void>();
      final engine = _PreviewEngine(
        ready: ready.future,
        accepted: accepted.future,
      );
      final preview = RemoteAsrPreviewSession(engine: engine);
      addTearDown(preview.dispose);
      final initialization = preview.initialize();
      await preview.add(chunk(0));
      await preview.add(chunk(6400));

      await preview.flush().timeout(const Duration(milliseconds: 100));
      await preview.flush().timeout(const Duration(milliseconds: 100));
      expect(engine.samples, isEmpty);
      expect(engine.flushes, 0);

      ready.complete();
      await initialization;
      expect(engine.samples.map((s) => s.$1), [0]);
      expect(engine.flushes, 0);
      accepted.complete();
      await engine.firstFlush.future.timeout(const Duration(milliseconds: 100));
      expect(engine.samples.map((s) => s.$1), [0, 200]);
      expect(engine.flushes, 1);
      expect(preview.metrics.processedPreviewWindows, 2);
    },
  );

  test(
    'dispatcher pause before initialization preserves its flush intent',
    () async {
      final ready = Completer<void>();
      final engine = _PreviewEngine(ready: ready.future);
      final preview = RemoteAsrPreviewSession(engine: engine);
      addTearDown(preview.dispose);
      final initialization = preview.initialize();
      final dispatcher = RecordingPreviewDispatcher(preview);
      dispatcher.offer(chunk(0));
      dispatcher.offer(chunk(6400));
      await dispatcher
          .flush(timeout: const Duration(milliseconds: 10))
          .timeout(const Duration(milliseconds: 100));
      expect(engine.samples, isEmpty);
      expect(preview.metrics.queuedAudioMs, 400);
      ready.complete();
      await initialization;
      await engine.firstFlush.future.timeout(const Duration(milliseconds: 100));
      await Future<void>.delayed(Duration.zero);
      expect(engine.samples.map((s) => s.$1), [0, 200]);
      expect(engine.flushes, 1);
    },
  );

  for (final resumeAfterInitialization in [false, true]) {
    test(
      'resume ${resumeAfterInitialization ? 'during drain' : 'before initialization'} invalidates pending pause',
      () async {
        final ready = Completer<void>();
        final accepted = Completer<void>();
        final engine = _PreviewEngine(
          ready: ready.future,
          accepted: accepted.future,
        );
        final preview = RemoteAsrPreviewSession(engine: engine);
        addTearDown(preview.dispose);
        final initialization = preview.initialize();
        await preview.add(chunk(0));
        await preview.flush();
        if (resumeAfterInitialization) {
          ready.complete();
          await initialization;
        }
        await preview.add(chunk(6400));
        if (!resumeAfterInitialization) {
          ready.complete();
          await initialization;
        }
        accepted.complete();
        await Future<void>.delayed(Duration.zero);
        expect(engine.samples.map((s) => s.$1), [0, 200]);
        expect(preview.metrics.processedPreviewWindows, 2);
        expect(engine.flushes, 0);

        await preview.flush();
        expect(engine.flushes, 1);
      },
    );
  }

  test('new pause replaces a stale pause before initialization', () async {
    final ready = Completer<void>();
    final engine = _PreviewEngine(ready: ready.future);
    final preview = RemoteAsrPreviewSession(engine: engine);
    addTearDown(preview.dispose);
    final initialization = preview.initialize();
    await preview.add(chunk(0));
    await preview.flush();
    await preview.add(chunk(6400));
    await preview.flush();
    ready.complete();
    await initialization;
    await engine.firstFlush.future.timeout(const Duration(milliseconds: 100));
    expect(engine.samples.map((s) => s.$1), [0, 200]);
    expect(engine.flushes, 1);
  });

  for (final dispose in [false, true]) {
    test(
      '${dispose ? 'dispose' : 'stop'} before initialization discards the pending pause',
      () async {
        final ready = Completer<void>();
        final engine = _PreviewEngine(ready: ready.future);
        final preview = RemoteAsrPreviewSession(engine: engine);
        addTearDown(preview.dispose);
        final initialization = preview.initialize();
        await preview.add(chunk(0));
        await preview.flush();
        await (dispose ? preview.dispose() : preview.stop()).timeout(
          const Duration(milliseconds: 100),
        );
        ready.complete();
        await initialization;
        expect(engine.samples, isEmpty);
        expect(engine.flushes, 0);
        expect(engine.cancelled, isTrue);
        expect(preview.metrics.state, AsrPreviewState.disposed);
        expect(preview.metrics.queuedAudioMs, 0);
      },
    );
  }

  test(
    'stop during drain discards the deferred pause after its timeout',
    () async {
      final ready = Completer<void>();
      final accepted = Completer<void>();
      final engine = _PreviewEngine(
        ready: ready.future,
        accepted: accepted.future,
      );
      final preview = RemoteAsrPreviewSession(
        engine: engine,
        stopTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(preview.dispose);
      final initialization = preview.initialize();
      await preview.add(chunk(0));
      await preview.flush();
      ready.complete();
      await initialization;
      await preview.stop().timeout(const Duration(milliseconds: 200));
      accepted.complete();
      await Future<void>.delayed(Duration.zero);
      expect(engine.samples, hasLength(1));
      expect(engine.flushes, 0);
      expect(preview.metrics.state, AsrPreviewState.disposed);
    },
  );

  for (final code in ['asr.remote.timeout', 'asr.remote.connection_failed']) {
    test('initialization $code cancels the deferred pause', () async {
      final ready = Completer<void>();
      final engine = _PreviewEngine(ready: ready.future);
      final preview = RemoteAsrPreviewSession(engine: engine);
      addTearDown(preview.dispose);
      final initialization = preview.initialize();
      await preview.add(chunk(0));
      await preview.flush();
      ready.completeError(_failure(code));
      await initialization;
      await preview.add(chunk(6400)).timeout(const Duration(milliseconds: 100));
      await preview.flush();
      expect(engine.samples, isEmpty);
      expect(engine.flushes, 0);
      expect(engine.cancelled, isTrue);
      expect(preview.metrics.state, AsrPreviewState.recordingOnly);
      expect(preview.metrics.lastErrorCode, code);
      expect(preview.metrics.queuedAudioMs, 0);
    });
  }

  test('disconnect during drain cancels the deferred pause', () async {
    final ready = Completer<void>();
    final accepted = Completer<void>();
    final engine = _PreviewEngine(
      ready: ready.future,
      accepted: accepted.future,
    );
    final preview = RemoteAsrPreviewSession(engine: engine);
    addTearDown(preview.dispose);
    final initialization = preview.initialize();
    await preview.add(chunk(0));
    await preview.add(chunk(6400));
    await preview.flush();
    ready.complete();
    await initialization;
    final degraded = preview.metricsChanges.firstWhere(
      (metrics) => metrics.state == AsrPreviewState.recordingOnly,
    );
    engine.updates.addError(_failure('asr.remote.disconnected'));
    await degraded;
    accepted.complete();
    await Future<void>.delayed(Duration.zero);
    await preview.add(chunk(12800)).timeout(const Duration(milliseconds: 100));
    expect(engine.samples, hasLength(1));
    expect(engine.flushes, 0);
    expect(engine.cancelled, isTrue);
    expect(preview.metrics.lastErrorCode, 'asr.remote.disconnected');
    expect(preview.metrics.queuedAudioMs, 0);
  });

  test(
    'caller timeout still allows the current deferred pause to flush',
    () async {
      final ready = Completer<void>();
      final accepted = Completer<void>();
      final engine = _PreviewEngine(
        ready: ready.future,
        accepted: accepted.future,
      );
      final preview = RemoteAsrPreviewSession(engine: engine);
      addTearDown(preview.dispose);
      final initialization = preview.initialize();
      await preview.add(chunk(0));
      await preview.flush();
      ready.complete();
      await initialization;
      final flushing = preview.flush();
      await expectLater(
        flushing.timeout(const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
      expect(engine.flushes, 0);
      accepted.complete();
      await flushing;
      expect(engine.flushes, 1);
    },
  );

  test('deferred flush failure degrades only the preview', () async {
    final ready = Completer<void>();
    final flushed = Completer<void>();
    final engine = _PreviewEngine(ready: ready.future, flushed: flushed.future);
    final preview = RemoteAsrPreviewSession(engine: engine);
    addTearDown(preview.dispose);
    final initialization = preview.initialize();
    await preview.add(chunk(0));
    await preview.flush();
    ready.complete();
    await initialization;
    await engine.firstFlush.future.timeout(const Duration(milliseconds: 100));
    final degraded = preview.metricsChanges.firstWhere(
      (metrics) => metrics.state == AsrPreviewState.recordingOnly,
    );
    flushed.completeError(_failure('asr.remote.timeout'));
    await degraded;
    await preview.add(chunk(6400)).timeout(const Duration(milliseconds: 100));
    expect(engine.flushes, 1);
    expect(engine.cancelled, isTrue);
    expect(preview.metrics.lastErrorCode, 'asr.remote.timeout');
    expect(preview.metrics.isRecognizing, isFalse);
  });

  for (final failureDuringFlush in [false, true]) {
    test(
      'dispatcher timeout handles a late ${failureDuringFlush ? 'flush' : 'drain'} failure',
      () async {
        final blocked = Completer<void>();
        final engine = _PreviewEngine(
          accepted: failureDuringFlush ? null : blocked.future,
          flushed: failureDuringFlush ? blocked.future : null,
        );
        final preview = RemoteAsrPreviewSession(engine: engine);
        addTearDown(preview.dispose);
        await preview.initialize();
        final dispatcher = RecordingPreviewDispatcher(preview);
        dispatcher.offer(chunk(0));
        await dispatcher
            .flush(timeout: const Duration(milliseconds: 10))
            .timeout(const Duration(milliseconds: 100));
        expect(engine.flushes, failureDuringFlush ? 1 : 0);
        final degraded = preview.metricsChanges.firstWhere(
          (metrics) => metrics.state == AsrPreviewState.recordingOnly,
        );
        blocked.completeError(_failure('asr.remote.disconnected'));
        await degraded;
        await preview
            .add(chunk(6400))
            .timeout(const Duration(milliseconds: 100));
        expect(engine.samples, hasLength(1));
        expect(engine.cancelled, isTrue);
        expect(preview.metrics.lastErrorCode, 'asr.remote.disconnected');
      },
    );
  }

  test('a new pause during flush waits for its own queued audio', () async {
    final flushed = Completer<void>();
    final engine = _PreviewEngine(flushed: flushed.future);
    final preview = RemoteAsrPreviewSession(engine: engine);
    addTearDown(preview.dispose);
    await preview.initialize();
    await preview.add(chunk(0));
    final oldPause = preview.flush();
    await engine.firstFlush.future;
    final duplicatePause = preview.flush();
    await preview.add(chunk(6400));
    final newPause = preview.flush();
    expect(engine.samples.map((s) => s.$1), [0]);
    expect(engine.flushes, 1);
    flushed.complete();
    await Future.wait([oldPause, duplicatePause, newPause]);
    expect(engine.samples.map((s) => s.$1), [0, 200]);
    expect(engine.flushes, 2);
    expect(preview.metrics.processedPreviewWindows, 2);
  });

  test('pause at drain completion waits for the restarted flush', () async {
    final flushed = Completer<void>();
    final engine = _PreviewEngine(flushed: flushed.future);
    final preview = RemoteAsrPreviewSession(engine: engine);
    addTearDown(preview.dispose);
    var pauseFinished = false;
    Future<void>? pause;
    final subscription = preview.metricsChanges.listen((metrics) {
      if (metrics.processedPreviewWindows == 1 && pause == null) {
        pause = preview.flush().then((_) {
          pauseFinished = true;
        });
      }
    });
    addTearDown(subscription.cancel);
    await preview.initialize();
    await preview.add(chunk(0));
    await engine.firstFlush.future.timeout(const Duration(milliseconds: 100));
    await Future<void>.delayed(Duration.zero);
    expect(pauseFinished, isFalse);
    expect(engine.flushes, 1);
    flushed.complete();
    await pause;
    expect(pauseFinished, isTrue);
  });

  test(
    'hung initialization cannot block PCM delivery or grow the preview queue',
    () async {
      final ready = Completer<void>();
      final engine = _PreviewEngine(ready: ready.future);
      final preview = RemoteAsrPreviewSession(
        engine: engine,
        maximumQueuedAudioMs: 300,
      );
      addTearDown(preview.dispose);
      final initialization = preview.initialize();
      await preview.add(chunk(0)).timeout(const Duration(milliseconds: 100));
      await preview.flush().timeout(const Duration(milliseconds: 100));
      await preview.add(chunk(6400)).timeout(const Duration(milliseconds: 100));
      expect(preview.metrics.state, AsrPreviewState.recordingOnly);
      expect(preview.metrics.queuedAudioMs, 0);
      expect(preview.metrics.lastErrorCode, 'asr.remote.backlog_exceeded');
      expect(preview.metrics.isRecognizing, isFalse);
      expect(engine.cancelled, isTrue);
      ready.complete();
      await initialization;
      expect(engine.samples, isEmpty);
      expect(engine.flushes, 0);
    },
  );

  test(
    'stop is bounded even when the remote consumer does not complete',
    () async {
      final accepted = Completer<void>();
      final engine = _PreviewEngine(accepted: accepted.future);
      final preview = RemoteAsrPreviewSession(
        engine: engine,
        stopTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(preview.dispose);
      await preview.initialize();
      await preview.add(chunk(0));
      expect(engine.samples, hasLength(1));
      expect(preview.metrics.state, AsrPreviewState.ready);
      await preview.stop().timeout(const Duration(milliseconds: 200));
      expect(preview.metrics.state, AsrPreviewState.disposed);
      expect(engine.cancelled, isTrue);
      accepted.complete();
    },
  );
  test('late pause flush cannot commit audio delivered after resume', () async {
    final accepted = Completer<void>();
    final engine = _PreviewEngine(accepted: accepted.future);
    final preview = RemoteAsrPreviewSession(engine: engine);
    addTearDown(preview.dispose);
    await preview.initialize();
    await preview.add(chunk(0));
    final oldFlush = preview.flush();
    await preview.add(chunk(6400));
    accepted.complete();
    await oldFlush;
    expect(engine.flushes, 0);
    await preview.flush();
    expect(engine.flushes, 1);
  });

  test(
    'recognizing covers queued audio and all out-of-order completions',
    () async {
      final ready = Completer<void>();
      final accepted = Completer<void>();
      final engine = _PreviewEngine(
        ready: ready.future,
        accepted: accepted.future,
      );
      final preview = RemoteAsrPreviewSession(engine: engine);
      addTearDown(preview.dispose);
      expect(preview.metrics.isRecognizing, isFalse);
      final initialization = preview.initialize();
      await preview.add(chunk(0));
      expect(preview.metrics.queuedAudioMs, 200);
      expect(preview.metrics.isRecognizing, isTrue);
      ready.complete();
      await initialization;
      expect(preview.metrics.queuedAudioMs, 0);
      expect(preview.metrics.isRecognizing, isTrue);
      accepted.complete();
      await preview.flush();
      await preview.add(chunk(6400));
      await preview.add(chunk(12800));
      await preview.flush();
      expect(preview.metrics.isRecognizing, isTrue);

      Future<void> completeWindow(
        int start,
        int end, {
        String text = '',
      }) async {
        final changed = preview.metricsChanges.first;
        engine.updates.add(
          TranscriptSegmentEvent(
            segmentId: 'window-$start',
            startMs: start,
            endMs: end,
            text: text,
            modelId: 'custom',
            modelVersion: 'unreported',
            isFinalForWindow: true,
          ),
        );
        await changed;
      }

      await completeWindow(400, 600, text: 'last');
      expect(preview.metrics.isRecognizing, isTrue);
      expect(preview.metrics.previewLagMs, 600);
      await completeWindow(0, 200, text: 'first');
      expect(preview.metrics.isRecognizing, isTrue);
      expect(preview.metrics.previewLagMs, 400);
      await completeWindow(200, 400);
      expect(preview.metrics.isRecognizing, isFalse);
      expect(preview.metrics.previewLagMs, 0);
      await completeWindow(400, 600, text: 'duplicate');
      expect(preview.metrics.isRecognizing, isFalse);
      await preview.add(chunk(19200));
      expect(preview.metrics.isRecognizing, isTrue);
      await preview.stop();
      expect(preview.metrics.isRecognizing, isFalse);
    },
  );
}

final class _PreviewEngine implements AsrEngine, AsrPreviewControl {
  _PreviewEngine({this.ready, this.accepted, this.flushed});
  final Future<void>? ready;
  final Future<void>? accepted;
  final Future<void>? flushed;
  final firstFlush = Completer<void>();
  int initialized = 0;
  int flushes = 0;
  bool cancelled = false;
  final samples = <(int, Float32List)>[];
  final sampleRates = <int>[];
  final updates = StreamController<TranscriptEvent>.broadcast();
  @override
  Stream<TranscriptEvent> get events => updates.stream;
  @override
  Future<void> initialize() async {
    initialized++;
    await ready;
  }

  @override
  Future<void> acceptAudio(
    Float32List data, {
    required int sampleRate,
    required int startMs,
  }) async {
    sampleRates.add(sampleRate);
    samples.add((startMs, data));
    await accepted;
  }

  @override
  Future<void> flushPreview() async {
    flushes++;
    if (!firstFlush.isCompleted) firstFlush.complete();
    await flushed;
  }

  @override
  void cancel() {
    cancelled = true;
  }

  @override
  Future<void> dispose() => updates.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AsrEngineException _failure(String code) => AsrEngineException(
  AppFailure(
    code: code,
    stage: FailureStage.asrInference,
    recoverability: FailureRecoverability.retryable,
    userAction: FailureUserAction.checkNetwork,
  ),
);
