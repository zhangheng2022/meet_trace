import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/repositories/sqflite_model_installation_repository.dart';
import 'package:meetily_ai/data/repositories/sqflite_model_usage_lease_repository.dart';
import 'package:meetily_ai/data/services/storage/app_database.dart';
import 'package:meetily_ai/domain/models/asr_model.dart';
import 'package:meetily_ai/domain/models/model_installation.dart';
import 'package:meetily_ai/domain/models/model_usage_lease.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SqfliteModelInstallationRepository installations;
  late SqfliteModelUsageLeaseRepository leases;

  setUp(() async {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await database.open();
    installations = SqfliteModelInstallationRepository(database);
    leases = SqfliteModelUsageLeaseRepository(database);
  });

  tearDown(() async {
    await installations.dispose();
    await database.close();
  });

  test('安装记录与活动版本在同一事务中切换且保留旧版本', () async {
    await installations.saveInstalledAndActivate(_installation('1'));
    await installations.saveInstalledAndActivate(_installation('2'));

    expect(await installations.getActiveVersion('qwen'), '2');
    expect(await installations.get(modelId: 'qwen', version: '1'), isNotNull);
    expect(await installations.get(modelId: 'qwen', version: '2'), isNotNull);
  });

  test('租约仅在到期前阻止对应模型版本删除', () async {
    final now = DateTime.utc(2026, 7, 24, 12);
    await installations.saveInstalledAndActivate(_installation('2'));
    await leases.save(
      ModelUsageLease(
        leaseId: 'lease-1',
        modelId: 'qwen',
        version: '2',
        ownerId: 'meeting-1',
        acquiredAt: now.subtract(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(minutes: 5)),
      ),
    );

    expect(
      await leases.listActive(modelId: 'qwen', version: '2', now: now),
      hasLength(1),
    );
    expect(
      await leases.listActive(
        modelId: 'qwen',
        version: '2',
        now: now.add(const Duration(minutes: 6)),
      ),
      isEmpty,
    );
    expect(await leases.deleteExpired(now.add(const Duration(minutes: 6))), 1);
  });

  test('删除安装记录时仅取消匹配的活动版本', () async {
    await installations.saveInstalledAndActivate(_installation('1'));
    await installations.saveInstalledAndActivate(_installation('2'));

    await installations.deleteAndDeactivate(modelId: 'qwen', version: '1');
    expect(await installations.getActiveVersion('qwen'), '2');

    await installations.deleteAndDeactivate(modelId: 'qwen', version: '2');
    expect(await installations.getActiveVersion('qwen'), isNull);
    expect(await installations.get(modelId: 'qwen', version: '2'), isNull);
  });
}

ModelInstallation _installation(String version) {
  return ModelInstallation(
    modelId: 'qwen',
    version: version,
    installationType: AsrInstallationType.downloadable,
    state: ModelInstallationState.installed,
    installedPath: '/models/qwen/$version',
    verifiedAt: DateTime.utc(2026, 7, 24),
    bytes: 10,
  );
}
