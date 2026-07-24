import 'dart:async';
import 'dart:typed_data';

import 'package:meetily_ai/data/repositories/repository_contracts.dart';
import 'package:meetily_ai/data/services/asr/asr_engine.dart';
import 'package:meetily_ai/domain/models/asr_model.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/audio_source.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
import 'package:meetily_ai/domain/models/model_installation.dart';
import 'package:meetily_ai/domain/models/model_usage_lease.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';

final class TestModelPreferences implements ModelPreferenceRepository {
  TestModelPreferences(this.value);

  String value;
  final List<String> setCalls = [];

  @override
  Future<String> getDefaultModelId() async => value;

  @override
  Future<void> setDefaultModelId(String modelId) async {
    value = modelId;
    setCalls.add(modelId);
  }
}

final class TestActiveInstallations
    implements ActiveModelInstallationRepository {
  final Map<String, ModelInstallation> _records = {};
  final Map<String, String> _activeVersions = {};
  final StreamController<List<ModelInstallation>> _changes =
      StreamController.broadcast();

  void install(
    ModelInstallation installation, {
    bool active = false,
    bool notify = false,
  }) {
    _records[_key(installation.modelId, installation.version)] = installation;
    if (active) {
      _activeVersions[installation.modelId] = installation.version;
    }
    if (notify) {
      emit();
    }
  }

  void emit() {
    _changes.add(List.unmodifiable(_records.values));
  }

  ModelInstallation state(
    AsrModelDescriptor descriptor,
    ModelInstallationState state, {
    String? errorCode,
  }) {
    return ModelInstallation(
      modelId: descriptor.modelId,
      version: descriptor.version,
      installationType: descriptor.installationType,
      state: state,
      installedPath: state == ModelInstallationState.installed
          ? 'models/${descriptor.modelId}/${descriptor.version}'
          : null,
      verifiedAt: state == ModelInstallationState.installed
          ? DateTime.utc(2026, 7, 24)
          : null,
      bytes: state == ModelInstallationState.installed
          ? descriptor.requiredBytes
          : 0,
      lastErrorCode: errorCode,
    );
  }

  ModelInstallation installed(AsrModelDescriptor descriptor) {
    return state(descriptor, ModelInstallationState.installed);
  }

  @override
  Future<ModelInstallation?> get({
    required String modelId,
    required String version,
  }) async {
    return _records[_key(modelId, version)];
  }

  @override
  Future<String?> getActiveVersion(String modelId) async {
    return _activeVersions[modelId];
  }

  @override
  Future<void> save(ModelInstallation installation) async {
    install(installation, notify: true);
  }

  @override
  Future<void> saveInstalledAndActivate(ModelInstallation installation) async {
    install(installation, active: true, notify: true);
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
    emit();
  }

  @override
  Stream<List<ModelInstallation>> watchAll() async* {
    yield List.unmodifiable(_records.values);
    yield* _changes.stream;
  }

  Future<void> dispose() => _changes.close();

  String _key(String modelId, String version) => '$modelId@$version';
}

final class TestMeetingRepository implements MeetingRepository {
  final List<Meeting> saved = [];

  @override
  Future<Meeting?> getById(String meetingId) async {
    return saved.where((meeting) => meeting.id == meetingId).firstOrNull;
  }

  @override
  Stream<List<Meeting>> watchAll() => Stream.value(List.unmodifiable(saved));

  @override
  Future<void> save(Meeting meeting) async {
    saved.add(meeting);
  }

  @override
  Future<void> delete(String meetingId) async {
    saved.removeWhere((meeting) => meeting.id == meetingId);
  }
}

final class TestAsrEngineFactory implements AsrEngineFactory {
  final List<(String, String)> calls = [];
  final List<TestAsrEngine> engines = [];
  Object? createError;

  @override
  Future<AsrEngine> create({
    required String modelId,
    required String modelVersion,
  }) async {
    calls.add((modelId, modelVersion));
    final error = createError;
    if (error != null) {
      throw error;
    }
    final descriptor = AsrModelRegistry.alpha.requireById(modelId);
    final engine = TestAsrEngine(descriptor);
    engines.add(engine);
    return engine;
  }
}

final class TestAsrEngine implements AsrEngine {
  TestAsrEngine(this.descriptor);

  @override
  final AsrModelDescriptor descriptor;
  int initializeCalls = 0;
  int disposeCalls = 0;
  Object? initializeError;

  @override
  List<AsrWindowDiagnostic> get diagnostics => const [];

  @override
  AsrDeviceRiskState get deviceRisk => const AsrDeviceRiskState.supported();

  @override
  Stream<AsrDeviceRiskState> get deviceRisks => const Stream.empty();

  @override
  Stream<TranscriptEvent> get events => const Stream.empty();

  @override
  Stream<AsrFinalizationProgress> get finalizationProgress =>
      const Stream.empty();

  @override
  AsrEngineMetrics get metrics => AsrEngineMetrics(
    modelId: descriptor.modelId,
    modelVersion: descriptor.version,
    totalWindowCount: 0,
    recognizedWindowCount: 0,
    emptyWindowCount: 0,
    failedWindowCount: 0,
    totalAudioDuration: Duration.zero,
    totalInferenceDuration: Duration.zero,
  );

  @override
  Future<void> initialize() async {
    initializeCalls++;
    final error = initializeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> acceptAudio(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  }) async {}

  @override
  Future<TranscriptSnapshot> finalizeMeeting(
    AudioSource source, {
    required String meetingId,
  }) {
    throw UnimplementedError();
  }

  @override
  void cancel() {}

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

final class TestModelLeases implements ModelUsageLeaseRepository {
  @override
  Future<int> deleteExpired(DateTime now) async => 0;

  @override
  Future<List<ModelUsageLease>> listActive({
    required String modelId,
    required String version,
    required DateTime now,
  }) async => const [];

  @override
  Future<void> release(String leaseId) async {}

  @override
  Future<void> save(ModelUsageLease lease) async {}
}
