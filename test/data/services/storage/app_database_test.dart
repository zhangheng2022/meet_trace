import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/storage/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('首次创建数据库包含全部 Step 03 表和版本', () async {
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

  test('现有 user_version 0 数据库通过迁移升级到 v1', () async {
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
}
