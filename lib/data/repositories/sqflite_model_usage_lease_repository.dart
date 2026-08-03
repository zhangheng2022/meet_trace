import '../../domain/models/model_usage_lease.dart';
import '../services/storage/app_database.dart';
import '../../domain/ports/repositories.dart';

final class SqfliteModelUsageLeaseRepository
    implements ModelUsageLeaseRepository {
  SqfliteModelUsageLeaseRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> save(ModelUsageLease lease) async {
    final db = await _appDatabase.open();
    final row = _toRow(lease);
    final updated = await db.update(
      'model_usage_leases',
      row,
      where: 'lease_id = ?',
      whereArgs: [lease.leaseId],
    );
    if (updated == 0) {
      await db.insert('model_usage_leases', row);
    }
  }

  @override
  Future<void> release(String leaseId) async {
    final db = await _appDatabase.open();
    await db.delete(
      'model_usage_leases',
      where: 'lease_id = ?',
      whereArgs: [leaseId],
    );
  }

  @override
  Future<List<ModelUsageLease>> listActive({
    required String modelId,
    required String version,
    required DateTime now,
  }) async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'model_usage_leases',
      where: 'model_id = ? AND version = ? AND expires_at > ?',
      whereArgs: [modelId, version, now.toUtc().millisecondsSinceEpoch],
      orderBy: 'expires_at, lease_id',
    );
    return List.unmodifiable(rows.map(_fromRow));
  }

  @override
  Future<int> deleteExpired(DateTime now) async {
    final db = await _appDatabase.open();
    return db.delete(
      'model_usage_leases',
      where: 'expires_at <= ?',
      whereArgs: [now.toUtc().millisecondsSinceEpoch],
    );
  }
}

Map<String, Object?> _toRow(ModelUsageLease lease) {
  return {
    'lease_id': lease.leaseId,
    'model_id': lease.modelId,
    'version': lease.version,
    'owner_id': lease.ownerId,
    'acquired_at': lease.acquiredAt.toUtc().millisecondsSinceEpoch,
    'expires_at': lease.expiresAt.toUtc().millisecondsSinceEpoch,
  };
}

ModelUsageLease _fromRow(Map<String, Object?> row) {
  return ModelUsageLease(
    leaseId: row['lease_id']! as String,
    modelId: row['model_id']! as String,
    version: row['version']! as String,
    ownerId: row['owner_id']! as String,
    acquiredAt: DateTime.fromMillisecondsSinceEpoch(
      row['acquired_at']! as int,
      isUtc: true,
    ),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      row['expires_at']! as int,
      isUtc: true,
    ),
  );
}
