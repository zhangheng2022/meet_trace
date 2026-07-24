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
