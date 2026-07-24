import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/domain/models/asr_model.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';

void main() {
  group('AsrModelRegistry', () {
    test('Alpha Registry 恰有一个标准默认模型并注册双模型', () {
      final registry = AsrModelRegistry.alpha;

      expect(registry.models, hasLength(2));
      expect(registry.defaultModel.modelId, paraformerStandardModelId);
      expect(registry.defaultModel.tier, AsrModelTier.standard);
      expect(
        registry.requireById(qwenAdvancedModelId).installationType,
        AsrInstallationType.downloadable,
      );
    });

    test('拒绝重复模型 ID', () {
      final model = _descriptor(
        modelId: 'duplicate',
        tier: AsrModelTier.standard,
      );

      expect(
        () => AsrModelRegistry(
          models: [model, model],
          defaultModelId: model.modelId,
        ),
        throwsArgumentError,
      );
    });

    test('默认模型必须是标准模型', () {
      final advanced = _descriptor(
        modelId: 'advanced',
        tier: AsrModelTier.advanced,
      );

      expect(
        () => AsrModelRegistry(
          models: [advanced],
          defaultModelId: advanced.modelId,
        ),
        throwsArgumentError,
      );
    });
  });
}

AsrModelDescriptor _descriptor({
  required String modelId,
  required AsrModelTier tier,
}) {
  return AsrModelDescriptor(
    modelId: modelId,
    displayName: modelId,
    tier: tier,
    version: '1.0.0',
    supportedLanguages: const ['zh'],
    installationType: tier == AsrModelTier.standard
        ? AsrInstallationType.bundled
        : AsrInstallationType.downloadable,
    requiredBytes: 5,
    capabilities: const {'offline'},
  );
}
