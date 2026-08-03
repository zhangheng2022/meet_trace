import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/recording_ports.dart';
import 'package:meettrace/domain/models/recording.dart';

void main() {
  test('预览队列满时淘汰最旧待处理块并保留最新音频', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final receivedOffsets = <int>[];
    final dispatcher = RecordingPreviewDispatcher(
      CallbackRecordingPreviewSink((chunk) async {
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
      CallbackRecordingPreviewSink((chunk) async {
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
