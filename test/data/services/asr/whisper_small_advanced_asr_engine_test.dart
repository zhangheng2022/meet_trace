import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/repository_contracts.dart';
import 'package:meettrace/data/services/asr/asr_engine.dart';
import 'package:meettrace/data/services/asr/whisper_small_advanced_asr_engine.dart';
import 'package:meettrace/data/services/asr/whisper/whisper_adapter.dart';
import 'package:meettrace/data/services/audio/recording_checkpoint_store.dart';
import 'package:meettrace/data/services/audio/recording_ports.dart';
import 'package:meettrace/data/services/audio/reliable_recording_service.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/domain/models/app_failure.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/model_usage_lease.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late _MemoryInstallations installations;
  late _MemoryLeases leases;
  late _RiskMonitor risks;
  late _FakeWorkerFactory workers;
  late DateTime clock;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'meettrace-whisper-small-engine-',
    );
    installations = _MemoryInstallations();
    leases = _MemoryLeases();
    risks = _RiskMonitor(const AsrDeviceRiskState.supported());
    workers = _FakeWorkerFactory();
    clock = DateTime.utc(2026, 7, 24, 12);
    _installActiveWhisperSmall(installations, tempDirectory.path);
  });

  tearDown(() async {
    await risks.close();
    await tempDirectory.delete(recursive: true);
  });

  test('只从活动且已校验的高级版本创建配置并获取租约', () async {
    final engine = await _createEngine(
      installations: installations,
      leases: leases,
      risks: risks,
      workers: workers,
      now: () => clock,
    );

    await engine.initialize();

    expect(
      engine.descriptor,
      same(AsrModelRegistry.alpha.requireById(whisperSmallAdvancedModelId)),
    );
    final config = workers.configs.single;
    expect(config.modelPath, p.join(tempDirectory.path, 'ggml-small-q5_1.bin'));
    expect(leases.active.single.ownerId, 'meeting-1');

    await engine.dispose();
    expect(leases.active, isEmpty);
  });

  test('未安装、校验失败或非活动版本不能创建 Engine', () async {
    installations.activeVersions.clear();
    await expectLater(
      _createEngine(
        installations: installations,
        leases: leases,
        risks: risks,
        workers: workers,
        now: () => clock,
      ),
      throwsA(_engineFailure('asr.whisper_small.model_not_active')),
    );

    _installActiveWhisperSmall(installations, tempDirectory.path);
    final descriptor = AsrModelRegistry.alpha.requireById(
      whisperSmallAdvancedModelId,
    );
    installations.records[_key(
      descriptor.modelId,
      descriptor.version,
    )] = ModelInstallation(
      modelId: descriptor.modelId,
      version: descriptor.version,
      installationType: descriptor.installationType,
      state: ModelInstallationState.failed,
      bytes: descriptor.requiredBytes - 1,
      lastErrorCode: 'model.verification.sha256_mismatch',
    );
    await expectLater(
      _createEngine(
        installations: installations,
        leases: leases,
        risks: risks,
        workers: workers,
        now: () => clock,
      ),
      throwsA(_engineFailure('asr.whisper_small.model_not_verified')),
    );
    expect(workers.createCalls, 0);
    expect(leases.active, isEmpty);
  });

  test('同一 owner 的活动租约冲突时拒绝重复创建', () async {
    final descriptor = AsrModelRegistry.alpha.requireById(
      whisperSmallAdvancedModelId,
    );
    leases.active.add(
      ModelUsageLease(
        leaseId: 'existing',
        modelId: descriptor.modelId,
        version: descriptor.version,
        ownerId: 'meeting-1',
        acquiredAt: clock,
        expiresAt: clock.add(const Duration(minutes: 10)),
      ),
    );

    await expectLater(
      _createEngine(
        installations: installations,
        leases: leases,
        risks: risks,
        workers: workers,
        now: () => clock,
      ),
      throwsA(_engineFailure('asr.whisper_small.lease_conflict')),
    );
    expect(workers.createCalls, 0);
  });

  test('不支持设备、临界内存和临界温控分别阻止初始化', () async {
    final cases = <(AsrDeviceRiskState, String)>[
      (
        const AsrDeviceRiskState(
          support: AsrDeviceSupport.unsupported,
          memoryPressure: AsrMemoryPressure.normal,
          thermalState: AsrThermalState.nominal,
        ),
        'asr.whisper_small.device_unsupported',
      ),
      (
        const AsrDeviceRiskState(
          support: AsrDeviceSupport.supported,
          memoryPressure: AsrMemoryPressure.critical,
          thermalState: AsrThermalState.nominal,
        ),
        'asr.whisper_small.memory_pressure_critical',
      ),
      (
        const AsrDeviceRiskState(
          support: AsrDeviceSupport.supported,
          memoryPressure: AsrMemoryPressure.normal,
          thermalState: AsrThermalState.critical,
        ),
        'asr.whisper_small.thermal_critical',
      ),
    ];

    for (final (risk, errorCode) in cases) {
      final localLeases = _MemoryLeases();
      final localRisks = _RiskMonitor(risk);
      final engine = await _createEngine(
        installations: installations,
        leases: localLeases,
        risks: localRisks,
        workers: workers,
        now: () => clock,
        ownerId: errorCode,
      );
      await expectLater(
        engine.initialize(),
        throwsA(_engineFailure(errorCode)),
      );
      expect(engine.deviceRisk, same(risk));
      await engine.dispose();
      await localRisks.close();
    }
    expect(workers.createCalls, 0);
  });

  test('风险警告允许初始化，后续临界风险只阻止高级模型', () async {
    final warning = const AsrDeviceRiskState(
      support: AsrDeviceSupport.constrained,
      memoryPressure: AsrMemoryPressure.warning,
      thermalState: AsrThermalState.serious,
      processRssBytes: 2900000000,
    );
    risks.current = warning;
    final engine = await _createEngine(
      installations: installations,
      leases: leases,
      risks: risks,
      workers: workers,
      now: () => clock,
    );
    final observed = <AsrDeviceRiskState>[];
    final subscription = engine.deviceRisks.listen(observed.add);
    await engine.initialize();

    expect(engine.deviceRisk.hasWarning, true);
    risks.emit(
      const AsrDeviceRiskState(
        support: AsrDeviceSupport.constrained,
        memoryPressure: AsrMemoryPressure.warning,
        thermalState: AsrThermalState.critical,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      engine.acceptAudio(Float32List(16000), sampleRate: 16000, startMs: 0),
      throwsA(
        isA<AsrEngineException>()
            .having(
              (error) => error.failure.code,
              'code',
              'asr.whisper_small.thermal_critical',
            )
            .having(
              (error) => error.failure.stage,
              'stage',
              FailureStage.asrInference,
            ),
      ),
    );
    expect(engine.descriptor.modelId, whisperSmallAdvancedModelId);
    expect(observed.last.thermalState, AsrThermalState.critical);
    await subscription.cancel();
    await engine.dispose();
  });

  test('事件与最终快照协议可通过统一 AsrEngine 使用', () async {
    workers = _FakeWorkerFactory(results: const ['高级预览', '高级最终']);
    final engine = await _createEngine(
      installations: installations,
      leases: leases,
      risks: risks,
      workers: workers,
      now: () => clock,
    );
    final events = <TranscriptEvent>[];
    final subscription = engine.events.listen(events.add);
    await engine.initialize();
    await engine.acceptAudio(
      Float32List(16000),
      sampleRate: 16000,
      startMs: 42000,
    );
    final audio = File(p.join(tempDirectory.path, 'meeting.pcm'));
    await audio.writeAsBytes(Uint8List(32000), flush: true);

    final snapshot = await _finalizeThroughContract(
      engine,
      AudioSource(path: audio.path, durationMs: 1000),
    );

    final preview = events.first as TranscriptSegmentEvent;
    expect((preview.startMs, preview.endMs), (42000, 43000));
    expect(preview.modelId, whisperSmallAdvancedModelId);
    expect(snapshot.actualModelId, whisperSmallAdvancedModelId);
    expect(snapshot.actualModelVersion, engine.descriptor.version);
    expect(snapshot.segments.single.text, '高级最终');
    expect(snapshot.status, TranscriptSnapshotStatus.complete);
    await subscription.cancel();
    await engine.dispose();
  });

  test('超过 15 秒的输入不会进入 Whisper adapter', () async {
    final engine = await _createEngine(
      installations: installations,
      leases: leases,
      risks: risks,
      workers: workers,
      now: () => clock,
    );
    await engine.initialize();

    await expectLater(
      engine.acceptAudio(
        Float32List(15 * 16000 + 1),
        sampleRate: 16000,
        startMs: 0,
      ),
      throwsA(_engineFailure('asr.whisper_small.window_too_long')),
    );

    expect(workers.workers.single.recognizeCalls, 0);
    await engine.dispose();
  });

  test('推理失败保持高级模型身份且不触发自动模型切换', () async {
    workers = _FakeWorkerFactory(
      recognitionErrors: [StateError('out of memory')],
    );
    final engine = await _createEngine(
      installations: installations,
      leases: leases,
      risks: risks,
      workers: workers,
      now: () => clock,
    );
    await engine.initialize();

    await expectLater(
      engine.acceptAudio(Float32List(16000), sampleRate: 16000, startMs: 0),
      throwsA(_engineFailure('asr.whisper.inference_failed')),
    );

    expect(engine.descriptor.modelId, whisperSmallAdvancedModelId);
    expect(workers.configs.single.modelId, whisperSmallAdvancedModelId);
    expect(engine.metrics.failedWindowCount, 1);
    expect(engine.metrics.lastErrorCode, 'asr.whisper.inference_failed');
    await engine.dispose();
  });

  test('高级模型推理失败后可靠录音链仍继续写入事实音频', () async {
    workers = _FakeWorkerFactory(
      recognitionErrors: [StateError('out of memory')],
    );
    final engine = await _createEngine(
      installations: installations,
      leases: leases,
      risks: risks,
      workers: workers,
      now: () => clock,
    );
    final layout = AppFileLayout(
      rootPath: p.join(tempDirectory.path, 'recording-root'),
    );
    final capture = _FakeCapture();
    final recording = ReliableRecordingService(
      capture: capture,
      layout: layout,
      checkpoints: JsonRecordingCheckpointStore(layout),
      storageCapacity: const _FixedCapacity(512 * 1024 * 1024),
      audioLevelMeter: PcmAudioLevelMeter(),
      now: () => clock,
    );
    await engine.initialize();
    await recording.start(meetingId: 'meeting-recording');
    capture.add(Uint8List(3200));
    await _waitFor(() => recording.persistedBytes == 3200);

    await expectLater(
      engine.acceptAudio(Float32List(16000), sampleRate: 16000, startMs: 0),
      throwsA(_engineFailure('asr.whisper.inference_failed')),
    );
    capture.add(Uint8List(3200));
    await _waitFor(() => recording.persistedBytes == 6400);
    final artifact = await recording.stop();

    expect(artifact.bytes, 6400);
    expect(await File(artifact.audioPath).length(), 6400);
    expect(recording.state, RecordingState.completed);
    await engine.dispose();
  });

  test('识别前续租，dispose 同时释放大模型 worker 和租约', () async {
    final engine = await _createEngine(
      installations: installations,
      leases: leases,
      risks: risks,
      workers: workers,
      now: () => clock,
      leaseDuration: const Duration(minutes: 10),
      leaseRenewalLead: const Duration(minutes: 2),
    );
    await engine.initialize();
    final originalExpiry = leases.active.single.expiresAt;
    clock = clock.add(const Duration(minutes: 9));

    await engine.acceptAudio(Float32List(1600), sampleRate: 16000, startMs: 0);

    expect(leases.active.single.expiresAt.isAfter(originalExpiry), true);
    await engine.dispose();
    expect(workers.workers.single.disposeCalls, 1);
    expect(leases.active, isEmpty);
  });
}

