import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../data/repositories/sqflite_meeting_repository.dart';
import '../data/repositories/sqflite_diarization_preference_repository.dart';
import '../data/repositories/sqflite_model_installation_repository.dart';
import '../data/repositories/sqflite_model_preference_repository.dart';
import '../data/repositories/sqflite_model_usage_lease_repository.dart';
import '../data/repositories/sqflite_processing_task_repository.dart';
import '../data/repositories/sqflite_summary_repository.dart';
import '../data/repositories/sqflite_transcript_repository.dart';
import '../data/services/asr/android_proc_asr_device_risk_monitor.dart';
import '../data/services/asr/asr_preview_coordinator.dart';
import '../data/services/asr/final_transcription_service.dart';
import '../data/services/asr/sherpa_onnx_asr_engine_factory.dart';
import '../data/services/diarization/speaker_diarization_coordinator.dart';
import '../data/services/diarization/speaker_diarization_service.dart';
import '../data/services/audio/device_recording_storage_capacity.dart';
import '../data/services/audio/flutter_foreground_recording_lifecycle.dart';
import '../data/services/audio/record_pcm_audio_capture.dart';
import '../data/services/audio/recording_checkpoint_store.dart';
import '../data/services/audio/reliable_recording_service.dart';
import '../data/services/audio/pcm_evidence_playback_service.dart';
import '../data/services/models/bundled_model_preparation_service.dart';
import '../data/services/models/flutter_model_asset_source.dart';
import '../data/services/models/model_file_verifier.dart';
import '../data/services/models/model_manifest_parser.dart';
import '../data/services/models/downloadable_model_service.dart';
import '../data/services/models/http_model_file_downloader.dart';
import '../data/services/models/platform_download_preflight_providers.dart';
import '../data/services/sharing/text_share_service.dart';
import '../data/services/storage/app_database.dart';
import '../data/services/storage/app_file_layout.dart';
import '../data/services/storage/startup_recovery_service.dart';
import '../data/services/storage/local_data_control_service.dart';
import '../data/services/storage/meeting_directory_deletion_service.dart';
import '../data/services/summary/summary_generation_service.dart';
import '../data/services/vad/bundled_silero_vad_model.dart';
import '../data/services/vad/silero_vad_segmenter.dart';
import '../domain/models/asr_model_registry.dart';
import '../domain/models/meeting.dart';
import '../domain/models/model_manifest.dart';
import '../domain/use_cases/delete_meeting.dart';
import '../domain/use_cases/generate_summary.dart';
import '../domain/use_cases/revise_final_transcript.dart';
import '../ui/core/asr_model_option.dart';
import '../ui/features/meetings/view_models/meeting_list_view_model.dart';
import '../ui/features/meetings/view_models/meeting_detail_view_model.dart';
import '../ui/features/meetings/view_models/recording_session_view_model.dart';
import '../ui/features/meetings/view_models/start_meeting_view_model.dart';
import '../ui/features/settings/view_models/data_controls_view_model.dart';
import '../ui/features/settings/view_models/model_settings_view_model.dart';

final class MeetTraceDependencies {
  MeetTraceDependencies._({
    required this.database,
    required this.fileLayout,
    required this.meetings,
    required this.transcripts,
    required this.installations,
    required this.preferences,
    required this.diarizationPreferences,
    required this.processingTasks,
    required this.summaries,
    required this.engineFactory,
    required this.finalTranscription,
    required this.diarization,
    required this.summaryGeneration,
    required this.registry,
    required this.modelManifest,
    required this.modelDownloads,
    required this.vadModelPath,
  });

  final AppDatabase database;
  final AppFileLayout fileLayout;
  final SqfliteMeetingRepository meetings;
  final SqfliteTranscriptRepository transcripts;
  final SqfliteModelInstallationRepository installations;
  final SqfliteModelPreferenceRepository preferences;
  final SqfliteDiarizationPreferenceRepository diarizationPreferences;
  final SqfliteProcessingTaskRepository processingTasks;
  final SqfliteSummaryRepository summaries;
  final SherpaOnnxAsrEngineFactory engineFactory;
  final FinalTranscriptionService finalTranscription;
  final SpeakerDiarizationCoordinator diarization;
  final GenerateSummaryUseCase summaryGeneration;
  final AsrModelRegistry registry;
  final ModelManifest modelManifest;
  final DownloadableModelService modelDownloads;
  final String vadModelPath;

