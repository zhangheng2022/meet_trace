import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/vad/whisper_vad_segmenter.dart';
import 'package:meettrace_whisper_native/meettrace_whisper_native.dart';

void main() {
  test('不同输入 chunk 边界产生相同的全局语音区间', () async {
    final audio = Float32List(12 * whisperVadSampleRate);
    audio.fillRange(whisperVadSampleRate, 3 * whisperVadSampleRate, 0.8);
    audio.fillRange(6 * whisperVadSampleRate, 9 * whisperVadSampleRate, 0.8);

    final oneSecond = await _run(audio, chunkSamples: whisperVadSampleRate);
    final irregular = await _run(audio, chunkSamples: 7311);

    expect(
      oneSecond.map((segment) => (segment.startSample, segment.endSample)),
      irregular.map((segment) => (segment.startSample, segment.endSample)),
    );
    expect(
      oneSecond.map((segment) => (segment.startSample, segment.endSample)),
      [
        (whisperVadSampleRate, 3 * whisperVadSampleRate),
        (6 * whisperVadSampleRate, 9 * whisperVadSampleRate),
      ],
    );
  });

  test('纯静音不会生成最终片段', () async {
    final segmenter = _segmenter();

    expect(
      await segmenter.accept(Float32List(4 * whisperVadSampleRate)),
      isEmpty,
    );
    expect(await segmenter.flush(), isEmpty);

    await segmenter.dispose();
  });

  test('时间轴中断后从 reset 的全局样本位置重新开始', () async {
    final segmenter = _segmenter();
    await segmenter.accept(Float32List(2 * whisperVadSampleRate));
    await segmenter.reset(nextStartSample: 8 * whisperVadSampleRate);
    final speech = Float32List(2 * whisperVadSampleRate)
      ..fillRange(0, 2 * whisperVadSampleRate, 0.8);

    await segmenter.accept(speech);
    final segments = await segmenter.flush();

    expect(
      segments.map((segment) => (segment.startSample, segment.endSample)),
      [(8 * whisperVadSampleRate, 10 * whisperVadSampleRate)],
    );
    await segmenter.dispose();
  });

  test('连续语音只在固定全局采样点运行 VAD', () async {
    final factory = _CountingVadWorkerFactory();
    final segmenter = WhisperVadSegmenter(
      modelPath: 'fake-vad.bin',
      workerFactory: factory,
      analysisInterval: const Duration(seconds: 1),
      stabilityMargin: const Duration(seconds: 1),
    );
    final chunk = Float32List(whisperVadSampleRate ~/ 10)
      ..fillRange(0, whisperVadSampleRate ~/ 10, 0.8);

    for (var index = 0; index < 35; index++) {
      await segmenter.accept(chunk);
    }
    await segmenter.flush();

    expect(factory.segmentCallCount, 3);
    await segmenter.dispose();
  });

  test('预览模式在持续讲话未结束时按三秒稳定窗口提前产出', () async {
    final factory = _CapturingVadWorkerFactory();
    final segmenter = WhisperVadSegmenter.preview(
      modelPath: 'fake-vad.bin',
      workerFactory: factory,
    );
    final speech = Float32List(8 * whisperVadSampleRate)
      ..fillRange(0, 8 * whisperVadSampleRate, 0.8);
    final output = <dynamic>[];

    for (
      var offset = 0;
      offset < speech.length;
      offset += whisperVadSampleRate
    ) {
      output.addAll(
        await segmenter.accept(
          Float32List.sublistView(
            speech,
            offset,
            offset + whisperVadSampleRate,
          ),
        ),
      );
    }

    expect(segmenter.config.threshold, whisperPreviewVadThreshold);
    expect(
      segmenter.config.minSpeechDurationMs,
      whisperPreviewMinimumSpeechDurationMs,
    );
    expect(segmenter.config.speechPadMs, whisperPreviewSpeechPadMs);
    expect(factory.configs.single.maxSpeechDurationSeconds, 15);
    expect(output.map((segment) => (segment.startSample, segment.endSample)), [
      (0, 3 * whisperVadSampleRate),
      (3 * whisperVadSampleRate, 6 * whisperVadSampleRate),
    ]);
    expect(
      (await segmenter.flush()).map(
        (segment) => (segment.startSample, segment.endSample),
      ),
      [(6 * whisperVadSampleRate, 8 * whisperVadSampleRate)],
    );
    await segmenter.dispose();
  });

  test('普通模式保留最终转录的默认 VAD 参数', () async {
    final segmenter = WhisperVadSegmenter(
      modelPath: 'fake-vad.bin',
      workerFactory: const _FakeVadWorkerFactory(),
    );

    expect(segmenter.config.threshold, 0.5);
    expect(segmenter.config.minSpeechDurationMs, 250);
    expect(segmenter.config.speechPadMs, 30);

    await segmenter.dispose();
  });
}

Future<List<dynamic>> _run(
  Float32List audio, {
  required int chunkSamples,
}) async {
  final segmenter = _segmenter();
  final output = <dynamic>[];
  for (var offset = 0; offset < audio.length; offset += chunkSamples) {
    final end = (offset + chunkSamples).clamp(0, audio.length);
    output.addAll(
      await segmenter.accept(Float32List.fromList(audio.sublist(offset, end))),
    );
  }
  output.addAll(await segmenter.flush());
  await segmenter.dispose();
  return output;
}

WhisperVadSegmenter _segmenter() {
  return WhisperVadSegmenter(
    modelPath: 'fake-vad.bin',
    workerFactory: const _FakeVadWorkerFactory(),
    analysisInterval: const Duration(seconds: 1),
    stabilityMargin: const Duration(seconds: 1),
  );
}

final class _FakeVadWorkerFactory implements WhisperVadWorkerFactory {
  const _FakeVadWorkerFactory();

  @override
  Future<WhisperVadWorker> create(WhisperVadConfig config) async {
    return _FakeVadWorker();
  }
}

final class _CountingVadWorkerFactory implements WhisperVadWorkerFactory {
  int segmentCallCount = 0;

  @override
  Future<WhisperVadWorker> create(WhisperVadConfig config) async {
    return _FakeVadWorker(onSegment: () => segmentCallCount++);
  }
}

final class _CapturingVadWorkerFactory implements WhisperVadWorkerFactory {
  final List<WhisperVadConfig> configs = [];

  @override
  Future<WhisperVadWorker> create(WhisperVadConfig config) async {
    configs.add(config);
    return _FakeVadWorker();
  }
}

final class _FakeVadWorker implements WhisperVadWorker {
  _FakeVadWorker({this.onSegment});

  final void Function()? onSegment;

  @override
  Future<List<WhisperVadNativeSegment>> segment(Float32List samples) async {
    onSegment?.call();
    final output = <WhisperVadNativeSegment>[];
    int? start;
    for (var index = 0; index < samples.length; index++) {
      final speech = samples[index].abs() >= 0.5;
      if (speech && start == null) {
        start = index;
      } else if (!speech && start != null) {
        output.add(
          WhisperVadNativeSegment(startSample: start, endSample: index),
        );
        start = null;
      }
    }
    if (start != null) {
      output.add(
        WhisperVadNativeSegment(startSample: start, endSample: samples.length),
      );
    }
    return output;
  }

  @override
  Future<void> dispose() async {}
}
