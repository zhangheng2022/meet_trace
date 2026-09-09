import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/recording_ports.dart';
import 'package:meettrace/domain/models/recording.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/ports/asr_preview_session.dart';

import '../../../support/recording_fakes.dart';

void main() {
  test('暂停 flush 先交付全部已提交尾块，再通知 ASR 结束语音', () async {
    final gate = Completer<void>();
    final sink = _FlushablePreview(gate);
    final dispatcher = RecordingPreviewDispatcher(sink);
    dispatcher.offer(_chunk(0));
    dispatcher.offer(_chunk(2));
    final flushing = dispatcher.flush();
    expect(sink.calls, ['audio:0']);
    gate.complete();
    await flushing;
    expect(sink.calls, ['audio:0', 'audio:2', 'flush']);
    dispatcher.close();
  });

  test('暂停交付超时有界返回，恢复后不会迟到 flush 新语音', () async {
    final gate = Completer<void>();
    final sink = _FlushablePreview(gate);
    final dispatcher = RecordingPreviewDispatcher(sink);
    dispatcher.offer(_chunk(0));
    final watch = Stopwatch()..start();
    await dispatcher.flush(timeout: const Duration(milliseconds: 20));
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 200)));
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(sink.calls, ['audio:0']);
    dispatcher.close();
  });

  test('尾句 flush 故障不传播至录音控制', () async {
    final sink = _FlushablePreview(null, failFlush: true);
    final dispatcher = RecordingPreviewDispatcher(sink);
    await dispatcher.flush();
    expect(sink.calls, ['flush']);
    dispatcher.close();
  });

  test('预览队列满时淘汰最旧待处理块并保留最新音频', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final receivedOffsets = <int>[];
    final dispatcher = RecordingPreviewDispatcher(
      TestRecordingPreviewSink((chunk) async {
        receivedOffsets.add(chunk.startByteOffset);
        if (receivedOffsets.length == 1) {
          firstStarted.complete();
          await releaseFirst.future;
        }
      }),
      maxPendingChunks: 2,
    );

    dispatcher.offer(_chunk(0));
    await firstStarted.future;
    dispatcher
      ..offer(_chunk(2))
      ..offer(_chunk(4))
      ..offer(_chunk(6));

    releaseFirst.complete();
    await _waitFor(() => receivedOffsets.length == 3);

    expect(receivedOffsets, [0, 4, 6]);
    expect(dispatcher.droppedChunks, 1);
    dispatcher.close();
  });

  test('零等待队列在处理期间丢弃新块', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final receivedOffsets = <int>[];
    final dispatcher = RecordingPreviewDispatcher(
      TestRecordingPreviewSink((chunk) async {
        receivedOffsets.add(chunk.startByteOffset);
        firstStarted.complete();
        await releaseFirst.future;
      }),
      maxPendingChunks: 0,
    );

    dispatcher.offer(_chunk(0));
    await firstStarted.future;
    dispatcher.offer(_chunk(2));
    releaseFirst.complete();
    await _waitFor(() => receivedOffsets.isNotEmpty);

    expect(receivedOffsets, [0]);
    expect(dispatcher.droppedChunks, 1);
    dispatcher.close();
  });
}

final class _FlushablePreview
    implements RecordingPreviewSink, AsrPreviewSession {
  _FlushablePreview(this.gate, {this.failFlush = false});
  final Completer<void>? gate;
  final bool failFlush;
  final List<String> calls = [];
  @override
  Future<void> add(RecordingPcmChunk chunk) async {
    calls.add('audio:${chunk.startByteOffset}');
    await gate?.future;
  }

  @override
  Future<void> flush() async {
    calls.add('flush');
    if (failFlush) throw StateError('flush failed');
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Stream<TranscriptEvent> get events => const Stream.empty();
  @override
  Stream<AsrPreviewMetrics> get metricsChanges => const Stream.empty();
  @override
  AsrPreviewMetrics get metrics => const AsrPreviewMetrics(
    state: AsrPreviewState.ready,
    vadSegmentCount: 0,
    queuedAudioMs: 0,
    processedPreviewWindows: 0,
    droppedPreviewWindows: 0,
    previewLagMs: 0,
  );
}

RecordingPcmChunk _chunk(int startByteOffset) {
  return RecordingPcmChunk(
    bytes: Uint8List(recordingBytesPerSample),
    startByteOffset: startByteOffset,
  );
}

Future<void> _waitFor(bool Function() condition) async {
  final timeout = Stopwatch()..start();
  while (!condition()) {
    if (timeout.elapsed > const Duration(seconds: 2)) {
      fail('等待预览队列排空超时');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
