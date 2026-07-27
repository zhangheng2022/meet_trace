import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/vad/silero_vad_segmenter.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

void main() {
  test('官方配置固定 16 kHz、512 样本窗口和 15 秒上限', () async {
    final directory = await Directory.systemTemp.createTemp('meettrace-vad-');
    final model = File('${directory.path}${Platform.pathSeparator}silero.onnx');
    await model.writeAsBytes(const [1]);
    sherpa.VadModelConfig? capturedConfig;
    double? capturedBufferSeconds;
    final runtime = _FakeVadRuntime([]);

    final segmenter = SileroVadSegmenter.official(
      modelPath: model.path,
      runtimeFactory:
          ({
            required sherpa.VadModelConfig config,
            required double bufferSizeInSeconds,
          }) {
            capturedConfig = config;
            capturedBufferSeconds = bufferSizeInSeconds;
            return runtime;
          },
    );

    expect(capturedConfig?.sampleRate, 16000);
    expect(capturedConfig?.numThreads, 1);
    expect(capturedConfig?.provider, 'cpu');
    expect(capturedConfig?.sileroVad.model, model.path);
    expect(capturedConfig?.sileroVad.windowSize, 512);
    expect(capturedConfig?.sileroVad.maxSpeechDuration, 15);
    expect(capturedBufferSeconds, 20);
    segmenter.dispose();
    await directory.delete(recursive: true);
  });

  test('把官方 VAD 局部样本位置映射到统一全局时间轴', () {
    final runtime = _FakeVadRuntime([
      sherpa.SpeechSegment(samples: Float32List(1600), start: 320),
    ]);
    final segmenter = SileroVadSegmenter.fromRuntime(runtime);

    segmenter.reset(nextStartSample: 16000);
    final segments = segmenter.accept(Float32List(512));

    expect(segments.single.startSample, 16320);
    expect(segments.single.endSample, 17920);
    expect(runtime.acceptedSampleCounts, [512]);
    expect(runtime.resetCalls, 1);
    segmenter.dispose();
    expect(runtime.freeCalls, 1);
  });

  test('flush 排空尾部语音且重复释放安全', () {
    final runtime = _FakeVadRuntime([]);
    final segmenter = SileroVadSegmenter.fromRuntime(runtime);
    runtime.pending.add(
      sherpa.SpeechSegment(samples: Float32List(800), start: 100),
    );

    final segments = segmenter.flush();

    expect(segments.single, isA<Object>());
    expect(segments.single.startSample, 100);
    expect(runtime.flushCalls, 1);
    segmenter
      ..dispose()
      ..dispose();
    expect(runtime.freeCalls, 1);
  });
}

final class _FakeVadRuntime implements SherpaOnnxVadRuntime {
  _FakeVadRuntime(Iterable<sherpa.SpeechSegment> segments)
    : pending = List.of(segments);

  final List<sherpa.SpeechSegment> pending;
  final List<int> acceptedSampleCounts = [];
  int resetCalls = 0;
  int flushCalls = 0;
  int freeCalls = 0;

  @override
  void acceptWaveform(Float32List samples) {
    acceptedSampleCounts.add(samples.length);
  }

  @override
  bool get isEmpty => pending.isEmpty;

  @override
  sherpa.SpeechSegment get front => pending.first;

  @override
  void pop() {
    pending.removeAt(0);
  }

  @override
  void flush() {
    flushCalls++;
  }

  @override
  void reset() {
    resetCalls++;
  }

  @override
  void free() {
    freeCalls++;
  }
}
