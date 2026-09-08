import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/remote/remote_asr_preview_session.dart';
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
      expect(engine.flushes, 1);
      expect(preview.metrics.vadSegmentCount, 0);
    },
  );

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
      await preview.add(chunk(6400)).timeout(const Duration(milliseconds: 100));
      expect(preview.metrics.state, AsrPreviewState.recordingOnly);
      expect(preview.metrics.queuedAudioMs, 0);
      expect(preview.metrics.lastErrorCode, 'asr.remote.backlog_exceeded');
      expect(engine.cancelled, isTrue);
      ready.complete();
      await initialization;
      expect(engine.samples, isEmpty);
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
}

final class _PreviewEngine implements AsrEngine, AsrPreviewControl {
  _PreviewEngine({this.ready, this.accepted});
  final Future<void>? ready;
  final Future<void>? accepted;
  int initialized = 0;
  int flushes = 0;
  bool cancelled = false;
  final samples = <(int, Float32List)>[];
  @override
  Stream<TranscriptEvent> get events => const Stream.empty();
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
    expect(sampleRate, 16000);
    samples.add((startMs, data));
    await accepted;
  }

  @override
  Future<void> flushPreview() async {
    flushes++;
  }

  @override
  void cancel() {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
