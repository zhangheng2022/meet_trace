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

  test('没有设置时返回 SenseVoice 初始值', () async {
    expect(await repository.getDefaultModelId(), senseVoiceDefaultModelId);
  });

  test('保存高级默认模型并持久化读取', () async {
    await repository.setDefaultModelId(senseVoiceDefaultModelId);

    expect(await repository.getDefaultModelId(), senseVoiceDefaultModelId);
  });

  test('拒绝 Registry 外的模型 ID', () async {
    expect(
      () => repository.setDefaultModelId('unknown-model'),
      throwsArgumentError,
    );
  });
}
