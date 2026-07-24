import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/repositories/sqflite_model_preference_repository.dart';
import 'package:meetily_ai/data/services/storage/app_database.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
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
    expect(await repository.getDefaultModelId(), paraformerStandardModelId);
  });

  test('保存高级默认模型并持久化读取', () async {
    await repository.setDefaultModelId(qwenAdvancedModelId);

    expect(await repository.getDefaultModelId(), qwenAdvancedModelId);
  });

  test('拒绝 Registry 外的模型 ID', () async {
    expect(
      () => repository.setDefaultModelId('unknown-model'),
      throwsArgumentError,
    );
  });
}
