import 'dart:convert';

import '../../../domain/models/asr_model_registry.dart';
import '../../../domain/models/model_manifest.dart';

final class ModelManifestParser {
  const ModelManifestParser({
    required this.registry,
    required this.currentAppVersion,
  });

  static const supportedSchemaVersion = 1;

  final AsrModelRegistry registry;
  final String currentAppVersion;

  ModelManifest parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Manifest 不是合法 JSON：${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Manifest 顶层必须是对象');
    }

    final schemaVersion = _requiredInt(decoded, 'schemaVersion');
    if (schemaVersion != supportedSchemaVersion) {
      throw FormatException('不兼容的 Manifest schemaVersion：$schemaVersion');
    }
    final minAppVersion = _requiredText(decoded, 'minAppVersion');
    if (_compareVersions(minAppVersion, currentAppVersion) > 0) {
      throw FormatException(
        'Manifest 最低 App 版本 $minAppVersion 高于当前 $currentAppVersion',
      );
    }

    final rawModels = _requiredList(decoded, 'models');
    if (rawModels.isEmpty) {
      throw const FormatException('Manifest models 不能为空');
    }
    final entries = <ModelManifestEntry>[];
    final modelIds = <String>{};
    for (final rawModel in rawModels) {
      final model = _requiredMap(rawModel, 'models[]');
      final entry = _parseEntry(model);
      if (!modelIds.add(entry.modelId)) {
        throw FormatException('Manifest modelId 重复：${entry.modelId}');
      }
      entries.add(entry);
    }

    return ModelManifest(
      schemaVersion: schemaVersion,
      minAppVersion: minAppVersion,
      models: entries,
    );
  }

  ModelManifestEntry _parseEntry(Map<String, dynamic> json) {
    final modelId = _requiredText(json, 'modelId');
    final version = _requiredText(json, 'version');
    final installationType = _requiredText(json, 'installationType');
    final requiredBytes = _positiveInt(json, 'requiredBytes');
    final descriptor = registry.findById(modelId);
    if (descriptor == null) {
      throw FormatException('Manifest 包含 Registry 外模型：$modelId');
    }
    if (descriptor.version != version ||
        descriptor.installationType.name != installationType ||
        descriptor.requiredBytes != requiredBytes) {
      throw FormatException('Manifest 与 Registry 元数据不一致：$modelId@$version');
    }

    final rawFiles = _requiredList(json, 'files');
    if (rawFiles.isEmpty) {
      throw FormatException('模型 $modelId 的 files 不能为空');
    }
    final files = <ModelManifestFile>[];
    final paths = <String>{};
    for (final rawFile in rawFiles) {
      final file = _parseFile(
        _requiredMap(rawFile, 'files[]'),
        installationType: installationType,
      );
      if (!paths.add(file.path)) {
        throw FormatException('模型 $modelId 的文件路径重复：${file.path}');
      }
      files.add(file);
    }
    final fileBytes = files.fold<int>(0, (sum, file) => sum + file.bytes);
    if (fileBytes != requiredBytes) {
      throw FormatException(
        '模型 $modelId 的 requiredBytes=$requiredBytes，'
        '但文件合计为 $fileBytes',
      );
    }

    final licenseJson = _requiredMap(json['license'], 'license');
    final license = ModelLicense(
      name: _requiredText(licenseJson, 'name'),
      noticePath: _safeRelativePath(
        _requiredText(licenseJson, 'noticePath'),
        'noticePath',
      ),
    );

    return ModelManifestEntry(
      modelId: modelId,
      version: version,
      installationType: installationType,
      requiredBytes: requiredBytes,
      files: files,
      license: license,
    );
  }

  ModelManifestFile _parseFile(
    Map<String, dynamic> json, {
    required String installationType,
  }) {
    final path = _safeRelativePath(_requiredText(json, 'path'), 'path');
    final bytes = _positiveInt(json, 'bytes');
    final hash = _requiredText(json, 'sha256').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw FormatException('文件 $path 的 sha256 必须是 64 位十六进制');
    }
    final url = _requiredText(json, 'url');
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw FormatException('文件 $path 的 url 无效');
    }
    if (installationType == 'downloadable' && uri.scheme != 'https') {
      throw FormatException('可下载模型文件必须使用 HTTPS：$path');
    }
    if (installationType == 'bundled' && uri.scheme != 'asset') {
      throw FormatException('内置模型文件必须使用 asset:// URL：$path');
    }

    return ModelManifestFile(path: path, bytes: bytes, sha256: hash, url: url);
  }
}

Map<String, dynamic> _requiredMap(Object? value, String name) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$name 必须是对象');
  }
  return value;
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List<dynamic>) {
    throw FormatException('$key 必须是数组');
  }
  return value;
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串');
  }
  final trimmed = value.trim();
  if (trimmed.contains('<') ||
      trimmed.contains('>') ||
      trimmed.toLowerCase() == 'pending') {
    throw FormatException('$key 不能包含占位符');
  }
  return trimmed;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key 必须是整数');
  }
  return value;
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = _requiredInt(json, key);
  if (value <= 0) {
    throw FormatException('$key 必须大于 0');
  }
  return value;
}

String _safeRelativePath(String value, String name) {
  final normalized = value.replaceAll(r'\', '/');
  final segments = normalized.split('/');
  if (normalized.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
      normalized.contains('\u0000') ||
      segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      )) {
    throw FormatException('$name 不是安全的相对路径：$value');
  }
  return normalized;
}

int _compareVersions(String left, String right) {
  List<int> parse(String value) {
    final core = value.split('+').first.split('-').first;
    final parts = core.split('.');
    if (parts.length != 3) {
      throw FormatException('App 版本必须是 major.minor.patch：$value');
    }
    return parts
        .map((part) {
          final number = int.tryParse(part);
          if (number == null || number < 0) {
            throw FormatException('App 版本无效：$value');
          }
          return number;
        })
        .toList(growable: false);
  }

  final leftParts = parse(left);
  final rightParts = parse(right);
  for (var index = 0; index < leftParts.length; index++) {
    final comparison = leftParts[index].compareTo(rightParts[index]);
    if (comparison != 0) {
      return comparison;
    }
  }
  return 0;
}
