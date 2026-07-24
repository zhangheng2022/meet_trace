import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/asr/spike/asr_spike_models.dart';
import 'package:meetily_ai/data/services/asr/spike/sherpa_onnx_spike_runner.dart';

void main() {
  group('AsrSpikeModelSpec', () {
    test('标准模型只要求 Paraformer INT8 模型与 tokens', () {
      final spec = AsrSpikeModelSpec.paraformer(rootPath: '/models/paraformer');

      expect(spec.modelId, paraformerSpikeModelId);
      expect(spec.requiredRelativePaths, ['model.int8.onnx', 'tokens.txt']);
    });

    test('高级模型要求 Qwen3-ASR 三个 ONNX 文件和 tokenizer', () {
      final spec = AsrSpikeModelSpec.qwen(rootPath: '/models/qwen');

      expect(spec.modelId, qwenSpikeModelId);
      expect(spec.requiredRelativePaths, [
        'conv_frontend.onnx',
        'encoder.int8.onnx',
        'decoder.int8.onnx',
        'tokenizer/merges.txt',
        'tokenizer/tokenizer_config.json',
        'tokenizer/vocab.json',
      ]);
    });

    test('缺失模型文件时返回精确相对路径', () async {
      final root = await Directory.systemTemp.createTemp('meetily-spike-');
      addTearDown(() => root.delete(recursive: true));
      await File(
        '${root.path}${Platform.pathSeparator}model.int8.onnx',
      ).writeAsBytes([1]);

      final spec = AsrSpikeModelSpec.paraformer(rootPath: root.path);
      final validation = await spec.validateFiles();

      expect(validation.isValid, isFalse);
      expect(validation.missingRelativePaths, ['tokens.txt']);
    });
  });

  group('AsrSpikeMetrics', () {
    test('按推理耗时除以音频时长计算 RTF', () {
      final metrics = AsrSpikeMetrics(
        audioDuration: const Duration(minutes: 5),
        initializationDuration: const Duration(milliseconds: 800),
        firstResultDuration: const Duration(seconds: 3),
        inferenceDuration: const Duration(seconds: 75),
      );

      expect(metrics.realTimeFactor, closeTo(0.25, 0.0001));
      expect(metrics.utteranceLatencyMs, 3000);
    });
  });

  test('按窗口计数暴露局部空结果', () {
    const windows = [
      AsrSpikeWindowMetrics(
        index: 1,
        startMs: 0,
        endMs: 15000,
        inferenceDuration: Duration(milliseconds: 700),
        resultCharacterCount: 20,
      ),
      AsrSpikeWindowMetrics(
        index: 2,
        startMs: 15000,
        endMs: 30000,
        inferenceDuration: Duration(milliseconds: 600),
        resultCharacterCount: 0,
      ),
    ];
    final result = AsrSpikeRunResult(
      modelId: paraformerSpikeModelId,
      packageVersion: '1.13.4',
      nativeVersion: '1.13.4',
      nativeGitSha1: 'sha',
      nativeGitDate: 'date',
      metrics: AsrSpikeMetrics(
        audioDuration: const Duration(minutes: 5),
        initializationDuration: const Duration(seconds: 1),
        firstResultDuration: const Duration(seconds: 1),
        inferenceDuration: const Duration(seconds: 10),
      ),
      resultText: '可读',
      fileValidation: const AsrSpikeFileValidation(
        missingRelativePaths: [],
        byteSizes: {},
      ),
      repeatIndex: 1,
      peakProcessRssBytes: 100,
      windows: windows,
    );

    expect(result.totalWindowCount, 2);
    expect(result.readableWindowCount, 1);
    expect(result.emptyWindowCount, 1);
    expect(result.toJson()['windows'], [
      {
        'index': 1,
        'startMs': 0,
        'endMs': 15000,
        'inferenceDurationMs': 700,
        'resultCharacterCount': 20,
        'resultWasReadable': true,
      },
      {
        'index': 2,
        'startMs': 15000,
        'endMs': 30000,
        'inferenceDurationMs': 600,
        'resultCharacterCount': 0,
        'resultWasReadable': false,
      },
    ]);
  });

  group('SherpaOnnxSpikeRunner', () {
    test('模型文件不完整时不加载原生运行库', () async {
      final root = await Directory.systemTemp.createTemp('meetily-spike-');
      addTearDown(() => root.delete(recursive: true));
      final runner = SherpaOnnxSpikeRunner();

      await expectLater(
        runner.run(
          spec: AsrSpikeModelSpec.paraformer(rootPath: root.path),
          wavePath: '${root.path}${Platform.pathSeparator}sample.wav',
        ),
        throwsA(
          isA<AsrSpikePrerequisiteException>().having(
            (error) => error.missingRelativePaths,
            'missingRelativePaths',
            containsAll(['model.int8.onnx', 'tokens.txt']),
          ),
        ),
      );
    });
  });
}
