import 'dart:typed_data';

/// 从事实音频派生 24 kHz PCM；相位与末样本跨输入块保留。
final class Pcm16To24Resampler {
  int _inputCount = 0;
  int _outputCount = 0;
  double _last = 0;
  bool _finished = false;

  Uint8List add(Float32List samples) {
    if (_finished) throw StateError('resampler.finished');
    if (samples.isEmpty) return Uint8List(0);
    if (samples.any((value) => !value.isFinite)) {
      throw ArgumentError('resampler.invalid_sample');
    }
    final firstIndex = _inputCount;
    final lastIndex = firstIndex + samples.length - 1;
    final values = <int>[];
    double sampleAt(int index) =>
        index < firstIndex ? _last : samples[index - firstIndex];

    // ponytail: 线性插值保留跨块相位；若声学对照显示成像频率影响，再换带限滤波。
    while (true) {
      final position = _outputCount * 2;
      final left = position ~/ 3;
      final remainder = position % 3;
      if (left > lastIndex || (left == lastIndex && remainder != 0)) break;
      final a = sampleAt(left);
      final value = remainder == 0
          ? a
          : a + (sampleAt(left + 1) - a) * remainder / 3;
      values.add(_quantize(value));
      _outputCount++;
    }
    _inputCount += samples.length;
    _last = samples.last;
    return _encode(values);
  }

  Uint8List finish() {
    if (_finished) return Uint8List(0);
    _finished = true;
    return flushBoundary();
  }

  /// 暂停是一个明确的音频边界；复制末样本收齐尾部，仍保留全局相位。
  Uint8List flushBoundary() {
    final count = (_inputCount * 3 + 1) ~/ 2 - _outputCount;
    _outputCount += count;
    return _encode(List<int>.filled(count, _quantize(_last)));
  }
}

Float32List decodeRemotePcm16(Uint8List bytes) {
  if (bytes.length.isOdd) throw ArgumentError('pcm.incomplete_sample');
  final data = ByteData.sublistView(bytes);
  return Float32List.fromList([
    for (var index = 0; index < bytes.length; index += 2)
      data.getInt16(index, Endian.little) / 32768,
  ]);
}

int _quantize(double sample) =>
    (sample.clamp(-1.0, 1.0) * 32768).round().clamp(-32768, 32767);

Uint8List _encode(List<int> samples) {
  final result = Uint8List(samples.length * 2);
  final data = ByteData.sublistView(result);
  for (var index = 0; index < samples.length; index++) {
    data.setInt16(index * 2, samples[index], Endian.little);
  }
  return result;
}
