import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/models/model_manifest.dart';
import '../models/downloadable_model_service.dart';
import '../models/model_file_verifier.dart';
import '../models/runtime_asset_installers.dart';
import '../storage/app_file_layout.dart';
import 'silero_vad_segmenter.dart';

const sileroVadModelId = 'silero-vad-int8';
const sileroVadModelVersion = '2025-07-11';
const sileroVadModelFileName = 'silero_vad.int8.onnx';
const sileroVadManifestAssetPath = 'assets/models/silero-vad-manifest.json';

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

final class DownloadableSileroVadModelService implements RuntimeVadInstaller {
  const DownloadableSileroVadModelService({
    required this.fileLayout,
    required this.downloader,
    this.verifier = const ModelFileVerifier(),
  });

  final AppFileLayout fileLayout;
  final ModelFileDownloader downloader;
  final ModelFileVerifier verifier;

  String modelPath(SileroVadManifest manifest) => p.join(
    fileLayout.modelVersionDirectory(manifest.modelId, manifest.version),
    sileroVadModelFileName,
  );

  @override
  Future<bool> isReadyFast(SileroVadManifest manifest) async {
    final file = File(modelPath(manifest));
    if (!await file.exists() || await file.length() != manifest.requiredBytes) {
      return false;
    }
    final root = Directory(p.dirname(file.path));
    var files = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        files++;
      }
    }
    return files == manifest.files.length;
  }

  @override
  Future<String> prepare({
    required SileroVadManifest manifest,
    required ModelDownloadCancellationToken cancellation,
    void Function(int completedBytes, int totalBytes)? onProgress,
  }) async {
    try {
      return await _prepare(
        manifest: manifest,
        cancellation: cancellation,
        onProgress: onProgress,
      );
    } on ModelDownloadCanceledException catch (error) {
      throw DownloadableModelException(
        code: 'model.download.canceled',
        message: 'VAD 下载已暂停，可稍后继续',
        cause: error,
      );
    }
  }

  Future<String> _prepare({
    required SileroVadManifest manifest,
    required ModelDownloadCancellationToken cancellation,
    void Function(int completedBytes, int totalBytes)? onProgress,
  }) async {
    final finalPath = fileLayout.modelVersionDirectory(
      manifest.modelId,
      manifest.version,
    );
    final tempPath = fileLayout.modelTempDirectory(
      manifest.modelId,
      manifest.version,
    );
    final finalVerification = await verifier.verifyDirectory(
      directoryPath: finalPath,
      manifest: manifest.verificationEntry,
    );
    if (finalVerification.isValid) {
      return modelPath(manifest);
    }
    await Directory(tempPath).create(recursive: true);
    var completedBefore = 0;
    for (final file in manifest.files) {
      cancellation.throwIfCanceled();
      final destination = _resolveWithin(tempPath, file.path);
      await Directory(p.dirname(destination)).create(recursive: true);
      final output = File(destination);
      var resumeFrom = await output.exists() ? await output.length() : 0;
      if (resumeFrom > file.bytes) {
        await output.delete();
        resumeFrom = 0;
      }
      onProgress?.call(completedBefore + resumeFrom, manifest.requiredBytes);
      if (resumeFrom < file.bytes) {
        final result = await downloader.download(
          source: Uri.parse(file.url),
          destinationPath: destination,
          resumeFrom: resumeFrom,
          expectedBytes: file.bytes,
          cancellation: cancellation,
          onProgress: (value) =>
              onProgress?.call(completedBefore + value, manifest.requiredBytes),
        );
        if (result.finalBytes != file.bytes) {
          throw const DownloadableModelException(
            code: 'vad.download.incomplete',
            message: 'VAD 下载不完整',
          );
        }
      }
      completedBefore += file.bytes;
    }
    final verification = await verifier.verifyDirectory(
      directoryPath: tempPath,
      manifest: manifest.verificationEntry,
    );
    if (!verification.isValid) {
      await _deleteWithin(tempPath, fileLayout.modelTempRoot);
      throw DownloadableModelException(
        code: 'vad.integrity',
        message: verification.issues
            .map((issue) => '${issue.path}:${issue.kind.name}')
            .join(', '),
      );
    }
    await Directory(p.dirname(finalPath)).create(recursive: true);
    await _deleteWithin(finalPath, fileLayout.modelsRoot);
    await Directory(tempPath).rename(finalPath);
    return modelPath(manifest);
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

String _resolveWithin(String root, String relativePath) {
  final normalizedRoot = p.normalize(p.absolute(root));
  final candidate = p.normalize(
    p.absolute(p.join(normalizedRoot, relativePath)),
  );
  if (!p.isWithin(normalizedRoot, candidate)) {
    throw StateError('VAD 下载路径越界');
  }
  return candidate;
}

Future<void> _deleteWithin(String path, String allowedRoot) async {
  final normalizedRoot = p.normalize(p.absolute(allowedRoot));
  final normalizedPath = p.normalize(p.absolute(path));
  if (!p.isWithin(normalizedRoot, normalizedPath)) {
    throw StateError('拒绝删除允许根目录之外的路径');
  }
  final directory = Directory(normalizedPath);
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}
