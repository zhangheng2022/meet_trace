import 'dart:async';

import '../../domain/models/model_installation.dart';
import '../models/storage/storage_mappers.dart';
import '../services/storage/app_database.dart';
import 'repository_contracts.dart';

final class SqfliteModelInstallationRepository
    implements ModelInstallationRepository {
  SqfliteModelInstallationRepository(this._appDatabase);

  final AppDatabase _appDatabase;
  final StreamController<void> _changes = StreamController.broadcast();

  @override
  Future<ModelInstallation?> get({
    required String modelId,
    required String version,
  }) async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'model_installations',
      where: 'model_id = ? AND version = ?',
      whereArgs: [modelId, version],
      limit: 1,
    );
    return rows.isEmpty ? null : modelInstallationFromRow(rows.single);
  }

  Future<List<ModelInstallation>> listAll() async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'model_installations',
      orderBy: 'model_id, version',
    );
    return List.unmodifiable(rows.map(modelInstallationFromRow));
  }

  @override
  Stream<List<ModelInstallation>> watchAll() async* {
    yield await listAll();
    await for (final _ in _changes.stream) {
      yield await listAll();
    }
  }

  @override
  Future<void> save(ModelInstallation installation) async {
    final db = await _appDatabase.open();
    final row = modelInstallationToRow(installation);
    await db.transaction((txn) async {
      final updated = await txn.update(
        'model_installations',
        row,
        where: 'model_id = ? AND version = ?',
        whereArgs: [installation.modelId, installation.version],
      );
      if (updated == 0) {
        await txn.insert('model_installations', row);
      }
    });
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
