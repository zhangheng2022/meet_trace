import 'dart:typed_data';

import '../../../domain/models/app_failure.dart';
import '../../../domain/models/asr_model.dart';
import '../../../domain/models/audio_source.dart';
import '../../../domain/models/transcript.dart';

final class AsrEngineException implements Exception {
  const AsrEngineException(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'AsrEngineException(${failure.code})';
}

enum AsrDeviceSupport { supported, constrained, unsupported }

enum AsrMemoryPressure { unknown, normal, warning, critical }

enum AsrThermalState { unknown, nominal, fair, serious, critical }

final class AsrDeviceRiskState {
  const AsrDeviceRiskState({
    required this.support,
    required this.memoryPressure,
    required this.thermalState,
    this.processRssBytes,
    this.estimatedAvailableBytes,
  }) : assert(processRssBytes == null || processRssBytes >= 0),
       assert(estimatedAvailableBytes == null || estimatedAvailableBytes >= 0);

  const AsrDeviceRiskState.supported()
    : this(
        support: AsrDeviceSupport.supported,
        memoryPressure: AsrMemoryPressure.normal,
        thermalState: AsrThermalState.nominal,
      );

  final AsrDeviceSupport support;
  final AsrMemoryPressure memoryPressure;
  final AsrThermalState thermalState;
  final int? processRssBytes;
  final int? estimatedAvailableBytes;

  bool get blocksInference =>
      support == AsrDeviceSupport.unsupported ||
      memoryPressure == AsrMemoryPressure.critical ||
      thermalState == AsrThermalState.critical;

  bool get hasWarning =>
      support == AsrDeviceSupport.constrained ||
      memoryPressure == AsrMemoryPressure.warning ||
      thermalState == AsrThermalState.serious;
}

abstract interface class AsrDeviceRiskMonitor {
  Future<AsrDeviceRiskState> inspect();

  Stream<AsrDeviceRiskState> get changes;
}

enum AsrWindowOutcome { recognized, empty, failed }

final class AsrWindowDiagnostic {
  const AsrWindowDiagnostic({
    required this.startMs,
    required this.endMs,
    required this.outcome,
    required this.elapsed,
    this.errorCode,
  });

  final int startMs;
  final int endMs;
  final AsrWindowOutcome outcome;
  final Duration elapsed;
  final String? errorCode;
}

final class AsrEngineMetrics {
  const AsrEngineMetrics({
    required this.modelId,
    required this.modelVersion,
    required this.totalWindowCount,
    required this.recognizedWindowCount,
    required this.emptyWindowCount,
    required this.failedWindowCount,
    required this.totalAudioDuration,
    required this.totalInferenceDuration,
    this.lastErrorCode,
  });

  final String modelId;
  final String modelVersion;
  final int totalWindowCount;
  final int recognizedWindowCount;
  final int emptyWindowCount;
  final int failedWindowCount;
  final Duration totalAudioDuration;
  final Duration totalInferenceDuration;
  final String? lastErrorCode;

  double get realTimeFactor {
    final audioMicros = totalAudioDuration.inMicroseconds;
    return audioMicros == 0
        ? 0
        : totalInferenceDuration.inMicroseconds / audioMicros;
  }
}

enum AsrFinalizationPhase { processing, completed, canceled, failed }

final class AsrFinalizationProgress {
  const AsrFinalizationProgress({
    required this.phase,
    required this.completedSamples,
    required this.totalSamples,
  });

  final AsrFinalizationPhase phase;
  final int completedSamples;
  final int totalSamples;

  double get fraction {
    if (totalSamples == 0) {
      return phase == AsrFinalizationPhase.completed ? 1 : 0;
    }
    return (completedSamples / totalSamples).clamp(0, 1);
  }
}

abstract interface class AsrEngine {
  AsrModelDescriptor get descriptor;

  Future<void> initialize();

  Stream<TranscriptEvent> get events;

  Stream<AsrFinalizationProgress> get finalizationProgress;

  AsrDeviceRiskState get deviceRisk;

  Stream<AsrDeviceRiskState> get deviceRisks;

  AsrEngineMetrics get metrics;

  List<AsrWindowDiagnostic> get diagnostics;

  Future<void> acceptAudio(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  });

  Future<TranscriptSnapshot> finalizeMeeting(
    AudioSource source, {
    required String meetingId,
  });

  void cancel();

  Future<void> dispose();
}

abstract interface class AsrEngineFactory {
  Future<AsrEngine> create({
    required String modelId,
    required String modelVersion,
  });
}
