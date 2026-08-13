import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/sharing/share_plus_cache_cleaner.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory cacheRoot;

  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp(
      'meettrace-share-plus-cache-',
    );
  });

  tearDown(() async {
    if (await cacheRoot.exists()) {
      await cacheRoot.delete(recursive: true);
    }
  });

  test('删除 share_plus 插件缓存且保留其他缓存', () async {
    final pluginCache = Directory(p.join(cacheRoot.path, 'share_plus'));
    final sibling = File(p.join(cacheRoot.path, 'keep.txt'));
    await pluginCache.create(recursive: true);
    await File(p.join(pluginCache.path, 'meeting-audio.wav'))
        .writeAsBytes([1, 2, 3]);
    await sibling.writeAsString('keep');
    final cleaner = SharePlusCacheCleaner(
      cacheDirectoryProvider: () async => cacheRoot,
    );

    expect(await cleaner.clear(), true);

    expect(await pluginCache.exists(), false);
    expect(await sibling.readAsString(), 'keep');
  });

  test('缓存不存在时幂等返回未删除', () async {
    final cleaner = SharePlusCacheCleaner(
      cacheDirectoryProvider: () async => cacheRoot,
    );

    expect(await cleaner.clear(), false);
    expect(await cleaner.clear(), false);
  });

  test('插件缓存路径是符号链接时只删除链接而不跟随', () async {
    if (Platform.isWindows) {
      return;
    }
    final outside = await Directory.systemTemp.createTemp(
      'meettrace-share-plus-outside-',
    );
    addTearDown(() async {
      if (await outside.exists()) {
        await outside.delete(recursive: true);
      }
    });
    final protected = File(p.join(outside.path, 'protected.wav'));
    await protected.writeAsBytes([4, 5, 6]);
    final link = Link(p.join(cacheRoot.path, 'share_plus'));
    await link.create(outside.path);
    final cleaner = SharePlusCacheCleaner(
      cacheDirectoryProvider: () async => cacheRoot,
    );

    expect(await cleaner.clear(), true);

    expect(await link.exists(), false);
    expect(await protected.readAsBytes(), [4, 5, 6]);
  });
}
