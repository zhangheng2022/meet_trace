import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx_asr_engine_factory.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_adapter.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_asr_engine.dart';
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

  test('只按锁定的 SenseVoice ID、版本和配置创建 Engine', () async {
    final descriptor = AsrModelRegistry.alpha.requireById(
      senseVoiceDefaultModelId,
    );
    installations.install(_installed(descriptor));
    final workers = _WorkerFactory();
    final factory = _factory(installations, leases, workerFactory: workers);

    final engine = await factory.create(
      modelId: descriptor.modelId,
      modelVersion: descriptor.version,
    );

    expect(engine, isA<SherpaOnnxAsrEngine>());
    expect(engine.descriptor, same(descriptor));
    await engine.initialize();
    expect(workers.configs.single.kind, SherpaOnnxRecognizerKind.senseVoice);
    expect(workers.configs.single.language, 'auto');
    expect(workers.configs.single.useInverseTextNormalization, isTrue);
    await engine.dispose();
  });

  test('Factory 将设备风险监控传给 Engine', () async {
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    installations.install(_installed(descriptor));
    final riskMonitor = _TrackingRiskMonitor();
    final engine = await _factory(
      installations,
      leases,
      workerFactory: _WorkerFactory(),
      riskMonitor: riskMonitor,
    ).create(modelId: descriptor.modelId, modelVersion: descriptor.version);

    await engine.initialize();

    expect(riskMonitor.inspectCalls, 1);
    await engine.dispose();
  });

  test('拒绝状态或字节数不匹配的安装记录', () async {
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    installations.install(
      ModelInstallation(
        modelId: descriptor.modelId,
        version: descriptor.version,
        installationType: descriptor.installationType,
        state: ModelInstallationState.failed,
        bytes: 0,
      ),
    );

    await expectLater(
      _factory(
        installations,
        leases,
      ).create(modelId: descriptor.modelId, modelVersion: descriptor.version),
      throwsA(
        isA<AsrEngineException>().having(
          (error) => error.failure.code,
          'code',
          'asr.senseVoice.model_not_verified',
        ),
      ),
    );
  });

  test('Registry 版本不匹配时在读取安装记录前拒绝创建', () async {
    final factory = _factory(installations, leases);

    await expectLater(
      factory.create(
        modelId: senseVoiceDefaultModelId,
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

  test('锁定配置不匹配时拒绝创建且不自动改写配置', () async {
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    installations.install(_installed(descriptor));
    final factory = _factory(installations, leases);

    await expectLater(
      factory.create(
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        language: 'zh',
      ),
      throwsA(
        isA<AsrEngineException>()
            .having(
              (error) => error.failure.code,
              'code',
              'asr.factory.configuration_mismatch',
            )
            .having(
              (error) => error.failure.modelId,
              'modelId',
              descriptor.modelId,
            ),
      ),
    );
  });
}

SherpaOnnxAsrEngineFactory _factory(
  _MemoryInstallations installations,
  _MemoryLeases leases, {
  SherpaOnnxWorkerFactory workerFactory =
      const OfficialSherpaOnnxWorkerFactory(),
  AsrDeviceRiskMonitor riskMonitor = const _SupportedRiskMonitor(),
}) {
  return SherpaOnnxAsrEngineFactory(
    installations: installations,
    leases: leases,
    riskMonitor: riskMonitor,
    ownerId: 'meeting-11',
    workerFactory: workerFactory,
  );
}

final class _TrackingRiskMonitor implements AsrDeviceRiskMonitor {
  int inspectCalls = 0;

  @override
  Stream<AsrDeviceRiskState> get changes => const Stream.empty();

  @override
  Future<AsrDeviceRiskState> inspect() async {
    inspectCalls++;
    return const AsrDeviceRiskState.supported();
  }
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

final class _WorkerFactory implements SherpaOnnxWorkerFactory {
  final List<SherpaOnnxRecognizerConfig> configs = [];

  @override
  Future<SherpaOnnxWorker> create(SherpaOnnxRecognizerConfig config) async {
    configs.add(config);
    return const _Worker();
  }
}

final class _Worker implements SherpaOnnxWorker {
  const _Worker();

  @override
  Future<SherpaOnnxRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  }) async => SherpaOnnxRecognition(
    text: '测试',
    sampleCount: samples.length,
    elapsed: Duration.zero,
  );

  @override
  Future<void> dispose() async {}
}
