import '../../domain/models/asr_model_registry.dart';
import '../services/storage/app_database.dart';
import '../../domain/ports/repositories.dart';

final class SqfliteModelPreferenceRepository
    implements ModelPreferenceRepository {
  SqfliteModelPreferenceRepository(this._appDatabase, {required this.registry});

  static const _defaultModelKey = 'default_asr_model_id';

  final AppDatabase _appDatabase;
  final AsrModelRegistry registry;

  @override
  Future<String> getDefaultModelId() async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'app_settings',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [_defaultModelKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return registry.defaultModelId;
    }
    final modelId = rows.single['value']! as String;
    registry.requireById(modelId);
    return modelId;
  }

  @override
  Future<void> setDefaultModelId(String modelId) async {
    registry.requireById(modelId);
    final db = await _appDatabase.open();
    await db.transaction((txn) async {
      final row = <String, Object?>{
        'value': modelId,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      };
      final updated = await txn.update(
        'app_settings',
        row,
        where: 'key = ?',
        whereArgs: const [_defaultModelKey],
      );
      if (updated == 0) {
        await txn.insert('app_settings', {'key': _defaultModelKey, ...row});
      }
    });
  }
}
