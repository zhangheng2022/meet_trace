import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_model_preference_repository.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SqfliteModelPreferenceRepository repository;

  setUp(() {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqfliteModelPreferenceRepository(
      database,
      registry: AsrModelRegistry.alpha,
    );
  });

  tearDown(() => database.close());

  test('没有设置时返回标准模型初始值', () async {
    expect(await repository.getDefaultModelId(), whisperBaseStandardModelId);
  });

  test('保存高级默认模型并持久化读取', () async {
    await repository.setDefaultModelId(whisperSmallAdvancedModelId);

    expect(await repository.getDefaultModelId(), whisperSmallAdvancedModelId);
  });

  test('拒绝 Registry 外的模型 ID', () async {
    expect(
      () => repository.setDefaultModelId('unknown-model'),
      throwsArgumentError,
    );
  });

  test('升级时把旧 sherpa 默认模型迁移到对应 Whisper 模型', () async {
    final db = await database.open();
    await db.insert('app_settings', {
      'key': 'default_asr_model_id',
      'value': 'sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25',
      'updated_at': 1,
    });

    expect(await repository.getDefaultModelId(), whisperSmallAdvancedModelId);

    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['default_asr_model_id'],
    );
    expect(rows.single['value'], whisperSmallAdvancedModelId);
  });
}
