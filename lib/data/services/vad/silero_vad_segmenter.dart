import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../models/runtime/silero_vad_manifest.dart';
import '../../../domain/models/asr_preview.dart';

typedef SherpaOnnxVadRuntimeFactory = SherpaOnnxVadRuntime Function({
  required sherpa.VadModelConfig config,
  required double bufferSizeInSeconds,
});

abstract interface class VoiceActivitySegmenter {
  int get sampleRate;

  List<VadSpeechSegment> accept(Float32List samples);

  List<VadSpeechSegment> flush();

  void reset({required int nextStartSample});

  void dispose();
}

abstract interface class SherpaOnnxVadRuntime {
  void acceptWaveform(Float32List samples);

  bool get isEmpty;

  sherpa.SpeechSegment get front;

  void pop();

  void flush();

  void reset();

  void free();
}

final class OfficialSherpaOnnxVadRuntime implements SherpaOnnxVadRuntime {
  OfficialSherpaOnnxVadRuntime({
    required sherpa.VadModelConfig config,
    required double bufferSizeInSeconds,
  }) : _detector = sherpa.VoiceActivityDetector(
         config: config,
         bufferSizeInSeconds: bufferSizeInSeconds,
       );

  final sherpa.VoiceActivityDetector _detector;

  @override
  void acceptWaveform(Float32List samples) {
    _detector.acceptWaveform(samples);
  }

  @override
  bool get isEmpty => _detector.isEmpty();

  @override
  sherpa.SpeechSegment get front => _detector.front();

  @override
  void pop() => _detector.pop();

  @override
  void flush() => _detector.flush();

  @override
  void reset() => _detector.reset();

  @override
  void free() => _detector.free();
}

final class SileroVadSegmenter implements VoiceActivitySegmenter {
  factory SileroVadSegmenter.official({
    required String modelPath,
    double threshold = 0.5,
    double minimumSilenceSeconds = 0.5,
    double minimumSpeechSeconds = 0.25,
    double maximumSpeechSeconds = 15,
    double bufferSizeInSeconds = 20,
    SherpaOnnxVadRuntimeFactory runtimeFactory = _createOfficialVadRuntime,
  }) {
    if (!File(modelPath).existsSync()) {
      throw ArgumentError.value(modelPath, 'modelPath', 'Silero VAD 模型不存在');
    }
    final config = sherpa.VadModelConfig(
      sileroVad: sherpa.SileroVadModelConfig(
        model: modelPath,
        threshold: threshold,
        minSilenceDuration: minimumSilenceSeconds,
        minSpeechDuration: minimumSpeechSeconds,
        windowSize: sileroVadWindowSize,
        maxSpeechDuration: maximumSpeechSeconds,
      ),
      sampleRate: sileroVadSampleRate,
      numThreads: 1,
      provider: 'cpu',
      debug: false,
    );
    return SileroVadSegmenter.fromRuntime(
      runtimeFactory(config: config, bufferSizeInSeconds: bufferSizeInSeconds),
    );
  }

  SileroVadSegmenter.fromRuntime(this._runtime, {this.sampleRate = 16000}) {
    if (sampleRate != sileroVadSampleRate) {
      throw ArgumentError.value(
        sampleRate,
        'sampleRate',
        'Silero VAD 固定使用 16 kHz',
      );
    }
  }

  final SherpaOnnxVadRuntime _runtime;

  @override
  final int sampleRate;

  int _timelineOriginSample = 0;
  bool _disposed = false;

  @override
  List<VadSpeechSegment> accept(Float32List samples) {
    _throwIfDisposed();
    if (samples.isEmpty) {
      return const [];
    }
    _runtime.acceptWaveform(samples);
    return _drain();
  }

  @override
  List<VadSpeechSegment> flush() {
    _throwIfDisposed();
    _runtime.flush();
    return _drain();
  }

  @override
  void reset({required int nextStartSample}) {
    _throwIfDisposed();
    if (nextStartSample < 0) {
      throw ArgumentError.value(nextStartSample, 'nextStartSample', '不能为负数');
    }
    _runtime.reset();
    _timelineOriginSample = nextStartSample;
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _runtime.free();
  }

  List<VadSpeechSegment> _drain() {
    final segments = <VadSpeechSegment>[];
    while (!_runtime.isEmpty) {
      final segment = _runtime.front;
      _runtime.pop();
      if (segment.samples.isEmpty || segment.start < 0) {
        continue;
      }
      final startSample = _timelineOriginSample + segment.start;
      segments.add(
        VadSpeechSegment(
          startSample: startSample,
          endSample: startSample + segment.samples.length,
        ),
      );
    }
    return List.unmodifiable(segments);
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('Silero VAD 已释放');
    }
  }
}

SherpaOnnxVadRuntime _createOfficialVadRuntime({
  required sherpa.VadModelConfig config,
  required double bufferSizeInSeconds,
}) {
  return OfficialSherpaOnnxVadRuntime(
    config: config,
    bufferSizeInSeconds: bufferSizeInSeconds,
  );
}
