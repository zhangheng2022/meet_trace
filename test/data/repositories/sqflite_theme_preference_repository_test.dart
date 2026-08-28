import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_theme_preference_repository.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/domain/models/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SqfliteThemePreferenceRepository repository;

  setUp(() {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqfliteThemePreferenceRepository(database);
  });

  tearDown(() => database.close());

  test('没有设置时默认跟随系统', () async {
    expect(await repository.getThemeMode(), AppThemeMode.system);
  });

  test('保存并读取浅色和深色主题', () async {
    await repository.setThemeMode(AppThemeMode.light);
    expect(await repository.getThemeMode(), AppThemeMode.light);

    await repository.setThemeMode(AppThemeMode.dark);
    expect(await repository.getThemeMode(), AppThemeMode.dark);
  });

  test('未知主题值回退跟随系统', () async {
    final db = await database.open();
    await db.insert('app_settings', {
      'key': 'theme_mode',
      'value': 'unknown',
      'updated_at': 0,
    });

    expect(await repository.getThemeMode(), AppThemeMode.system);
  });
}
