import '../services/storage/app_database.dart';
import 'repository_contracts.dart';

final class SqfliteDiarizationPreferenceRepository
    implements DiarizationPreferenceRepository {
  SqfliteDiarizationPreferenceRepository(this._appDatabase);

  static const _enabledKey = 'speaker_diarization_enabled';

  final AppDatabase _appDatabase;

  @override
  Future<bool> getEnabled() async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'app_settings',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [_enabledKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    return rows.single['value'] == 'true';
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final db = await _appDatabase.open();
    await db.transaction((txn) async {
      final row = <String, Object?>{
        'value': enabled.toString(),
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      };
      final updated = await txn.update(
        'app_settings',
        row,
        where: 'key = ?',
        whereArgs: const [_enabledKey],
      );
      if (updated == 0) {
        await txn.insert('app_settings', {'key': _enabledKey, ...row});
      }
    });
  }
}
