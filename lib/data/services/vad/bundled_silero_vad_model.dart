import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/models/model_manifest.dart';
import '../models/bundled_model_preparation_service.dart';
import '../models/model_file_verifier.dart';
import '../storage/app_file_layout.dart';
import 'silero_vad_segmenter.dart';

const bundledSileroVadModelId = 'silero-vad-int8';
const bundledSileroVadModelVersion = '2025-07-11';
const bundledSileroVadModelFileName = 'silero_vad.int8.onnx';
const bundledSileroVadAssetDirectory =
    'assets/models/silero-vad-int8-2025-07-11';
const bundledSileroVadManifestAssetPath =
    'assets/models/silero-vad-manifest.json';
const bundledSileroVadManifestAssetUrl =
    'asset://$bundledSileroVadManifestAssetPath';

final class SileroVadAssetManifest {
  SileroVadAssetManifest({
    required this.schemaVersion,
    required this.modelId,
    required this.version,
    required this.sampleRate,
    required this.windowSize,
    required this.requiredBytes,
    required List<ModelManifestFile> files,
    required this.license,
    required this.licensePath,
    required this.documentationUrl,
    required this.downloadUrl,
    required this.releaseAssetId,
    required this.releaseAssetUpdatedAt,
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
  final Uri documentationUrl;
  final Uri downloadUrl;
  final int releaseAssetId;
  final DateTime releaseAssetUpdatedAt;

  ModelManifestEntry get verificationEntry => ModelManifestEntry(
    modelId: modelId,
    version: version,
    tier: 'supporting',
    installationType: 'bundled',
    requiredBytes: requiredBytes,
    files: files,
    license: license,
  );
}

final class SileroVadAssetManifestParser {
  const SileroVadAssetManifestParser();

  SileroVadAssetManifest parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Silero VAD Manifest 不是合法 JSON：${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Silero VAD Manifest 顶层必须是对象');
    }

    final schemaVersion = _requiredInt(decoded, 'schemaVersion');
    if (schemaVersion != 1) {
      throw FormatException('不兼容的 Silero VAD Manifest schema：$schemaVersion');
    }
    final modelId = _requiredText(decoded, 'modelId');
    final version = _requiredText(decoded, 'version');
    final sampleRate = _requiredInt(decoded, 'sampleRate');
    final windowSize = _requiredInt(decoded, 'windowSize');
    final requiredBytes = _requiredInt(decoded, 'requiredBytes');
    if (modelId != bundledSileroVadModelId ||
        version != bundledSileroVadModelVersion ||
        sampleRate != sileroVadSampleRate ||
        windowSize != sileroVadWindowSize ||
        requiredBytes <= 0) {
      throw const FormatException('Silero VAD Manifest 与应用固定契约不一致');
    }

    final filesJson = decoded['files'];
    if (filesJson is! List<dynamic> || filesJson.length != 1) {
      throw const FormatException('Silero VAD Manifest 必须且只能包含一个模型文件');
    }
    final files = filesJson
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException('Silero VAD 文件条目必须是对象');
          }
          final path = _safeRelativePath(_requiredText(value, 'path'), 'path');
          final bytes = _requiredInt(value, 'bytes');
          final sha256 = _requiredText(value, 'sha256').toLowerCase();
          final url = _requiredText(value, 'url');
          if (path != bundledSileroVadModelFileName ||
              bytes <= 0 ||
              !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) ||
              Uri.tryParse(url)?.scheme != 'asset') {
            throw FormatException('Silero VAD 文件条目无效：$path');
          }
          return ModelManifestFile(
            path: path,
            bytes: bytes,
            sha256: sha256,
            url: url,
          );
        })
        .toList(growable: false);
    if (files.fold<int>(0, (total, file) => total + file.bytes) !=
        requiredBytes) {
      throw const FormatException('Silero VAD 文件字节数之和与 requiredBytes 不一致');
    }

    final licenseJson = _requiredMap(decoded, 'license');
    final license = ModelLicense(
      name: _requiredText(licenseJson, 'name'),
      noticePath: _safeRelativePath(
        _requiredText(licenseJson, 'noticePath'),
        'noticePath',
      ),
    );
    final licensePath = _safeRelativePath(
      _requiredText(licenseJson, 'licensePath'),
      'licensePath',
    );

    final sourceJson = _requiredMap(decoded, 'source');
    final documentationUrl = _requiredHttpsUri(sourceJson, 'documentationUrl');
    final downloadUrl = _requiredHttpsUri(sourceJson, 'downloadUrl');
    final releaseAssetId = _requiredInt(sourceJson, 'releaseAssetId');
    final releaseAssetUpdatedAt = DateTime.tryParse(
      _requiredText(sourceJson, 'releaseAssetUpdatedAt'),
    );
    if (releaseAssetId <= 0 ||
        releaseAssetUpdatedAt == null ||
        !releaseAssetUpdatedAt.isUtc) {
      throw const FormatException('Silero VAD 来源版本信息无效');
    }

    return SileroVadAssetManifest(
      schemaVersion: schemaVersion,
      modelId: modelId,
      version: version,
      sampleRate: sampleRate,
      windowSize: windowSize,
      requiredBytes: requiredBytes,
      files: files,
      license: license,
      licensePath: licensePath,
      documentationUrl: documentationUrl,
      downloadUrl: downloadUrl,
      releaseAssetId: releaseAssetId,
      releaseAssetUpdatedAt: releaseAssetUpdatedAt,
    );
  }
}

