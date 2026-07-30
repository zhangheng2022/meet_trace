import 'dart:math' as math;
import 'dart:typed_data';

const recordingDiagnosticsSampleRate = 16000;
const recordingDiagnosticsChannelCount = 1;
const recordingDiagnosticsBitsPerSample = 16;

final class RecordingPcmDiagnosticsSnapshot {
  const RecordingPcmDiagnosticsSnapshot({
    required this.chunkCount,
    required this.totalBytes,
    required this.sampleCount,
    required this.peakNormalized,
    required this.rmsNormalized,
    required this.dcOffsetNormalized,
    required this.clippedSampleCount,
  });

  final int chunkCount;
  final int totalBytes;
  final int sampleCount;
  final double peakNormalized;
  final double rmsNormalized;
  final double dcOffsetNormalized;
  final int clippedSampleCount;

  Duration get duration => Duration(
    microseconds:
        sampleCount *
        Duration.microsecondsPerSecond ~/
        recordingDiagnosticsSampleRate,
  );

  double get clippingRatio =>
      sampleCount == 0 ? 0 : clippedSampleCount / sampleCount;

  Map<String, Object> toJson() => {
    'sampleRate': recordingDiagnosticsSampleRate,
    'channelCount': recordingDiagnosticsChannelCount,
    'bitsPerSample': recordingDiagnosticsBitsPerSample,
    'chunkCount': chunkCount,
    'totalBytes': totalBytes,
    'sampleCount': sampleCount,
    'durationMicros': duration.inMicroseconds,
    'peakNormalized': peakNormalized,
    'rmsNormalized': rmsNormalized,
    'dcOffsetNormalized': dcOffsetNormalized,
    'clippedSampleCount': clippedSampleCount,
    'clippingRatio': clippingRatio,
  };
}

/// 只累计 PCM 统计值，不保留音频块或样本内容。
final class RecordingPcmDiagnostics {
  int _nextByteOffset = 0;
  int _chunkCount = 0;
  int _totalBytes = 0;
  int _sampleCount = 0;
  int _peakAbsolute = 0;
  double _sum = 0;
  double _sumSquares = 0;
  int _clippedSampleCount = 0;

  RecordingPcmDiagnosticsSnapshot get snapshot {
    final count = _sampleCount;
    return RecordingPcmDiagnosticsSnapshot(
      chunkCount: _chunkCount,
      totalBytes: _totalBytes,
      sampleCount: count,
      peakNormalized: _peakAbsolute / 32768,
      rmsNormalized: count == 0 ? 0 : math.sqrt(_sumSquares / count) / 32768,
      dcOffsetNormalized: count == 0 ? 0 : _sum / count / 32768,
      clippedSampleCount: _clippedSampleCount,
    );
  }

  void addChunk(Uint8List bytes, {required int startByteOffset}) {
    if (bytes.length.isOdd) {
      throw ArgumentError.value(bytes.length, 'bytes', '必须按 PCM16 样本对齐');
    }
    if (startByteOffset != _nextByteOffset) {
      throw StateError(
        'PCM offset 不连续：期望 $_nextByteOffset，实际 $startByteOffset',
      );
    }
    if (bytes.isEmpty) {
      return;
    }

    final data = ByteData.sublistView(bytes);
    for (var offset = 0; offset < bytes.length; offset += 2) {
      final sample = data.getInt16(offset, Endian.little);
      final absolute = sample.abs();
      _peakAbsolute = math.max(_peakAbsolute, absolute);
      _sum += sample;
      _sumSquares += sample * sample;
      if (absolute >= 32767) {
        _clippedSampleCount++;
      }
    }
    _chunkCount++;
    _totalBytes += bytes.length;
    _sampleCount += bytes.length ~/ 2;
    _nextByteOffset += bytes.length;
  }

  void reset({required int nextByteOffset}) {
    if (nextByteOffset < 0 || nextByteOffset.isOdd) {
      throw ArgumentError.value(nextByteOffset, 'nextByteOffset', '必须是非负偶数');
    }
    _nextByteOffset = nextByteOffset;
    _chunkCount = 0;
    _totalBytes = 0;
    _sampleCount = 0;
    _peakAbsolute = 0;
    _sum = 0;
    _sumSquares = 0;
    _clippedSampleCount = 0;
  }
}
