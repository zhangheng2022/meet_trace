import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../domain/models/model_manifest.dart';

/// 下载片段只在下载来源及内容契约均未变化时复用。
final class RuntimeArtifactTempManifest {
  const RuntimeArtifactTempManifest({
    required this.manifest,
    this.downloadSubdirectory = '',
  });

  final ModelManifestEntry manifest;
  final String downloadSubdirectory;

  Map<String, ModelManifestFile> get files {
    final prefix = downloadSubdirectory.isEmpty
        ? ''
        : '${_safeRelativePath(downloadSubdirectory)}/';
    final result = <String, ModelManifestFile>{};
    for (final file in manifest.files) {
      final path = '$prefix${_safeRelativePath(file.path)}';
      if (path == RuntimeArtifactTempState.markerName ||
          path.startsWith('${RuntimeArtifactTempState.markerName}/') ||
          file.bytes <= 0 ||
          result.containsKey(path)) {
        throw const FormatException('运行资源临时文件契约无效');
      }
      result[path] = file;
    }
    if (result.isEmpty ||
        result.keys.any(
          (path) => result.keys.any((other) => other.startsWith('$path/')),
        )) {
      throw const FormatException('运行资源临时文件契约无效');
    }
    return result;
  }

  String get fingerprint {
    final entries = files.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'schemaVersion': 1,
              'modelId': manifest.modelId,
              'version': manifest.version,
              'installationType': manifest.installationType,
              'requiredBytes': manifest.requiredBytes,
              'files': [
                for (final entry in entries)
                  {
                    'path': entry.key,
                    'bytes': entry.value.bytes,
                    'sha256': entry.value.sha256,
                    'url': entry.value.url,
                  },
              ],
            }),
          ),
        )
        .toString();
  }
}

/// 下载事务与启动恢复共用的暂存白名单；永不递归进入符号链接。
final class RuntimeArtifactTempState {
  const RuntimeArtifactTempState();

  static const markerName = '.download-manifest.sha256';

  Future<void> prepare({
    required String tempPath,
    required String tempRoot,
    required RuntimeArtifactTempManifest specification,
  }) async {
    await _requireRealAncestors(tempRoot, tempPath);
    await Directory(tempPath).create(recursive: true);
    await recoverDirectory(tempPath: tempPath, specification: specification);
    // 指纹必须先持久化；没有指纹的半成品不能证明来自当前 Manifest。
    final marker = File(p.join(tempPath, markerName));
    if (!await marker.exists()) {
      await marker.writeAsString(specification.fingerprint, flush: true);
    }
  }

  /// 返回是否仍有可复用的下载字节。
  /// 部分文件只能验证归属与长度，最终完整 SHA-256 仍由安装事务校验。
  Future<bool> recoverDirectory({
    required String tempPath,
    required RuntimeArtifactTempManifest specification,
  }) async {
    if (await FileSystemEntity.type(tempPath, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw FileSystemException('运行资源暂存目录不是普通目录', tempPath);
    }
    final expected = specification.files;
    final markerPath = p.join(tempPath, markerName);
    final markerType = await FileSystemEntity.type(
      markerPath,
      followLinks: false,
    );
    var associated = false;
    if (markerType != FileSystemEntityType.notFound) {
      final marker = File(markerPath);
      associated =
          markerType == FileSystemEntityType.file &&
          await marker.length() == 64 &&
          await marker.readAsString(encoding: latin1) ==
              specification.fingerprint;
      if (!associated) {
        await for (final entity in Directory(
          tempPath,
        ).list(followLinks: false)) {
          await deleteRuntimeTempEntity(
            path: entity.path,
            allowedRoot: tempPath,
          );
        }
        return false;
      }
    }
    final parents = <String>{};
    for (final path in expected.keys) {
      var parent = p.posix.dirname(path);
      while (parent != '.') {
        parents.add(parent);
        parent = p.posix.dirname(parent);
      }
    }
    var retainedBytes = false;
    Future<void> prune(Directory directory) async {
      await for (final entity in directory.list(followLinks: false)) {
        final relative = p
            .relative(entity.path, from: tempPath)
            .split(p.separator)
            .join('/');
        if (relative == markerName && associated) {
          continue;
        }
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.directory &&
            parents.contains(relative)) {
          await prune(Directory(entity.path));
          if (await Directory(entity.path).list(followLinks: false).isEmpty) {
            await Directory(entity.path).delete();
          }
          continue;
        }
        final expectedFile = expected[relative];
        if (type == FileSystemEntityType.file && expectedFile != null) {
          final file = File(entity.path);
          final length = await file.length();
          if (length > 0 && length <= expectedFile.bytes) {
            final complete = length == expectedFile.bytes;
            if ((complete &&
                    (await sha256.bind(file.openRead()).first).toString() ==
                        expectedFile.sha256) ||
                (!complete && associated)) {
              retainedBytes = true;
              continue;
            }
          }
        }
        await deleteRuntimeTempEntity(path: entity.path, allowedRoot: tempPath);
      }
    }

    await prune(Directory(tempPath));
    return retainedBytes;
  }

  Future<void> removeMarker(String tempPath) async {
    await deleteRuntimeTempEntity(
      path: p.join(tempPath, markerName),
      allowedRoot: tempPath,
    );
  }
}

Future<void> deleteRuntimeTempEntity({
  required String path,
  required String allowedRoot,
}) async {
  final root = p.normalize(p.absolute(allowedRoot));
  final target = p.normalize(p.absolute(path));
  if (!p.isWithin(root, target)) {
    throw FileSystemException('拒绝清理运行资源临时根目录之外的路径', target);
  }
  final type = await FileSystemEntity.type(target, followLinks: false);
  if (type == FileSystemEntityType.directory) {
    await for (final child in Directory(target).list(followLinks: false)) {
      await deleteRuntimeTempEntity(path: child.path, allowedRoot: root);
    }
    await Directory(target).delete();
  } else if (type == FileSystemEntityType.link) {
    await Link(target).delete();
  } else if (type != FileSystemEntityType.notFound) {
    await File(target).delete();
  }
}

Future<void> _requireRealAncestors(String rootPath, String targetPath) async {
  final root = p.normalize(p.absolute(rootPath));
  final target = p.normalize(p.absolute(targetPath));
  if (!p.isWithin(root, target)) {
    throw FileSystemException('运行资源暂存路径越界', target);
  }
  var current = p.dirname(root);
  final segments = [
    p.basename(root),
    ...p.split(p.relative(target, from: root)),
  ];
  for (final segment in ['', ...segments]) {
    if (segment.isNotEmpty) {
      current = p.join(current, segment);
    }
    final type = await FileSystemEntity.type(current, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw FileSystemException('运行资源暂存路径包含非目录或符号链接', current);
    }
  }
}

String _safeRelativePath(String value) {
  if (value.contains(r'\') ||
      value.contains('\u0000') ||
      value.contains(':') ||
      value
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw FormatException('不安全的运行资源相对路径：$value');
  }
  return value;
}
