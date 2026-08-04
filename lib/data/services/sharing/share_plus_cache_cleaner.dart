import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class ShareCacheCleaner {
  Future<bool> clear();
}

final class ShareCacheCleanupException implements Exception {
  const ShareCacheCleanupException(this.message);

  final String message;

  @override
  String toString() => 'ShareCacheCleanupException: $message';
}

typedef CacheDirectoryProvider = Future<Directory> Function();

final class SharePlusCacheCleaner implements ShareCacheCleaner {
  const SharePlusCacheCleaner({
    this.cacheDirectoryProvider = getTemporaryDirectory,
  });

  final CacheDirectoryProvider cacheDirectoryProvider;

  @override
  Future<bool> clear() async {
    final cacheRoot = await cacheDirectoryProvider();
    final normalizedRoot = p.normalize(p.absolute(cacheRoot.path));
    final target = p.normalize(
      p.absolute(p.join(normalizedRoot, 'share_plus')),
    );
    if (!p.isWithin(normalizedRoot, target)) {
      throw ShareCacheCleanupException('拒绝清理应用缓存目录之外的路径：$target');
    }

    try {
      final type = await FileSystemEntity.type(target, followLinks: false);
      switch (type) {
        case FileSystemEntityType.notFound:
          return false;
        case FileSystemEntityType.directory:
          await Directory(target).delete(recursive: true);
        case FileSystemEntityType.link:
          await Link(target).delete();
        case FileSystemEntityType.file:
          await File(target).delete();
        default:
          throw ShareCacheCleanupException('无法识别 share_plus 缓存路径类型：$target');
      }
      return true;
    } on ShareCacheCleanupException {
      rethrow;
    } on FileSystemException catch (error) {
      throw ShareCacheCleanupException('无法清理 share_plus 缓存：${error.message}');
    }
  }
}
