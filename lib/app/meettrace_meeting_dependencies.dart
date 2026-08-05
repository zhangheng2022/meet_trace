import '../data/services/asr/platform_asr_device_risk_monitor.dart';
import '../data/services/asr/sherpa_onnx_asr_engine_factory.dart';
import '../data/services/audio/device_recording_storage_capacity.dart';
import '../data/services/audio/record_pcm_audio_capture.dart';
import '../data/services/audio/recording_device_readiness_probe.dart';
import '../data/services/diarization/speaker_diarization_service.dart';
import '../data/models/runtime/speaker_diarization_manifest.dart';
import '../domain/use_cases/check_meeting_readiness.dart';
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
  });

  final SherpaOnnxAsrEngineFactory engineFactory;
  final FinalResultCoordinator finalTranscription;
  final SpeakerDiarizationCoordinator diarization;
  final SpeakerDiarizationService diarizationService;
  final CheckMeetingReadinessUseCase meetingReadiness;

  factory MeetingDependencies.create({
    required StorageDependencies storage,
    required RuntimeAssetDependencies runtime,
  }) {
    final engineFactory = SherpaOnnxAsrEngineFactory(
      installations: storage.installations,
      leases: storage.leases,
      riskMonitor: createPlatformAsrDeviceRiskMonitor(),
      ownerId: 'meettrace-app',
    );
    final diarizationService = createMeetTraceSpeakerDiarizationService(
      segmentationModelPath: runtime.speakerSegmentationModelPath,
      embeddingModelPath: runtime.speakerEmbeddingModelPath,
      inference: runtime.speakerManifest.inference,
    );
    return MeetingDependencies._(
      engineFactory: engineFactory,
      finalTranscription: FinalResultCoordinator(
        meetings: storage.meetings,
        transcripts: storage.transcripts,
        tasks: storage.processingTasks,
        engineFactory: engineFactory,
        diarization: diarizationService,
        diarizationPreferences: storage.diarizationPreferences,
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
    );
  }

  Future<void> dispose() async {
    if (diarizationService
        case final SpeakerDiarizationServiceLifecycle lifecycle) {
      await lifecycle.dispose();
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