final class PreparedSileroVadModel {
  const PreparedSileroVadModel({
    required this.modelPath,
    required this.manifest,
    required this.alreadyReady,
  });

  final String modelPath;
  final SileroVadAssetManifest manifest;
  final bool alreadyReady;
}

final class BundledSileroVadPreparationException implements Exception {
  const BundledSileroVadPreparationException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'BundledSileroVadPreparationException($code, $message)';
}

final class BundledSileroVadModelService {
  const BundledSileroVadModelService({
    required this.fileLayout,
    required this.assetSource,
    this.manifestParser = const SileroVadAssetManifestParser(),
    this.verifier = const ModelFileVerifier(),
  });

  final AppFileLayout fileLayout;
  final ModelAssetSource assetSource;
  final SileroVadAssetManifestParser manifestParser;
  final ModelFileVerifier verifier;

  Future<PreparedSileroVadModel> prepare() async {
    String? tempPath;
    try {
      final manifestBytes = await assetSource.load(
        bundledSileroVadManifestAssetUrl,
      );
      final manifest = manifestParser.parse(
        utf8.decode(manifestBytes, allowMalformed: false),
      );
      final finalPath = fileLayout.modelVersionDirectory(
        manifest.modelId,
        manifest.version,
      );
      tempPath = fileLayout.modelTempDirectory(
        manifest.modelId,
        manifest.version,
      );
      final finalDirectory = Directory(finalPath);
      if (await finalDirectory.exists()) {
        final existing = await verifier.verifyDirectory(
          directoryPath: finalPath,
          manifest: manifest.verificationEntry,
        );
        if (existing.isValid) {
          return PreparedSileroVadModel(
            modelPath: p.join(finalPath, bundledSileroVadModelFileName),
            manifest: manifest,
            alreadyReady: true,
          );
        }
        await _deleteDirectoryWithin(
          path: finalPath,
          allowedRoot: fileLayout.modelsRoot,
        );
      }

      await _deleteDirectoryWithin(
        path: tempPath,
        allowedRoot: fileLayout.modelTempRoot,
      );
      await Directory(tempPath).create(recursive: true);
      for (final file in manifest.files) {
        final bytes = await assetSource.load(file.url);
        final outputPath = _resolveWithin(tempPath, file.path);
        await Directory(p.dirname(outputPath)).create(recursive: true);
        final output = await File(outputPath).open(mode: FileMode.write);
        try {
          await output.writeFrom(bytes);
          await output.flush();
        } finally {
          await output.close();
        }
      }

      final verification = await verifier.verifyDirectory(
        directoryPath: tempPath,
        manifest: manifest.verificationEntry,
      );
      if (!verification.isValid) {
        throw BundledSileroVadPreparationException(
          code: 'vad.model.integrity',
          message: verification.issues
              .map((issue) => '${issue.path}:${issue.kind.name}')
              .join(', '),
        );
      }
      await Directory(p.dirname(finalPath)).create(recursive: true);
      await Directory(tempPath).rename(finalPath);
      tempPath = null;
      return PreparedSileroVadModel(
        modelPath: p.join(finalPath, bundledSileroVadModelFileName),
        manifest: manifest,
        alreadyReady: false,
      );
    } on BundledSileroVadPreparationException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        BundledSileroVadPreparationException(
          code: 'vad.model.prepare_failed',
          message: '内置 Silero VAD 模型准备失败',
          cause: error,
        ),
        stackTrace,
      );
    } finally {
      if (tempPath != null) {
        await _deleteDirectoryWithin(
          path: tempPath,
          allowedRoot: fileLayout.modelTempRoot,
        );
      }
    }
  }

  String _resolveWithin(String root, String relativePath) {
    final normalizedRoot = p.normalize(p.absolute(root));
    final resolved = p.normalize(
      p.absolute(p.join(normalizedRoot, relativePath)),
    );
    if (!p.isWithin(normalizedRoot, resolved)) {
      throw ArgumentError.value(relativePath, 'relativePath', '路径越界');
    }
    return resolved;
  }

  Future<void> _deleteDirectoryWithin({
    required String path,
    required String allowedRoot,
  }) async {
    final normalizedRoot = p.normalize(p.absolute(allowedRoot));
    final normalizedPath = p.normalize(p.absolute(path));
    if (!p.isWithin(normalizedRoot, normalizedPath)) {
      throw StateError('拒绝删除允许根目录之外的路径：$normalizedPath');
    }
    final directory = Directory(normalizedPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key 必须是对象');
  }
  return value;
}

String _requiredText(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串');
  }
  return value.trim();
}

int _requiredInt(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! int) {
    throw FormatException('$key 必须是整数');
  }
  return value;
}

Uri _requiredHttpsUri(Map<String, dynamic> source, String key) {
  final value = Uri.tryParse(_requiredText(source, key));
  if (value == null || value.scheme != 'https' || value.host.isEmpty) {
    throw FormatException('$key 必须是 HTTPS URL');
  }
  return value;
}

String _safeRelativePath(String value, String key) {
  final normalized = value.replaceAll(r'\', '/');
  final segments = normalized.split('/');
  if (p.posix.isAbsolute(normalized) ||
      normalized.contains('\u0000') ||
      segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      )) {
    throw FormatException('$key 不是安全相对路径');
  }
  return normalized;
}
