import 'asr_model.dart';

const whisperBaseStandardModelId = 'whisper-cpp-base-q5_1-v1.9.1';
const whisperSmallAdvancedModelId = 'whisper-cpp-small-q5_1-v1.9.1';

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
        modelId: whisperBaseStandardModelId,
        displayName: '标准模型（Whisper Base）',
        tier: AsrModelTier.standard,
        version: 'v1.9.1-q5_1',
        supportedLanguages: const ['multilingual'],
        installationType: AsrInstallationType.bundled,
        requiredBytes: 60592723,
        capabilities: const {
          'offline',
          'multilingual',
          'meeting-preview',
          'final-transcript',
          'timestamps',
        },
      ),
      AsrModelDescriptor(
        modelId: whisperSmallAdvancedModelId,
        displayName: '高级模型（Whisper Small）',
        tier: AsrModelTier.advanced,
        version: 'v1.9.1-q5_1',
        supportedLanguages: const ['multilingual'],
        installationType: AsrInstallationType.downloadable,
        requiredBytes: 190085487,
        capabilities: const {
          'offline',
          'multilingual',
          'high-accuracy',
          'meeting-preview',
          'final-transcript',
          'timestamps',
        },
      ),
    ],
    defaultModelId: whisperBaseStandardModelId,
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
