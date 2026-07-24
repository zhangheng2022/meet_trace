import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/model_installation.dart';
import '../../domain/models/workflow_states.dart';
import '../models/storage/storage_mappers.dart';
import '../services/storage/app_database.dart';
import 'repository_contracts.dart';

final class SqfliteModelInstallationRepository
    implements ActiveModelInstallationRepository {
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
    await db.transaction((txn) async {
      await _upsert(txn, installation);
    });
    _changes.add(null);
  }

  @override
  Future<String?> getActiveVersion(String modelId) async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'active_model_versions',
      columns: ['version'],
      where: 'model_id = ?',
      whereArgs: [modelId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['version']! as String;
  }

  @override
  Future<void> saveInstalledAndActivate(ModelInstallation installation) async {
    if (installation.state != ModelInstallationState.installed) {
      throw ArgumentError.value(
        installation.state,
        'installation',
        '只有 installed 状态可以激活',
      );
    }
    final db = await _appDatabase.open();
    await db.transaction((txn) async {
      await _upsert(txn, installation);
      final row = {
        'model_id': installation.modelId,
        'version': installation.version,
      };
      final updated = await txn.update(
        'active_model_versions',
        row,
        where: 'model_id = ?',
        whereArgs: [installation.modelId],
      );
      if (updated == 0) {
        await txn.insert('active_model_versions', row);
      }
    });
    _changes.add(null);
  }

  @override
  Future<void> deleteAndDeactivate({
    required String modelId,
    required String version,
  }) async {
    final db = await _appDatabase.open();
    await db.transaction((txn) async {
      await txn.delete(
        'active_model_versions',
        where: 'model_id = ? AND version = ?',
        whereArgs: [modelId, version],
      );
      await txn.delete(
        'model_installations',
        where: 'model_id = ? AND version = ?',
        whereArgs: [modelId, version],
      );
    });
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}

Future<void> _upsert(
  DatabaseExecutor executor,
  ModelInstallation installation,
) async {
  final row = modelInstallationToRow(installation);
  final updated = await executor.update(
    'model_installations',
    row,
    where: 'model_id = ? AND version = ?',
    whereArgs: [installation.modelId, installation.version],
  );
  if (updated == 0) {
    await executor.insert('model_installations', row);
  }
}
