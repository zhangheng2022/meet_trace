import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../../../domain/models/recording.dart';
import '../../../domain/models/recording_input.dart';

enum PcmAudioCaptureFailure { inputUnavailable }

final class PcmAudioCaptureException implements Exception {
  const PcmAudioCaptureException({required this.failure, this.cause});

  final PcmAudioCaptureFailure failure;
  final Object? cause;

  @override
  String toString() => 'PcmAudioCaptureException(${failure.name})';
}

abstract interface class PcmAudioCapture {
  Future<bool> hasPermission({bool request = true});

  Future<Stream<Uint8List>> start({
    LockedRecordingInput input = const LockedRecordingInput.systemDefault(),
  });

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> dispose();
}

abstract interface class RecordingStorageCapacityProvider {
  Future<int> getFreeBytes();
}

abstract interface class RecordingForegroundLifecycle {
  Future<void> start({required String meetingId});

  Future<void> setPaused(bool paused);

  Future<void> stop();
}

final class NoopRecordingForegroundLifecycle
    implements RecordingForegroundLifecycle {
  const NoopRecordingForegroundLifecycle();

  @override
  Future<void> start({required String meetingId}) async {}

  @override
  Future<void> setPaused(bool paused) async {}

  @override
  Future<void> stop() async {}
}

abstract interface class RecordingPreviewSink {
  Future<void> add(RecordingPcmChunk chunk);
}

final class DiscardingRecordingPreviewSink implements RecordingPreviewSink {
  const DiscardingRecordingPreviewSink();

  @override
  Future<void> add(RecordingPcmChunk chunk) async {}
}

final class CallbackRecordingPreviewSink implements RecordingPreviewSink {
  const CallbackRecordingPreviewSink(this.callback);

  final Future<void> Function(RecordingPcmChunk chunk) callback;

  @override
  Future<void> add(RecordingPcmChunk chunk) => callback(chunk);
}

final class RecordingPreviewDispatcher {
  RecordingPreviewDispatcher(this._sink, {this.maxPendingChunks = 4}) {
    if (maxPendingChunks < 0) {
      throw ArgumentError.value(maxPendingChunks, 'maxPendingChunks', '不能为负数');
    }
  }

  final RecordingPreviewSink _sink;
  final int maxPendingChunks;
  final Queue<RecordingPcmChunk> _pending = Queue<RecordingPcmChunk>();

  bool _draining = false;
  bool _closed = false;
  int _droppedChunks = 0;

  int get droppedChunks => _droppedChunks;

  void offer(RecordingPcmChunk chunk) {
    if (_closed) {
      _droppedChunks++;
      return;
    }
    if (_draining && _pending.length >= maxPendingChunks) {
      if (_pending.isNotEmpty) {
        _pending.removeFirst();
        _droppedChunks++;
      } else {
        // 零等待队列只能保留当前正在处理的块。
        _droppedChunks++;
        return;
      }
    }
    _pending.addLast(chunk);
    if (!_draining) {
      _draining = true;
      unawaited(_drain());
    }
  }

  void close() {
    _closed = true;
    _droppedChunks += _pending.length;
    _pending.clear();
  }

  Future<void> _drain() async {
    while (!_closed && _pending.isNotEmpty) {
      final chunk = _pending.removeFirst();
      try {
        await _sink.add(chunk);
      } on Object {
        // 预览是可重建派生数据，失败不得传播到录音写入链。
      }
    }
    _draining = false;
    if (!_closed && _pending.isNotEmpty) {
      _draining = true;
      unawaited(_drain());
    }
  }
}
