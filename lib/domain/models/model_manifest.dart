final class ModelManifest {
  ModelManifest({
    required this.schemaVersion,
    required this.minAppVersion,
    required List<ModelManifestEntry> models,
  }) : models = List.unmodifiable(models);

  final int schemaVersion;
  final String minAppVersion;
  final List<ModelManifestEntry> models;
}

final class ModelManifestEntry {
  ModelManifestEntry({
    required this.modelId,
    required this.version,
    required this.installationType,
    required this.requiredBytes,
    required List<ModelManifestFile> files,
    required this.license,
  }) : files = List.unmodifiable(files);

  final String modelId;
  final String version;
  final String installationType;
  final int requiredBytes;
  final List<ModelManifestFile> files;
  final ModelLicense license;
}

final class ModelManifestFile {
  const ModelManifestFile({
    required this.path,
    required this.bytes,
    required this.sha256,
    required this.url,
  });

  final String path;
  final int bytes;
  final String sha256;
  final String url;
}

final class ModelLicense {
  const ModelLicense({required this.name, required this.noticePath});

  final String name;
  final String noticePath;
}