  static Future<MeetTraceDependencies> create() async {
    final registry = AsrModelRegistry.alpha;
    final fileLayout = await AppFileLayout.forApplication();
    await fileLayout.createBaseDirectories();
    final database = AppDatabase(
      databaseFactory: databaseFactory,
      path: fileLayout.databasePath,
    );
    await StartupRecoveryService(
      database: database,
      layout: fileLayout,
    ).recover(now: DateTime.now());

    final meetings = SqfliteMeetingRepository(database);
    final transcripts = SqfliteTranscriptRepository(
      database,
      onMeetingChanged: meetings.notifyChanged,
    );
    final installations = SqfliteModelInstallationRepository(database);
    final preferences = SqfliteModelPreferenceRepository(
      database,
      registry: registry,
    );
    final diarizationPreferences = SqfliteDiarizationPreferenceRepository(
      database,
    );
    final processingTasks = SqfliteProcessingTaskRepository(database);
    final summaries = SqfliteSummaryRepository(database);
    final assetSource = FlutterModelAssetSource(rootBundle);
    final manifest = ModelManifestParser(
      registry: registry,
      currentAppVersion: '1.0.0',
    ).parse(await rootBundle.loadString('assets/models/manifest.json'));
    final standard = registry.requireById(paraformerStandardModelId);
    final standardManifest = manifest.models.singleWhere(
      (entry) => entry.modelId == standard.modelId,
    );
    await BundledModelPreparationService(
      fileLayout: fileLayout,
      installations: installations,
      assetSource: assetSource,
      verifier: const ModelFileVerifier(),
    ).prepare(descriptor: standard, manifest: standardManifest);
    final standardInstallation = await installations.get(
      modelId: standard.modelId,
      version: standard.version,
    );
    if (standardInstallation == null) {
      throw StateError('内置标准模型准备后没有安装记录');
    }
    await installations.saveInstalledAndActivate(standardInstallation);

    final vad = await BundledSileroVadModelService(
      fileLayout: fileLayout,
      assetSource: assetSource,
    ).prepare();
    final leases = SqfliteModelUsageLeaseRepository(database);
    final engineFactory = SherpaOnnxAsrEngineFactory(
      installations: installations,
      leases: leases,
      riskMonitor: AndroidProcAsrDeviceRiskMonitor(),
      ownerId: 'meettrace-app',
    );
    final finalTranscription = FinalTranscriptionService(
      meetings: meetings,
      transcripts: transcripts,
      engineFactory: engineFactory,
      now: DateTime.now,
    );
    final diarization = SpeakerDiarizationCoordinator(
      meetings: meetings,
      transcripts: transcripts,
      tasks: processingTasks,
      service: const UnavailableSpeakerDiarizationService(),
      now: DateTime.now,
    );
    final summaryGeneration = GenerateSummaryUseCase(
      meetings: meetings,
      transcripts: transcripts,
      summaries: summaries,
      tasks: processingTasks,
      service: const UnavailableSummaryGenerationService(),
      now: DateTime.now,
    );
    final modelDownloads = DownloadableModelService(
      fileLayout: fileLayout,
      installations: installations,
      leases: leases,
      capacity: const DeviceStorageCapacityProvider(),
      network: ConnectivityDownloadNetworkStatusProvider(),
      downloader: HttpModelFileDownloader(),
      verifier: const ModelFileVerifier(),
    );
    return MeetTraceDependencies._(
      database: database,
      fileLayout: fileLayout,
      meetings: meetings,
      transcripts: transcripts,
      installations: installations,
      preferences: preferences,
      diarizationPreferences: diarizationPreferences,
      processingTasks: processingTasks,
      summaries: summaries,
      engineFactory: engineFactory,
      finalTranscription: finalTranscription,
      diarization: diarization,
      summaryGeneration: summaryGeneration,
      registry: registry,
      modelManifest: manifest,
      modelDownloads: modelDownloads,
      vadModelPath: vad.modelPath,
    );
  }

