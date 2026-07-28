import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../../../domain/models/recording.dart';

abstract interface class PcmAudioCapture {
  Future<bool> hasPermission({bool request = true});

  Future<Stream<Uint8List>> start();

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

/// 将同一持久化音频块分发给互相隔离的派生消费者。
final class FanOutRecordingPreviewSink implements RecordingPreviewSink {
  FanOutRecordingPreviewSink(Iterable<RecordingPreviewSink> sinks)
    : _sinks = List.unmodifiable(sinks);

  final List<RecordingPreviewSink> _sinks;

  @override
  Future<void> add(RecordingPcmChunk chunk) async {
    for (final sink in _sinks) {
      try {
        await sink.add(chunk);
      } on Object {
        // 单个派生消费者失败不得阻断其他消费者或事实录音。
      }
    }
  }
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
      _droppedChunks++;
      return;
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