Future<WhisperSmallAdvancedAsrEngine> _createEngine({
  required _MemoryInstallations installations,
  required _MemoryLeases leases,
  required _RiskMonitor risks,
  required _FakeWorkerFactory workers,
  required DateTime Function() now,
  String ownerId = 'meeting-1',
  Duration leaseDuration = const Duration(hours: 1),
  Duration leaseRenewalLead = const Duration(minutes: 5),
}) {
  return WhisperSmallAdvancedAsrEngine.create(
    installations: installations,
    leases: leases,
    riskMonitor: risks,
    ownerId: ownerId,
    workerFactory: workers,
    now: now,
    leaseDuration: leaseDuration,
    leaseRenewalLead: leaseRenewalLead,
  );
}

Future<TranscriptSnapshot> _finalizeThroughContract(
  AsrEngine engine,
  AudioSource source,
) {
  return engine.finalizeMeeting(source, meetingId: 'meeting-1');
}

Matcher _engineFailure(String code) {
  return isA<AsrEngineException>().having(
    (error) => error.failure.code,
    'code',
    code,
  );
}

void _installActiveWhisperSmall(
  _MemoryInstallations installations,
  String installedPath,
) {
  final descriptor = AsrModelRegistry.alpha.requireById(
    whisperSmallAdvancedModelId,
  );
  installations.activeVersions[descriptor.modelId] = descriptor.version;
  installations.records[_key(
    descriptor.modelId,
    descriptor.version,
  )] = ModelInstallation(
    modelId: descriptor.modelId,
    version: descriptor.version,
    installationType: descriptor.installationType,
    state: ModelInstallationState.installed,
    installedPath: installedPath,
    verifiedAt: DateTime.utc(2026, 7, 24),
    bytes: descriptor.requiredBytes,
  );
}

