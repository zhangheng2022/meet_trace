import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/whisper/whisper_adapter.dart';
import 'package:meettrace/data/services/asr/whisper/whisper_recognizer_profiles.dart';

void main() {
  test('基线 Profile 精确复现替换前固定 Greedy 参数', () {
    final config = whisperBaselineRecognizerProfile.createConfig(
      modelId: 'base',
      modelVersion: '1',
      modelPath: 'model.bin',
    );

    expect(config.profileId, 'baseline-fixed-greedy-v1');
    expect(config.decodingStrategy, WhisperDecodingStrategy.greedy);
    expect(config.bestOf, 5);
    expect(config.beamSize, 5);
    expect(config.noContext, isTrue);
    expect(config.suppressBlank, isTrue);
    expect(config.temperature, 0);
    expect(config.temperatureIncrement, 0.2);
  });

  test('Preview 与 Final Profile 固定为不同的低延迟/质量候选', () {
    final preview = whisperPreviewRecognizerProfile.createConfig(
      modelId: 'base',
      modelVersion: '1',
      modelPath: 'model.bin',
    );
    final finalConfig = whisperFinalRecognizerProfile.createConfig(
      modelId: 'base',
      modelVersion: '1',
      modelPath: 'model.bin',
    );

    expect(preview.profileId, 'preview-greedy-low-latency-v1');
    expect(preview.decodingStrategy, WhisperDecodingStrategy.greedy);
    expect(preview.bestOf, 1);
    expect(preview.temperatureIncrement, 0);
    expect(finalConfig.profileId, 'final-beam-quality-v1');
    expect(finalConfig.decodingStrategy, WhisperDecodingStrategy.beamSearch);
    expect(finalConfig.beamSize, 5);
  });

  test('配置消息往返保留所有 ABI 字段', () {
    final original = whisperFinalRecognizerProfile.createConfig(
      modelId: 'base',
      modelVersion: '1',
      modelPath: 'model.bin',
      threadCount: 4,
      language: 'zh',
    );
    final restored = WhisperRecognizerConfig.fromMessage(original.toMessage());

    expect(restored.profileId, original.profileId);
    expect(restored.threadCount, original.threadCount);
    expect(restored.language, original.language);
    expect(restored.decodingStrategy, original.decodingStrategy);
    expect(restored.bestOf, original.bestOf);
    expect(restored.beamSize, original.beamSize);
    expect(restored.noContext, original.noContext);
    expect(restored.suppressBlank, original.suppressBlank);
    expect(restored.temperature, original.temperature);
    expect(restored.temperatureIncrement, original.temperatureIncrement);
    expect(restored.initialPrompt, original.initialPrompt);
  });

  test('配置在进入 FFI 前拒绝越界值', () {
    expect(
      () => WhisperRecognizerConfig(
        modelId: 'base',
        modelVersion: '1',
        modelPath: 'model.bin',
        beamSize: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => WhisperRecognizerConfig(
        modelId: 'base',
        modelVersion: '1',
        modelPath: 'model.bin',
        temperatureIncrement: 1.1,
      ),
      throwsArgumentError,
    );
  });
}
