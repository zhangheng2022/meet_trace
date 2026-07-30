import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/repository_contracts.dart';
import 'package:meettrace/data/services/asr/asr_engine.dart';
import 'package:meettrace/data/services/asr/whisper_base_standard_asr_engine.dart';
import 'package:meettrace/data/services/asr/whisper_small_advanced_asr_engine.dart';
import 'package:meettrace/data/services/asr/whisper_asr_engine_factory.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/model_usage_lease.dart';
import 'package:meettrace/domain/models/workflow_states.dart';

void main() {
  late _MemoryInstallations installations;
  late _MemoryLeases leases;

  setUp(() {
    installations = _MemoryInstallations();
    leases = _MemoryLeases();
  });

  test('只按锁定的标准模型 ID 和版本创建 Whisper Base Engine', () async {
    final descriptor = AsrModelRegistry.alpha.requireById(
      whisperBaseStandardModelId,
    );
    installations.install(_installed(descriptor));
    final factory = _factory(installations, leases);

    final engine = await factory.create(
      modelId: descriptor.modelId,
      modelVersion: descriptor.version,
    );

    expect(engine, isA<WhisperBaseStandardAsrEngine>());
    expect(engine.descriptor, same(descriptor));
    await engine.dispose();
  });

  test('只按锁定的高级模型 ID 和活动版本创建 Whisper Small Engine', () async {
    final standard = AsrModelRegistry.alpha.requireById(
      whisperBaseStandardModelId,
    );
    installations.install(_installed(standard));
    final descriptor = AsrModelRegistry.alpha.requireById(
      whisperSmallAdvancedModelId,
    );
    installations.install(_installed(descriptor), active: true);
    final factory = _factory(installations, leases);

    final engine = await factory.create(
      modelId: descriptor.modelId,
      modelVersion: descriptor.version,
    );

    expect(engine, isA<WhisperSmallAdvancedAsrEngine>());
    expect(engine.descriptor, same(descriptor));
    expect(leases.saved.single.ownerId, 'meeting-11');
    await engine.dispose();
    expect(leases.released, [leases.saved.single.leaseId]);
  });

  test('高级模型缺少随包 VAD 安装时拒绝创建且不获取租约', () async {
    final descriptor = AsrModelRegistry.alpha.requireById(
      whisperSmallAdvancedModelId,
    );
    installations.install(_installed(descriptor), active: true);
    final factory = _factory(installations, leases);

    await expectLater(
      factory.create(
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
      ),
      throwsA(
        isA<AsrEngineException>().having(
          (error) => error.failure.code,
          'code',
          'asr.factory.vad_model_not_verified',
        ),
      ),
    );
    expect(leases.saved, isEmpty);
  });

  test('高级模型拒绝复用未验证的随包 VAD 安装且不获取租约', () async {
    final standard = AsrModelRegistry.alpha.requireById(
      whisperBaseStandardModelId,
    );
    installations.install(
      ModelInstallation(
        modelId: standard.modelId,
        version: standard.version,
        installationType: standard.installationType,
        state: ModelInstallationState.failed,
        installedPath: 'models/${standard.modelId}/${standard.version}',
        verifiedAt: DateTime.utc(2026, 7, 24),
        bytes: standard.requiredBytes,
        lastErrorCode: 'checksum_mismatch',
      ),
    );
    final advanced = AsrModelRegistry.alpha.requireById(
      whisperSmallAdvancedModelId,
    );
    installations.install(_installed(advanced), active: true);
    final factory = _factory(installations, leases);

    await expectLater(
      factory.create(modelId: advanced.modelId, modelVersion: advanced.version),
      throwsA(
        isA<AsrEngineException>().having(
          (error) => error.failure.code,
          'code',
          'asr.factory.vad_model_not_verified',
        ),
      ),
    );
    expect(leases.saved, isEmpty);
  });

  test('Registry 版本不匹配时在读取安装记录前拒绝创建', () async {
    final factory = _factory(installations, leases);

    await expectLater(
      factory.create(
        modelId: whisperBaseStandardModelId,
        modelVersion: 'wrong-version',
      ),
      throwsA(
        isA<AsrEngineException>()
            .having(
              (error) => error.failure.code,
              'code',
              'asr.factory.version_mismatch',
            )
            .having(
              (error) => error.failure.modelVersion,
              'modelVersion',
              'wrong-version',
            ),
      ),
    );
    expect(installations.getCalls, 0);
  });

  test('高级模型不可用时返回高级模型错误且不自动创建标准模型', () async {
    final standard = AsrModelRegistry.alpha.requireById(
      whisperBaseStandardModelId,
    );
    installations.install(_installed(standard));
    final small = AsrModelRegistry.alpha.requireById(
      whisperSmallAdvancedModelId,
    );
    final factory = _factory(installations, leases);

    await expectLater(
      factory.create(modelId: small.modelId, modelVersion: small.version),
      throwsA(
        isA<AsrEngineException>()
            .having(
              (error) => error.failure.code,
              'code',
              'asr.whisper_small.model_not_active',
            )
            .having((error) => error.failure.modelId, 'modelId', small.modelId),
      ),
    );
    expect(leases.saved, isEmpty);
  });
}

