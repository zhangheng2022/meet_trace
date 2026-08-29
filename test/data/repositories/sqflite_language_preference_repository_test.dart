import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_language_preference_repository.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/domain/models/app_language.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SqfliteLanguagePreferenceRepository repository;

  setUp(() {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqfliteLanguagePreferenceRepository(database);
  });

  tearDown(() => database.close());

  test('没有设置时默认跟随系统', () async {
    expect(await repository.getLanguageMode(), AppLanguageMode.system);
  });

  test('保存并读取简体中文和英文', () async {
    await repository.setLanguageMode(AppLanguageMode.simplifiedChinese);
    expect(
      await repository.getLanguageMode(),
      AppLanguageMode.simplifiedChinese,
    );

    await repository.setLanguageMode(AppLanguageMode.english);
    expect(await repository.getLanguageMode(), AppLanguageMode.english);
  });

  test('未知语言值回退跟随系统', () async {
    final db = await database.open();
    await db.insert('app_settings', {
      'key': 'language_mode',
      'value': 'unknown',
      'updated_at': 0,
    });

    expect(await repository.getLanguageMode(), AppLanguageMode.system);
  });
}
