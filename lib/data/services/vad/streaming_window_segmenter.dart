import 'dart:typed_data';

import '../../../domain/models/asr_preview.dart';
import 'voice_activity_segmenter.dart';

const streamingWindowSampleRate = 16000;

/// 为 whisper.cpp 实时预览生成固定长度的连续音频窗口。
///
/// 这不是语音活动检测器。它有意不在录音线程执行模型推理，静音过滤交给
/// whisper.cpp；这样预览积压最多影响临时文本，不会影响事实 PCM 写入。
final class StreamingWindowSegmenter implements VoiceActivitySegmenter {
  StreamingWindowSegmenter({
    this.sampleRate = streamingWindowSampleRate,
    this.windowDuration = const Duration(seconds: 2),
    this.overlap = const Duration(milliseconds: 500),
    this.minimumFlushDuration = const Duration(milliseconds: 500),
  }) {
    if (sampleRate != streamingWindowSampleRate) {
      throw ArgumentError.value(sampleRate, 'sampleRate', '固定使用 16 kHz');
    }
    _windowSamples = _samplesFor(windowDuration);
    _overlapSamples = _samplesFor(overlap);
    _minimumFlushSamples = _samplesFor(minimumFlushDuration);
    if (_windowSamples <= 0 ||
        _overlapSamples < 0 ||
        _overlapSamples >= _windowSamples ||
        _minimumFlushSamples <= 0 ||
        _minimumFlushSamples > _windowSamples) {
      throw ArgumentError('流式窗口参数无效');
    }
  }

  @override
  final int sampleRate;
  final Duration windowDuration;
  final Duration overlap;
  final Duration minimumFlushDuration;

  late final int _windowSamples;
  late final int _overlapSamples;
  late final int _minimumFlushSamples;
  int _availableEndSample = 0;
  int _nextWindowStartSample = 0;
  bool _disposed = false;

  @override
  List<VadSpeechSegment> accept(Float32List samples) {
    _throwIfDisposed();
    if (samples.isEmpty) {
      return const [];
    }
    _availableEndSample += samples.length;
    final segments = <VadSpeechSegment>[];
    while (_availableEndSample - _nextWindowStartSample >= _windowSamples) {
      final endSample = _nextWindowStartSample + _windowSamples;
      segments.add(
        VadSpeechSegment(
          startSample: _nextWindowStartSample,
          endSample: endSample,
        ),
      );
      _nextWindowStartSample = endSample - _overlapSamples;
    }
    return List.unmodifiable(segments);
  }

  @override
  List<VadSpeechSegment> flush() {
    _throwIfDisposed();
    final remaining = _availableEndSample - _nextWindowStartSample;
    if (remaining < _minimumFlushSamples) {
      _nextWindowStartSample = _availableEndSample;
      return const [];
    }
    final segment = VadSpeechSegment(
      startSample: _nextWindowStartSample,
      endSample: _availableEndSample,
    );
    _nextWindowStartSample = _availableEndSample;
    return [segment];
  }

  @override
  void reset({required int nextStartSample}) {
    _throwIfDisposed();
    if (nextStartSample < 0) {
      throw ArgumentError.value(nextStartSample, 'nextStartSample', '不能为负数');
    }
    _availableEndSample = nextStartSample;
    _nextWindowStartSample = nextStartSample;
  }

  @override
  void dispose() {
    _disposed = true;
  }

  int _samplesFor(Duration duration) {
    return duration.inMicroseconds *
        sampleRate ~/
        Duration.microsecondsPerSecond;
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('流式窗口分段器已释放');
    }
  }
}
