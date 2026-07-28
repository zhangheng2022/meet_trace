import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../domain/models/recording.dart';
import 'recording_ports.dart';

const defaultRecordingAudioLevelFrame = Duration(milliseconds: 100);
const defaultRecordingAudioLevelFloorDbfs = -60.0;

/// 从持久化后的 PCM16 数据计算轻量级 RMS 包络。
///
/// 该服务运行在可丢弃预览链路中。输入不连续时会丢弃未完成窗口并从新块重新
/// 对齐，避免把积压或丢帧误画成连续事实。
final class PcmAudioLevelMeter implements RecordingPreviewSink {
  PcmAudioLevelMeter({
    this.frameDuration = defaultRecordingAudioLevelFrame,
    this.floorDbfs = defaultRecordingAudioLevelFloorDbfs,
  }) : _samplesPerFrame =
           recordingSampleRate *
           frameDuration.inMicroseconds ~/
           Duration.microsecondsPerSecond {
    if (frameDuration <= Duration.zero || _samplesPerFrame <= 0) {
      throw ArgumentError.value(frameDuration, 'frameDuration', '必须大于 0');
    }
    if (floorDbfs >= 0) {
      throw ArgumentError.value(floorDbfs, 'floorDbfs', '必须小于 0');
    }
  }

  final Duration frameDuration;
  final double floorDbfs;
  final int _samplesPerFrame;
  final StreamController<RecordingAudioLevel> _changes =
      StreamController<RecordingAudioLevel>.broadcast(sync: true);

  int? _expectedNextByteOffset;
  int _windowSamples = 0;
  double _sumSquares = 0;
  bool _disposed = false;

  Stream<RecordingAudioLevel> get changes => _changes.stream;

  @override
  Future<void> add(RecordingPcmChunk chunk) {
    if (_disposed) {
      return Future<void>.value();
    }
    if (_expectedNextByteOffset case final expected?
        when expected != chunk.startByteOffset) {
      _resetWindow();
    }

    final data = ByteData.sublistView(chunk.bytes);
    for (var byteOffset = 0; byteOffset < chunk.bytes.length; byteOffset += 2) {
      final sample = data.getInt16(byteOffset, Endian.little) / 32768.0;
      _sumSquares += sample * sample;
      _windowSamples++;
      if (_windowSamples == _samplesPerFrame) {
        final capturedBytes = chunk.startByteOffset + byteOffset + 2;
        _emit(capturedBytes);
        _resetWindow();
      }
    }
    _expectedNextByteOffset = chunk.endByteOffset;
    return Future<void>.value();
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _resetWindow();
    await _changes.close();
  }

  void _emit(int capturedBytes) {
    if (_changes.isClosed) {
      return;
    }
    final rms = math.sqrt(_sumSquares / _windowSamples);
    final dbfs = rms == 0
        ? floorDbfs
        : (20 * math.log(rms) / math.ln10).clamp(floorDbfs, 0.0);
    final normalized = ((dbfs - floorDbfs) / -floorDbfs).clamp(0.0, 1.0);
    _changes.add(
      RecordingAudioLevel(
        level: normalized,
        capturedThrough: recordingDurationForBytes(capturedBytes),
      ),
    );
  }

  void _resetWindow() {
    _windowSamples = 0;
    _sumSquares = 0;
  }
}
