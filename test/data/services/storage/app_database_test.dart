import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/storage/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('首次创建数据库包含模型活动版本、租约表和当前版本', () async {
    final database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    final db = await database.open();
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables = tableRows.map((row) => row['name']).toSet();
    final versionRows = await db.rawQuery('PRAGMA user_version');

    expect(
      tables,
      containsAll({
        'meetings',
        'transcript_snapshots',
        'transcript_segments',
        'summaries',
        'summary_items',
        'summary_evidence',
        'model_installations',
        'processing_tasks',
        'app_settings',
        'active_model_versions',
        'model_usage_leases',
      }),
    );
    expect(versionRows.single['user_version'], AppDatabase.schemaVersion);
  });

  test('每次打开都会启用外键约束', () async {
    final database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    final db = await database.open();
    final rows = await db.rawQuery('PRAGMA foreign_keys');

    expect(rows.single['foreign_keys'], 1);
  });

  test('现有 user_version 0 数据库通过迁移升级到当前版本', () async {
    final root = await Directory.systemTemp.createTemp('meetily-migration-');
    addTearDown(() => root.delete(recursive: true));
    final path = p.join(root.path, 'legacy.db');
    final legacy = await databaseFactoryFfi.openDatabase(path);
    await legacy.execute('CREATE TABLE legacy_marker (id INTEGER PRIMARY KEY)');
    await legacy.close();

    final database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(database.close);
    final db = await database.open();
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'meetings'",
    );

    expect(rows, hasLength(1));
    expect(await db.getVersion(), AppDatabase.schemaVersion);
  });

  test('现有 v1 数据库升级到当前版本并保留原表', () async {
    final root = await Directory.systemTemp.createTemp('meetily-v1-');
    addTearDown(() => root.delete(recursive: true));
    final path = p.join(root.path, 'v1.db');
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE legacy_marker (id INTEGER PRIMARY KEY)',
          );
          await db.insert('legacy_marker', {'id': 1});
        },
      ),
    );
    await legacy.close();

    final database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(database.close);
    final db = await database.open();
    final settings = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name = 'app_settings'",
    );
    final marker = await db.query('legacy_marker');

    expect(settings, hasLength(1));
    expect(marker.single['id'], 1);
    expect(await db.getVersion(), AppDatabase.schemaVersion);
  });
}
