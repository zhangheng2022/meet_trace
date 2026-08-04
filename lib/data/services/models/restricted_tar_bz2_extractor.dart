import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../models/runtime/speaker_diarization_manifest.dart';
import 'runtime_artifact_install_transaction.dart';

/// 只处理已经通过固定下载哈希校验的 tar.bz2，并严格按 Manifest 白名单落盘。
final class RestrictedTarBz2Extractor {
  const RestrictedTarBz2Extractor();

  Future<void> extract({
    required String archivePath,
    required String installationPath,
    required Set<String> allowedEntries,
    required List<SpeakerDiarizationArchiveInstallFile> installFiles,
    required void Function() throwIfCanceled,
  }) async {
    final archiveBytes = await File(archivePath).readAsBytes();
    late final Archive archive;
    try {
      final tarBytes = BZip2Decoder().decodeBytes(archiveBytes);
      archive = TarDecoder().decodeBytes(tarBytes, verify: true);
    } on Object catch (error) {
      throw RuntimeArtifactInstallException(
        RuntimeArtifactInstallFailure.preparation,
        'tar.bz2 解码失败：$error',
      );
    }

    final expected = {for (final file in installFiles) file.archivePath: file};
    final extracted = <String>{};
    final seen = <String>{};
    for (final entry in archive) {
      throwIfCanceled();
      final archiveEntryPath = _safeArchivePath(entry.name);
      if (!seen.add(archiveEntryPath)) {
        throw RuntimeArtifactInstallException(
          RuntimeArtifactInstallFailure.preparation,
          '归档包含重复路径：$archiveEntryPath',
        );
      }
      if (entry.isSymbolicLink) {
        throw RuntimeArtifactInstallException(
          RuntimeArtifactInstallFailure.preparation,
          '归档不允许符号链接或硬链接：$archiveEntryPath',
        );
      }
      if (entry.isDirectory) {
        if (!allowedEntries.any(
          (allowed) => allowed.startsWith('$archiveEntryPath/'),
        )) {
          throw RuntimeArtifactInstallException(
            RuntimeArtifactInstallFailure.preparation,
            '归档包含白名单外目录：$archiveEntryPath',
          );
        }
        continue;
      }
      if (!entry.isFile || !allowedEntries.contains(archiveEntryPath)) {
        throw RuntimeArtifactInstallException(
          RuntimeArtifactInstallFailure.preparation,
          '归档包含白名单外文件：$archiveEntryPath',
        );
      }
      final outputSpec = expected[archiveEntryPath];
      if (outputSpec == null) {
        continue;
      }
      if (entry.size != outputSpec.file.bytes) {
        throw RuntimeArtifactInstallException(
          RuntimeArtifactInstallFailure.integrity,
          '$archiveEntryPath 解包后大小不符',
        );
      }
      final content = entry.readBytes();
      if (content == null || content.length != outputSpec.file.bytes) {
        throw RuntimeArtifactInstallException(
          RuntimeArtifactInstallFailure.integrity,
          '$archiveEntryPath 无法完整读取',
        );
      }
      final destination = _resolveWithin(
        installationPath,
        outputSpec.file.path,
      );
      await Directory(p.dirname(destination)).create(recursive: true);
      final output = await File(destination).open(mode: FileMode.write);
      try {
        await output.writeFrom(content);
        await output.flush();
      } finally {
        await output.close();
      }
      extracted.add(archiveEntryPath);
    }
    final missing = expected.keys.where((path) => !extracted.contains(path));
    if (missing.isNotEmpty) {
      throw RuntimeArtifactInstallException(
        RuntimeArtifactInstallFailure.incomplete,
        '归档缺少固定安装文件：${missing.join(', ')}',
      );
    }
  }
}

String _safeArchivePath(String value) {
  var normalized = value.replaceAll(r'\', '/');
  normalized = normalized.replaceFirst(RegExp(r'/+$'), '');
  final parts = normalized.split('/');
  if (normalized.isEmpty ||
      normalized.contains('\u0000') ||
      p.posix.isAbsolute(normalized) ||
      RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
      parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw RuntimeArtifactInstallException(
      RuntimeArtifactInstallFailure.invalidPath,
      '归档路径不安全：$value',
    );
  }
  return normalized;
}

String _resolveWithin(String root, String relativePath) {
  final normalizedRoot = p.normalize(p.absolute(root));
  final candidate = p.normalize(
    p.absolute(p.joinAll([normalizedRoot, ...relativePath.split('/')])),
  );
  if (candidate == normalizedRoot || !p.isWithin(normalizedRoot, candidate)) {
    throw RuntimeArtifactInstallException(
      RuntimeArtifactInstallFailure.invalidPath,
      '归档安装路径越界：$relativePath',
    );
  }
  return candidate;
}
