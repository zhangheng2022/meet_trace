import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_adapter.dart';

void main() {
  test('Paraformer 与 Qwen3-ASR 配置只包含可跨 isolate 传输的应用数据', () {
    final paraformer = SherpaOnnxRecognizerConfig.paraformer(
      modelId: 'paraformer',
      modelVersion: '1',
      modelPath: '/models/paraformer/model.int8.onnx',
      tokensPath: '/models/paraformer/tokens.txt',
    );
    final qwen = SherpaOnnxRecognizerConfig.qwen3Asr(
      modelId: 'qwen',
      modelVersion: '1',
      convFrontendPath: '/models/qwen/conv_frontend.onnx',
      encoderPath: '/models/qwen/encoder.int8.onnx',
      decoderPath: '/models/qwen/decoder.int8.onnx',
      tokenizerPath: '/models/qwen/tokenizer',
    );

    expect(paraformer.kind, SherpaOnnxRecognizerKind.paraformer);
    expect(paraformer.toMessage()['modelPath'], contains('model.int8.onnx'));
    expect(qwen.kind, SherpaOnnxRecognizerKind.qwen3Asr);
    expect(qwen.toMessage()['maxNewTokens'], 512);
    expect(qwen.toMessage()['tokensPath'], '');
  });

  test('拒绝空模型身份、路径和非正线程数', () {
    expect(
      () => SherpaOnnxRecognizerConfig.paraformer(
        modelId: '',
        modelVersion: '1',
        modelPath: '/model.onnx',
        tokensPath: '/tokens.txt',
      ),
      throwsArgumentError,
    );
    expect(
      () => SherpaOnnxRecognizerConfig.paraformer(
        modelId: 'paraformer',
        modelVersion: '1',
        modelPath: '',
        tokensPath: '/tokens.txt',
      ),
      throwsArgumentError,
    );
    expect(
      () => SherpaOnnxRecognizerConfig.qwen3Asr(
        modelId: 'qwen',
        modelVersion: '1',
        convFrontendPath: '/conv.onnx',
        encoderPath: '/encoder.onnx',
        decoderPath: '/decoder.onnx',
        tokenizerPath: '/tokenizer',
        numThreads: 0,
      ),
      throwsArgumentError,
    );
  });
}