  MeetingListViewModel createMeetingListViewModel() {
    return MeetingListViewModel(meetings: meetings);
  }

  MeetingDetailViewModel createMeetingDetailViewModel(Meeting meeting) {
    final sharing = const SharePlusTextShareService();
    return MeetingDetailViewModel(
      meeting: meeting,
      meetings: meetings,
      transcripts: transcripts,
      installations: installations,
      transcription: finalTranscription,
      diarization: diarization,
      diarizationPreferences: diarizationPreferences,
      processingTasks: processingTasks,
      summaries: summaries,
      summaryGeneration: summaryGeneration,
      transcriptRevision: ReviseFinalTranscriptUseCase(
        meetings: meetings,
        transcripts: transcripts,
        now: DateTime.now,
      ),
      sharing: sharing,
      deletion: DeleteMeetingUseCase(
        meetings: meetings,
        files: MeetingDirectoryDeletionService(layout: fileLayout),
      ),
      playback: PcmEvidencePlaybackService(
        output: AudioplayersDeviceAudioOutput(),
        temporaryDirectory: fileLayout.rootPath,
      ),
    );
  }

  ModelSettingsViewModel createModelSettingsViewModel() {
    final advanced = registry.requireById(qwenAdvancedModelId);
    final manifest = modelManifest.models.singleWhere(
      (entry) => entry.modelId == advanced.modelId,
    );
    ModelDownloadCancellationToken? cancellation;

    Future<void> download() async {
      cancellation = ModelDownloadCancellationToken();
      try {
        await modelDownloads.download(
          descriptor: advanced,
          manifest: manifest,
          cancellation: cancellation,
        );
      } finally {
        cancellation = null;
      }
    }

    return ModelSettingsViewModel(
      preferences: preferences,
      installations: installations,
      registry: registry,
      actions: AdvancedModelActions(
        download: download,
        cancel: () => cancellation?.cancel(),
        retry: download,
        delete: () async {
          await modelDownloads.delete(descriptor: advanced);
          if (await preferences.getDefaultModelId() == advanced.modelId) {
            await preferences.setDefaultModelId(registry.defaultModelId);
          }
        },
      ),
    );
  }

  DataControlsViewModel createDataControlsViewModel() {
    return DataControlsViewModel(
      dataControl: LocalDataControlService(
        layout: fileLayout,
        meetings: meetings,
        installations: installations,
      ),
      sharing: const SharePlusTextShareService(),
    );
  }

  StartMeetingViewModel createStartMeetingViewModel() {
    return StartMeetingViewModel(
      preferences: preferences,
      installations: installations,
      meetings: meetings,
      engineFactory: engineFactory,
      meetingIdFactory: () =>
          'meeting-${DateTime.now().microsecondsSinceEpoch}',
      now: DateTime.now,
    );
  }

  RecordingSessionViewModel createRecordingSessionViewModel(
    StartedMeetingSession session,
  ) {
    final preview = AsrPreviewCoordinator(
      vad: SileroVadSegmenter.official(modelPath: vadModelPath),
      engine: session.engine,
    );
    final recording = ReliableRecordingService(
      capture: RecordPcmAudioCapture(),
      layout: fileLayout,
      checkpoints: JsonRecordingCheckpointStore(fileLayout),
      storageCapacity: const DeviceRecordingStorageCapacityProvider(),
      foreground: FlutterForegroundRecordingLifecycle(),
      previewSink: preview,
    );
    return RecordingSessionViewModel(
      session: session,
      meetings: meetings,
      recording: recording,
      preview: preview,
      now: DateTime.now,
    );
  }

  Future<void> dispose() async {
    await meetings.dispose();
    await installations.dispose();
    await database.close();
  }
}
