enum AsrModelTier { standard, advanced }

enum AsrInstallationType { bundled, downloadable }

final class AsrModelDescriptor {
  AsrModelDescriptor({
    required this.modelId,
    required this.displayName,
    required this.tier,
    required this.version,
    required List<String> supportedLanguages,
    required this.installationType,
    required this.requiredBytes,
    required Set<String> capabilities,
  }) : supportedLanguages = List.unmodifiable(supportedLanguages),
       capabilities = Set.unmodifiable(capabilities) {
    if (modelId.trim().isEmpty) {
      throw ArgumentError.value(modelId, 'modelId', '不能为空');
    }
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', '不能为空');
    }
    if (version.trim().isEmpty) {
      throw ArgumentError.value(version, 'version', '不能为空');
    }
    if (requiredBytes <= 0) {
      throw ArgumentError.value(requiredBytes, 'requiredBytes', '必须大于 0');
    }
    if (this.supportedLanguages.isEmpty ||
        this.supportedLanguages.any((language) => language.trim().isEmpty)) {
      throw ArgumentError.value(
        supportedLanguages,
        'supportedLanguages',
        '至少包含一个非空语言代码',
      );
    }
    if (this.capabilities.any((capability) => capability.trim().isEmpty)) {
      throw ArgumentError.value(capabilities, 'capabilities', '不能包含空能力');
    }
  }

  final String modelId;
  final String displayName;
  final AsrModelTier tier;
  final String version;
  final List<String> supportedLanguages;
  final AsrInstallationType installationType;
  final int requiredBytes;
  final Set<String> capabilities;
}
