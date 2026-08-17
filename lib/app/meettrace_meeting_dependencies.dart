import 'package:flutter/foundation.dart';

import '../data/services/asr/platform_asr_device_risk_monitor.dart';
import '../data/services/asr/sherpa_onnx_asr_engine_factory.dart';
import '../data/services/audio/device_recording_storage_capacity.dart';
import '../data/services/audio/record_pcm_audio_capture.dart';
import '../data/services/audio/record_input_device_catalog.dart';
import '../data/services/audio/recording_device_readiness_probe.dart';
import '../data/services/diarization/speaker_diarization_service.dart';
import '../data/services/platform/method_channel_windows_desktop_lifecycle.dart';
import '../data/models/runtime/speaker_diarization_manifest.dart';
import '../domain/ports/desktop_lifecycle.dart';
import '../domain/use_cases/check_meeting_readiness.dart';
import '../domain/use_cases/final_inference_scheduler.dart';
import '../domain/use_cases/lock_recording_input.dart';
import '../domain/use_cases/run_final_transcription.dart';
import '../domain/use_cases/run_speaker_diarization.dart';
import 'meettrace_runtime_dependencies.dart';
import 'meettrace_storage_dependencies.dart';

final class MeetingDependencies {
  const MeetingDependencies._({
    required this.engineFactory,
    required this.finalTranscription,
    required this.diarization,
    required this.diarizationService,
    required this.meetingReadiness,
    required this.recordingInputLock,
    required this.desktopLifecycle,
  });

  final SherpaOnnxAsrEngineFactory engineFactory;
  final FinalResultCoordinator finalTranscription;
  final SpeakerDiarizationCoordinator diarization;
  final SpeakerDiarizationService diarizationService;
  final CheckMeetingReadinessUseCase meetingReadiness;
  final LockRecordingInputUseCase recordingInputLock;
  final DesktopLifecycle desktopLifecycle;

  factory MeetingDependencies.create({
    required StorageDependencies storage,
    required RuntimeAssetDependencies runtime,
  }) {
    final engineFactory = SherpaOnnxAsrEngineFactory(
      installations: storage.installations,
      leases: storage.leases,
      riskMonitor: createPlatformAsrDeviceRiskMonitor(),
      ownerId: 'meettrace-app',
      vadModelPath: runtime.vadModelPath,
    );
    final diarizationService = createMeetTraceSpeakerDiarizationService(
      segmentationModelPath: runtime.speakerSegmentationModelPath,
      embeddingModelPath: runtime.speakerEmbeddingModelPath,
      inference: runtime.speakerManifest.inference,
    );
    final finalInferenceScheduler = FinalInferenceScheduler();
    return MeetingDependencies._(
      engineFactory: engineFactory,
      finalTranscription: FinalResultCoordinator(
        meetings: storage.meetings,
        transcripts: storage.transcripts,
        tasks: storage.processingTasks,
        engineFactory: engineFactory,
        diarization: diarizationService,
        diarizationPreferences: storage.diarizationPreferences,
        scheduler: finalInferenceScheduler,
        now: DateTime.now,
      ),
      diarization: SpeakerDiarizationCoordinator(
        meetings: storage.meetings,
        transcripts: storage.transcripts,
        tasks: storage.processingTasks,
        service: diarizationService,
        now: DateTime.now,
      ),
      diarizationService: diarizationService,
      meetingReadiness: CheckMeetingReadinessUseCase(
        device: DeviceRecordingReadinessProbe(
          captureFactory: RecordPcmAudioCapture.new,
          storageCapacity: const DeviceRecordingStorageCapacityProvider(),
        ),
        preferences: storage.preferences,
        installations: storage.installations,
        registry: runtime.registry,
      ),
      recordingInputLock: LockRecordingInputUseCase(
        preferences: storage.recordingInputPreferences,
        devices: RecordInputDeviceCatalog(),
      ),
      desktopLifecycle:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
          ? MethodChannelWindowsDesktopLifecycle()
          : const NoopDesktopLifecycle(),
    );
  }

  Future<void> dispose() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await desktopLifecycle.dispose();
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      if (diarizationService
          case final SpeakerDiarizationServiceLifecycle lifecycle) {
        await lifecycle.dispose();
      }
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}

SherpaOnnxSpeakerDiarizationService createMeetTraceSpeakerDiarizationService({
  required String segmentationModelPath,
  required String embeddingModelPath,
  required SpeakerDiarizationInferenceConfig inference,
}) {
  return SherpaOnnxSpeakerDiarizationService(
    config: SherpaOnnxSpeakerDiarizationConfig(
      segmentationModelPath: segmentationModelPath,
      embeddingModelPath: embeddingModelPath,
      sampleRate: inference.sampleRate,
      numThreads: inference.numThreads,
      provider: inference.provider,
      numClusters: inference.numClusters,
      clusteringThreshold: inference.clusteringThreshold,
      minDurationOn: inference.minDurationOn,
      minDurationOff: inference.minDurationOff,
    ),
  );
}
