import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';

void main() {
  group('AsrModelRegistry', () {
    test('Alpha Registry 只登记唯一默认 SenseVoice', () {
      final registry = AsrModelRegistry.alpha;

      expect(registry.models, hasLength(1));
      expect(registry.defaultModel.modelId, senseVoiceDefaultModelId);
      expect(
        registry.defaultModel.installationType,
        AsrInstallationType.downloadable,
      );
      expect(registry.defaultModel.supportedLanguages, [
        'zh',
        'yue',
        'en',
        'ja',
        'ko',
      ]);
      expect(registry.defaultModel.language, 'auto');
      expect(registry.defaultModel.useInverseTextNormalization, isTrue);
      expect(registry.defaultModel.requiredBytes, 239549735);
    });

    test('拒绝重复模型 ID', () {
      final model = _descriptor('duplicate');
      expect(
        () => AsrModelRegistry(
          models: [model, model],
          defaultModelId: model.modelId,
        ),
        throwsArgumentError,
      );
    });

    test('默认模型必须存在于 Registry', () {
      expect(
        () => AsrModelRegistry(
          models: [_descriptor('available')],
          defaultModelId: 'missing',
        ),
        throwsArgumentError,
      );
    });
  });
}

AsrModelDescriptor _descriptor(String modelId) => AsrModelDescriptor(
  modelId: modelId,
  displayName: modelId,
  version: '1.0.0',
  supportedLanguages: const ['zh'],
  installationType: AsrInstallationType.downloadable,
  requiredBytes: 5,
  capabilities: const {'offline'},
);
