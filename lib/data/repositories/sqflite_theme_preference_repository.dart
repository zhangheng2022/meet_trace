import '../../domain/models/app_theme.dart';
import '../../domain/ports/repositories.dart';
import '../services/storage/app_database.dart';

final class SqfliteThemePreferenceRepository
    implements ThemePreferenceRepository {
  const SqfliteThemePreferenceRepository(this._appDatabase);

  static const _themeModeKey = 'theme_mode';

  final AppDatabase _appDatabase;

  @override
  Future<AppThemeMode> getThemeMode() async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'app_settings',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [_themeModeKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return AppThemeMode.system;
    }
    final value = rows.single['value'];
    return AppThemeMode.values
            .where((mode) => mode.name == value)
            .firstOrNull ??
        AppThemeMode.system;
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
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
        whereArgs: const [_themeModeKey],
      );
      if (updated == 0) {
        await txn.insert('app_settings', {'key': _themeModeKey, ...row});
      }
    });
  }
}