WhisperAsrEngineFactory _factory(
  _MemoryInstallations installations,
  _MemoryLeases leases,
) {
  return WhisperAsrEngineFactory(
    installations: installations,
    leases: leases,
    riskMonitor: const _SupportedRiskMonitor(),
    ownerId: 'meeting-11',
  );
}

ModelInstallation _installed(AsrModelDescriptor descriptor) {
  return ModelInstallation(
    modelId: descriptor.modelId,
    version: descriptor.version,
    installationType: descriptor.installationType,
    state: ModelInstallationState.installed,
    installedPath: 'models/${descriptor.modelId}/${descriptor.version}',
    verifiedAt: DateTime.utc(2026, 7, 24),
    bytes: descriptor.requiredBytes,
  );
}

final class _MemoryInstallations implements ActiveModelInstallationRepository {
  final Map<String, ModelInstallation> _records = {};
  final Map<String, String> _activeVersions = {};
  int getCalls = 0;

  void install(ModelInstallation installation, {bool active = false}) {
    _records[_key(installation.modelId, installation.version)] = installation;
    if (active) {
      _activeVersions[installation.modelId] = installation.version;
    }
  }

  @override
  Future<ModelInstallation?> get({
    required String modelId,
    required String version,
  }) async {
    getCalls++;
    return _records[_key(modelId, version)];
  }

  @override
  Future<String?> getActiveVersion(String modelId) async {
    return _activeVersions[modelId];
  }

  @override
  Future<void> save(ModelInstallation installation) async {
    install(installation);
  }

  @override
  Future<void> saveInstalledAndActivate(ModelInstallation installation) async {
    install(installation, active: true);
  }

  @override
  Future<void> deleteAndDeactivate({
    required String modelId,
    required String version,
  }) async {
    _records.remove(_key(modelId, version));
    if (_activeVersions[modelId] == version) {
      _activeVersions.remove(modelId);
    }
  }

  @override
  Stream<List<ModelInstallation>> watchAll() {
    return Stream.value(List.unmodifiable(_records.values));
  }

  String _key(String modelId, String version) => '$modelId@$version';
}

final class _MemoryLeases implements ModelUsageLeaseRepository {
  final List<ModelUsageLease> saved = [];
  final List<String> released = [];

  @override
  Future<void> save(ModelUsageLease lease) async {
    saved.add(lease);
  }

  @override
  Future<void> release(String leaseId) async {
    released.add(leaseId);
  }

  @override
  Future<List<ModelUsageLease>> listActive({
    required String modelId,
    required String version,
    required DateTime now,
  }) async {
    return saved
        .where(
          (lease) =>
              lease.modelId == modelId &&
              lease.version == version &&
              lease.isActiveAt(now),
        )
        .toList(growable: false);
  }

  @override
  Future<int> deleteExpired(DateTime now) async => 0;
}

final class _SupportedRiskMonitor implements AsrDeviceRiskMonitor {
  const _SupportedRiskMonitor();

  @override
  Stream<AsrDeviceRiskState> get changes => const Stream.empty();

  @override
  Future<AsrDeviceRiskState> inspect() async {
    return const AsrDeviceRiskState.supported();
  }
}
