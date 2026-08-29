import '../../domain/models/app_language.dart';
import '../../domain/ports/repositories.dart';
import '../services/storage/app_database.dart';

final class SqfliteLanguagePreferenceRepository
    implements LanguagePreferenceRepository {
  const SqfliteLanguagePreferenceRepository(this._appDatabase);

  static const _languageModeKey = 'language_mode';

  final AppDatabase _appDatabase;

  @override
  Future<AppLanguageMode> getLanguageMode() async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'app_settings',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [_languageModeKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return AppLanguageMode.system;
    }
    final value = rows.single['value'];
    return AppLanguageMode.values
            .where((mode) => mode.name == value)
            .firstOrNull ??
        AppLanguageMode.system;
  }

  @override
  Future<void> setLanguageMode(AppLanguageMode mode) async {
    final db = await _appDatabase.open();
    await db.transaction((txn) async {
      final row = <String, Object?>{
        'value': mode.name,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      };
      final updated = await txn.update(
        'app_settings',
        row,
        where: 'key = ?',
        whereArgs: const [_languageModeKey],
      );
      if (updated == 0) {
        await txn.insert('app_settings', {'key': _languageModeKey, ...row});
      }
    });
  }
}
