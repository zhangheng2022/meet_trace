import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/asr/spike/asr_spike_models.dart';
import 'package:meetily_ai/data/services/asr/spike/sherpa_onnx_spike_config.dart';

void main() {
  group('SherpaOnnxSpikeConfigFactory', () {
    test('生成 Paraformer 官方离线识别配置', () {
      final spec = AsrSpikeModelSpec.paraformer(rootPath: '/models/paraformer');

      final config = SherpaOnnxSpikeConfigFactory.create(spec);

      expect(
        config.model.paraformer.model,
        '/models/paraformer/model.int8.onnx',
      );
      expect(config.model.tokens, '/models/paraformer/tokens.txt');
      expect(config.model.numThreads, 2);
      expect(config.model.debug, isFalse);
      expect(config.model.qwen3Asr.encoder, isEmpty);
    });

    test('生成 Qwen3-ASR 官方离线识别配置', () {
      final spec = AsrSpikeModelSpec.qwen(rootPath: '/models/qwen');

      final config = SherpaOnnxSpikeConfigFactory.create(spec);

      expect(
        config.model.qwen3Asr.convFrontend,
        '/models/qwen/conv_frontend.onnx',
      );
      expect(config.model.qwen3Asr.encoder, '/models/qwen/encoder.int8.onnx');
      expect(config.model.qwen3Asr.decoder, '/models/qwen/decoder.int8.onnx');
      expect(config.model.qwen3Asr.tokenizer, '/models/qwen/tokenizer');
      expect(config.model.qwen3Asr.maxNewTokens, 512);
      expect(config.model.tokens, isEmpty);
      expect(config.model.paraformer.model, isEmpty);
    });
  });
}
