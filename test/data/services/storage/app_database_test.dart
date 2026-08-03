import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
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
    final summaryColumns = await db.rawQuery('PRAGMA table_info(summaries)');
    final meetingColumns = await db.rawQuery('PRAGMA table_info(meetings)');
    final meetingColumnNames = meetingColumns
        .map((column) => column['name'])
        .toSet();

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
    expect(summaryColumns.map((column) => column['name']), contains('title'));
    // 单模型基线：会议表不再保留请求模型与回退原因遗留列。
    expect(meetingColumnNames, isNot(contains('requested_model_id')));
    expect(meetingColumnNames, isNot(contains('model_fallback_reason')));
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
    final root = await Directory.systemTemp.createTemp('meettrace-migration-');
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

  test('现有 v1 数据库拒绝原地升级且不删除原表', () async {
    final root = await Directory.systemTemp.createTemp('meettrace-v1-');
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
    await expectLater(
      database.open(),
      throwsA(isA<UnsupportedAlphaInstallationException>()),
    );
    final untouched = await databaseFactoryFfi.openDatabase(path);
    addTearDown(untouched.close);
    final marker = await untouched.query('legacy_marker');

    expect(marker.single['id'], 1);
    expect(await untouched.getVersion(), 1);
  });

  test('现有 v5 数据库拒绝原地升级且保留原表', () async {
    final root = await Directory.systemTemp.createTemp('meettrace-v5-');
    addTearDown(() => root.delete(recursive: true));
    final path = p.join(root.path, 'v5.db');
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE meetings (id TEXT PRIMARY KEY NOT NULL)',
          );
          await db.insert('meetings', {'id': 'meeting-legacy'});
        },
      ),
    );
    await legacy.close();

    final database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(database.close);
    await expectLater(
      database.open(),
      throwsA(isA<UnsupportedAlphaInstallationException>()),
    );
    // 生产路径由数据代门在打开数据库前全清；此处验证数据库层自身的兜底拒绝。
    final untouched = await databaseFactoryFfi.openDatabase(path);
    addTearDown(untouched.close);
    final rows = await untouched.query('meetings');

    expect(rows.single['id'], 'meeting-legacy');
    expect(await untouched.getVersion(), 5);
  });

  test('现有 v3 数据库拒绝原地升级且保留摘要', () async {
    final root = await Directory.systemTemp.createTemp('meettrace-v3-');
    addTearDown(() => root.delete(recursive: true));
    final path = p.join(root.path, 'v3.db');
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE summaries (id TEXT PRIMARY KEY NOT NULL)',
          );
          await db.insert('summaries', {'id': 'summary-legacy'});
        },
      ),
    );
    await legacy.close();

    final database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(database.close);
    await expectLater(
      database.open(),
      throwsA(isA<UnsupportedAlphaInstallationException>()),
    );
    final untouched = await databaseFactoryFfi.openDatabase(path);
    addTearDown(untouched.close);
    final rows = await untouched.query('summaries');

    expect(rows.single['id'], 'summary-legacy');
    expect(rows.single.containsKey('title'), isFalse);
    expect(await untouched.getVersion(), 3);
  });
}
