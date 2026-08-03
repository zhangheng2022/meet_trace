import 'asr_model.dart';

const senseVoiceDefaultModelId =
    'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17';

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
    if (_byId[defaultModelId] == null) {
      throw ArgumentError.value(
        defaultModelId,
        'defaultModelId',
        '必须存在于 Registry',
      );
    }
  }

  static final alpha = AsrModelRegistry(
    models: [
      AsrModelDescriptor(
        modelId: senseVoiceDefaultModelId,
        displayName: 'SenseVoice',
        version: '2024-07-17',
        supportedLanguages: const ['zh', 'yue', 'en', 'ja', 'ko'],
        installationType: AsrInstallationType.downloadable,
        requiredBytes: 239549735,
        capabilities: const {
          'offline',
          'meeting-preview',
          'final-transcript',
          'auto-language',
          'inverse-text-normalization',
          'required-runtime',
        },
        language: 'auto',
        useInverseTextNormalization: true,
      ),
    ],
    defaultModelId: senseVoiceDefaultModelId,
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
