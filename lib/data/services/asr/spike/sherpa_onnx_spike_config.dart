import 'package:sherpa_onnx/sherpa_onnx.dart';

import 'asr_spike_models.dart';

abstract final class SherpaOnnxSpikeConfigFactory {
  static OfflineRecognizerConfig create(AsrSpikeModelSpec spec) {
    return switch (spec.kind) {
      AsrSpikeModelKind.paraformer => OfflineRecognizerConfig(
        model: OfflineModelConfig(
          paraformer: OfflineParaformerModelConfig(
            model: spec.resolve('model.int8.onnx'),
          ),
          tokens: spec.resolve('tokens.txt'),
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
      ),
      AsrSpikeModelKind.qwen3Asr => OfflineRecognizerConfig(
        model: OfflineModelConfig(
          qwen3Asr: OfflineQwen3AsrModelConfig(
            convFrontend: spec.resolve('conv_frontend.onnx'),
            encoder: spec.resolve('encoder.int8.onnx'),
            decoder: spec.resolve('decoder.int8.onnx'),
            tokenizer: spec.resolve('tokenizer'),
            maxTotalLen: 512,
            maxNewTokens: 512,
          ),
          tokens: '',
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
      ),
    };
  }
}
