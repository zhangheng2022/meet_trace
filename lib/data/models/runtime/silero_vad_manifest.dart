import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../../domain/models/model_manifest.dart';

const sileroVadModelId = 'silero-vad-int8';
const sileroVadModelVersion = '2025-07-11';
const sileroVadModelFileName = 'silero_vad.int8.onnx';
const sileroVadManifestAssetPath = 'assets/models/silero-vad-manifest.json';
const sileroVadSampleRate = 16000;
const sileroVadWindowSize = 512;

final class SileroVadManifest {
  SileroVadManifest({
    required this.schemaVersion,
    required this.modelId,
    required this.version,
    required this.sampleRate,
    required this.windowSize,
    required this.requiredBytes,
    required List<ModelManifestFile> files,
    required this.license,
    required this.licensePath,
  }) : files = List.unmodifiable(files);

  final int schemaVersion;
  final String modelId;
  final String version;
  final int sampleRate;
  final int windowSize;
  final int requiredBytes;
  final List<ModelManifestFile> files;
  final ModelLicense license;
  final String licensePath;

  ModelManifestEntry get verificationEntry => ModelManifestEntry(
    modelId: modelId,
    version: version,
    installationType: 'downloadable',
    requiredBytes: requiredBytes,
    files: files,
    license: license,
  );
}

final class SileroVadManifestParser {
  const SileroVadManifestParser();

  SileroVadManifest parse(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Silero VAD Manifest 顶层必须是对象');
    }
    final schemaVersion = _requiredInt(decoded, 'schemaVersion');
    final modelId = _requiredText(decoded, 'modelId');
    final version = _requiredText(decoded, 'version');
    final sampleRate = _requiredInt(decoded, 'sampleRate');
    final windowSize = _requiredInt(decoded, 'windowSize');
    final requiredBytes = _requiredInt(decoded, 'requiredBytes');
    if (schemaVersion != 1 ||
        modelId != sileroVadModelId ||
        version != sileroVadModelVersion ||
        sampleRate != sileroVadSampleRate ||
        windowSize != sileroVadWindowSize ||
        requiredBytes <= 0) {
      throw const FormatException('Silero VAD Manifest 与应用固定契约不一致');
    }
    final rawFiles = decoded['files'];
    if (rawFiles is! List<dynamic> || rawFiles.length != 1) {
      throw const FormatException('Silero VAD Manifest 必须且只能包含一个文件');
    }
    final files = rawFiles
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException('Silero VAD 文件条目必须是对象');
          }
          final path = _safePath(_requiredText(value, 'path'));
          final bytes = _requiredInt(value, 'bytes');
          final sha256 = _requiredText(value, 'sha256').toLowerCase();
          final url = _requiredText(value, 'url');
          final uri = Uri.tryParse(url);
          if (path != sileroVadModelFileName ||
              bytes <= 0 ||
              !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) ||
              uri == null ||
              uri.scheme != 'https' ||
              uri.host.isEmpty) {
            throw const FormatException('Silero VAD 文件条目无效');
          }
          return ModelManifestFile(
            path: path,
            bytes: bytes,
            sha256: sha256,
            url: url,
          );
        })
        .toList(growable: false);
    if (files.fold<int>(0, (sum, file) => sum + file.bytes) != requiredBytes) {
      throw const FormatException('Silero VAD requiredBytes 与文件合计不一致');
    }
    final licenseJson = decoded['license'];
    if (licenseJson is! Map<String, dynamic>) {
      throw const FormatException('Silero VAD license 必须是对象');
    }
    return SileroVadManifest(
      schemaVersion: schemaVersion,
      modelId: modelId,
      version: version,
      sampleRate: sampleRate,
      windowSize: windowSize,
      requiredBytes: requiredBytes,
      files: files,
      license: ModelLicense(
        name: _requiredText(licenseJson, 'name'),
        noticePath: _safePath(_requiredText(licenseJson, 'noticePath')),
      ),
      licensePath: _safePath(_requiredText(licenseJson, 'licensePath')),
    );
  }
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串');
  }
  return value.trim();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key 必须是整数');
  }
  return value;
}

String _safePath(String value) {
  final normalized = value.replaceAll(r'\', '/');
  if (p.posix.isAbsolute(normalized) ||
      normalized.split('/').any((part) => part.isEmpty || part == '..')) {
    throw FormatException('不安全的相对路径：$value');
  }
  return normalized;
}
