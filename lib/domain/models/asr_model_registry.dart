import 'asr_model.dart';

const paraformerStandardModelId = 'sherpa-onnx-paraformer-zh-small-2024-03-09';
const qwenAdvancedModelId = 'sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25';

final class AsrModelRegistry {
  AsrModelRegistry({
    required List<AsrModelDescriptor> models,
    required this.defaultModelId,
  }) : models = List.unmodifiable(models),
       _byId = Map.unmodifiable({
         for (final model in models) model.modelId: model,
       }) {
    if (models.isEmpty) {
      throw ArgumentError.value(models, 'models', '不能为空');
    }
    if (_byId.length != models.length) {
      throw ArgumentError.value(models, 'models', 'modelId 不能重复');
    }
    final defaultModel = _byId[defaultModelId];
    if (defaultModel == null) {
      throw ArgumentError.value(
        defaultModelId,
        'defaultModelId',
        '必须存在于 Registry',
      );
    }
    if (defaultModel.tier != AsrModelTier.standard) {
      throw ArgumentError.value(
        defaultModelId,
        'defaultModelId',
        '默认模型必须是标准模型',
      );
    }
  }

  static final alpha = AsrModelRegistry(
    models: [
      AsrModelDescriptor(
        modelId: paraformerStandardModelId,
        displayName: '标准模型（Paraformer）',
        tier: AsrModelTier.standard,
        version: '2024-03-09',
        supportedLanguages: const ['zh', 'en'],
        installationType: AsrInstallationType.bundled,
        requiredBytes: 81904027,
        capabilities: const {'offline', 'meeting-preview', 'final-transcript'},
      ),
      AsrModelDescriptor(
        modelId: qwenAdvancedModelId,
        displayName: '高级模型（Qwen3-ASR）',
        tier: AsrModelTier.advanced,
        version: '2026-03-25',
        supportedLanguages: const ['multilingual'],
        installationType: AsrInstallationType.downloadable,
        requiredBytes: 987015347,
        capabilities: const {'offline', 'high-accuracy', 'final-transcript'},
      ),
    ],
    defaultModelId: paraformerStandardModelId,
  );

  final List<AsrModelDescriptor> models;
  final String defaultModelId;
  final Map<String, AsrModelDescriptor> _byId;

  AsrModelDescriptor get defaultModel => _byId[defaultModelId]!;

  AsrModelDescriptor? findById(String modelId) => _byId[modelId];

  AsrModelDescriptor requireById(String modelId) {
    final model = findById(modelId);
    if (model == null) {
      throw ArgumentError.value(modelId, 'modelId', '未在 Registry 注册');
    }
    return model;
  }
}