String _key(String modelId, String version) => '$modelId@$version';

final class _MemoryInstallations implements ActiveModelInstallationRepository {
  final Map<String, ModelInstallation> records = {};
  final Map<String, String> activeVersions = {};

  @override
  Future<ModelInstallation?> get({
    required String modelId,
    required String version,
  }) async {
    return records[_key(modelId, version)];
  }

  @override
  Future<String?> getActiveVersion(String modelId) async {
    return activeVersions[modelId];
  }

  @override
  Future<void> save(ModelInstallation installation) async {
    records[_key(installation.modelId, installation.version)] = installation;
  }

  @override
  Future<void> saveInstalledAndActivate(ModelInstallation installation) async {
    await save(installation);
    activeVersions[installation.modelId] = installation.version;
  }

  @override
  Future<void> deleteAndDeactivate({
    required String modelId,
    required String version,
  }) async {
    records.remove(_key(modelId, version));
    if (activeVersions[modelId] == version) {
      activeVersions.remove(modelId);
    }
  }

  @override
  Stream<List<ModelInstallation>> watchAll() {
    return Stream.value(List.unmodifiable(records.values));
  }
}

final class _MemoryLeases implements ModelUsageLeaseRepository {
  final List<ModelUsageLease> active = [];

  @override
  Future<void> save(ModelUsageLease lease) async {
    active
      ..removeWhere((item) => item.leaseId == lease.leaseId)
      ..add(lease);
  }

