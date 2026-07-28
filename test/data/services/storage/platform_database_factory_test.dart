import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/storage/platform_database_factory.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test('Windows 数据库工厂已初始化并可打开 SQLite 数据库', () async {
    final factory = createPlatformDatabaseFactory(operatingSystem: 'windows');
    final database = await factory.openDatabase(inMemoryDatabasePath);
    addTearDown(database.close);

    final rows = await database.rawQuery('SELECT 1 AS value');

    expect(rows.single['value'], 1);
  });
}
