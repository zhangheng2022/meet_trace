import '../../domain/ports/runtime_asset_preparation.dart';
import '../services/storage/app_database.dart';

final class SqfliteRuntimeDownloadConsentRepository
    implements RuntimeDownloadConsentRepository {
  const SqfliteRuntimeDownloadConsentRepository(this._database);

  static const _key = 'runtime_mobile_download_consent';
  final AppDatabase _database;

  @override
  Future<bool> hasConsent(String resourceSetId) async {
    final db = await _database.open();
    final rows = await db.query(
      'app_settings',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [_key],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['value'] == resourceSetId;
  }

  @override
  Future<void> grant(String resourceSetId) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      final values = <String, Object?>{
        'value': resourceSetId,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      };
      final updated = await txn.update(
        'app_settings',
        values,
        where: 'key = ?',
        whereArgs: const [_key],
      );
      if (updated == 0) {
        await txn.insert('app_settings', {'key': _key, ...values});
      }
    });
  }
}