  @override
  Future<void> release(String leaseId) async {
    active.removeWhere((item) => item.leaseId == leaseId);
  }

  @override
  Future<List<ModelUsageLease>> listActive({
    required String modelId,
    required String version,
    required DateTime now,
  }) async {
    return active
        .where(
          (lease) =>
              lease.modelId == modelId &&
              lease.version == version &&
              lease.expiresAt.isAfter(now),
        )
        .toList(growable: false);
  }

  @override
  Future<int> deleteExpired(DateTime now) async {
    final before = active.length;
    active.removeWhere((lease) => !lease.expiresAt.isAfter(now));
    return before - active.length;
  }
}

final class _RiskMonitor implements AsrDeviceRiskMonitor {
  _RiskMonitor(this.current);

  AsrDeviceRiskState current;
  final StreamController<AsrDeviceRiskState> _changes =
      StreamController<AsrDeviceRiskState>.broadcast(sync: true);

  @override
  Stream<AsrDeviceRiskState> get changes => _changes.stream;

  @override
  Future<AsrDeviceRiskState> inspect() async => current;

  void emit(AsrDeviceRiskState risk) {
    current = risk;
    _changes.add(risk);
  }

  Future<void> close() => _changes.close();
}

final class _FakeWorkerFactory implements WhisperWorkerFactory {
  _FakeWorkerFactory({
    this.results = const ['高级结果'],
    this.recognitionErrors = const [],
  });

  final List<String> results;
  final List<Object?> recognitionErrors;
  final List<WhisperRecognizerConfig> configs = [];
  final List<_FakeWorker> workers = [];
  int createCalls = 0;

  @override
  Future<WhisperWorker> create(WhisperRecognizerConfig config) async {
    createCalls++;
    configs.add(config);
    final worker = _FakeWorker(
      results: results,
      recognitionErrors: recognitionErrors,
    );
    workers.add(worker);
    return worker;
  }
}

final class _FakeWorker implements WhisperWorker {
  _FakeWorker({required this.results, required this.recognitionErrors});

  final List<String> results;
  final List<Object?> recognitionErrors;
  int recognizeCalls = 0;
  int disposeCalls = 0;

  @override
  int get nativeContextAddress => 1;

  @override
  Future<WhisperRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  }) async {
    final call = recognizeCalls++;
    final error = call < recognitionErrors.length
        ? recognitionErrors[call]
        : null;
    if (error != null) {
      throw error;
    }
    return WhisperRecognition(
      text: call < results.length ? results[call] : results.last,
      sampleCount: samples.length,
      elapsed: const Duration(milliseconds: 250),
    );
  }

  @override
  void cancel() {}

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

final class _FakeCapture implements PcmAudioCapture {
  final StreamController<Uint8List> _controller = StreamController<Uint8List>();
  bool _started = false;

  void add(Uint8List bytes) {
    if (!_started) {
      throw StateError('capture 尚未启动');
    }
    _controller.add(Uint8List.fromList(bytes));
  }

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> start() async {
    _started = true;
    return _controller.stream;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
    _started = false;
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

final class _FixedCapacity implements RecordingStorageCapacityProvider {
  const _FixedCapacity(this.bytes);

  final int bytes;

  @override
  Future<int> getFreeBytes() async => bytes;
}

Future<void> _waitFor(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 2)) {
      fail('等待录音写入超时');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
