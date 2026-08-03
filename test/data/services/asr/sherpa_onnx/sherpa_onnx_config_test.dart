import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_adapter.dart';

void main() {
  test('SenseVoice 配置可跨 isolate 且固定 auto 与 ITN', () {
    final config = SherpaOnnxRecognizerConfig.senseVoice(
      modelId: 'sense-voice',
      modelVersion: '2024-07-17',
      modelPath: '/models/sense/model.int8.onnx',
      tokensPath: '/models/sense/tokens.txt',
    );

    final restored = SherpaOnnxRecognizerConfig.fromMessage(config.toMessage());

    expect(restored.kind, SherpaOnnxRecognizerKind.senseVoice);
    expect(restored.language, 'auto');
    expect(restored.useInverseTextNormalization, isTrue);
    expect(restored.modelPath, endsWith('model.int8.onnx'));
    expect(restored.tokensPath, endsWith('tokens.txt'));
  });

  test('拒绝空模型路径、语言和非正线程数', () {
    expect(
      () => SherpaOnnxRecognizerConfig.senseVoice(
        modelId: 'sense-voice',
        modelVersion: '1',
        modelPath: '',
        tokensPath: '/tokens.txt',
      ),
      throwsArgumentError,
    );
    expect(
      () => SherpaOnnxRecognizerConfig.senseVoice(
        modelId: 'sense-voice',
        modelVersion: '1',
        modelPath: '/model.onnx',
        tokensPath: '/tokens.txt',
        language: '',
        numThreads: 0,
      ),
      throwsArgumentError,
    );
  });
}
