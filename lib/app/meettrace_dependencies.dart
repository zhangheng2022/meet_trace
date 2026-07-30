import 'dart:async';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../data/repositories/sqflite_meeting_repository.dart';
import '../data/repositories/sqflite_diarization_preference_repository.dart';
import '../data/repositories/sqflite_model_installation_repository.dart';
import '../data/repositories/sqflite_model_preference_repository.dart';
import '../data/repositories/sqflite_model_usage_lease_repository.dart';
import '../data/repositories/sqflite_processing_task_repository.dart';
import '../data/repositories/sqflite_summary_repository.dart';
import '../data/repositories/sqflite_transcript_repository.dart';
import '../data/services/asr/asr_preview_coordinator.dart';
import '../data/services/asr/platform_asr_device_risk_monitor.dart';
import '../data/services/asr/whisper_asr_engine_factory.dart';
import '../data/services/diarization/speaker_diarization_service.dart';
import '../data/services/audio/device_recording_storage_capacity.dart';
import '../data/services/audio/platform_recording_foreground_lifecycle.dart';
import '../data/services/audio/record_pcm_audio_capture.dart';
import '../data/services/audio/recording_checkpoint_store.dart';
import '../data/services/audio/recording_device_readiness_probe.dart';
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
import '../data/services/storage/platform_database_factory.dart';
import '../data/services/storage/startup_recovery_service.dart';
import '../data/services/storage/local_data_control_service.dart';
import '../data/services/storage/meeting_directory_deletion_service.dart';
import '../data/services/summary/summary_generation_service.dart';
import '../data/services/vad/whisper_vad_segmenter.dart';
import '../domain/models/asr_model_registry.dart';
import '../domain/models/meeting.dart';
import '../domain/models/model_manifest.dart';
import '../domain/use_cases/delete_meeting.dart';
import '../domain/use_cases/check_meeting_readiness.dart';
import '../domain/use_cases/generate_summary.dart';
import '../domain/use_cases/manage_recording_session.dart';
import '../domain/use_cases/revise_final_transcript.dart';
import '../domain/use_cases/run_final_transcription.dart';
import '../domain/use_cases/run_speaker_diarization.dart';
import '../domain/use_cases/start_meeting.dart';
import '../ui/core/asr_model_option.dart';
import '../ui/features/meetings/view_models/detail/meeting_detail_view_model.dart';
import '../ui/features/meetings/view_models/list/meeting_list_view_model.dart';
import '../ui/features/meetings/view_models/recording/recording_session_view_model.dart';
import '../ui/features/meetings/view_models/start/start_meeting_view_model.dart';
import '../ui/features/settings/view_models/data_controls_view_model.dart';
import '../ui/features/settings/view_models/model_settings_view_model.dart';

part 'meettrace_dependency_factories.dart';

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
    required this.meetingReadiness,
    required this.whisperVadModelPath,
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
  final WhisperAsrEngineFactory engineFactory;
  final FinalTranscriptionService finalTranscription;
  final SpeakerDiarizationCoordinator diarization;
  final GenerateSummaryUseCase summaryGeneration;
  final AsrModelRegistry registry;
  final ModelManifest modelManifest;
  final DownloadableModelService modelDownloads;
  final CheckMeetingReadinessUseCase meetingReadiness;
  final String whisperVadModelPath;

  static Future<MeetTraceDependencies> create() async {
    final rollback = <Future<void> Function()>[];
    try {
      final registry = AsrModelRegistry.alpha;
      final fileLayout = await AppFileLayout.forApplication();
      await fileLayout.createBaseDirectories();
      final database = AppDatabase(
        databaseFactory: createPlatformDatabaseFactory(),
        path: fileLayout.databasePath,
      );
      rollback.add(database.close);
      await StartupRecoveryService(
        database: database,
        layout: fileLayout,
      ).recover(now: DateTime.now());

      final meetings = SqfliteMeetingRepository(database);
      rollback.add(meetings.dispose);
      final transcripts = SqfliteTranscriptRepository(
        database,
        onMeetingChanged: meetings.notifyChanged,
      );
      final installations = SqfliteModelInstallationRepository(database);
      rollback.add(installations.dispose);
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
      final standard = registry.requireById(whisperBaseStandardModelId);
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
      final standardInstalledPath = standardInstallation.installedPath;
      if (standardInstalledPath == null) {
        throw StateError('内置标准模型准备后没有安装目录');
      }
      final whisperVadModelPath = p.join(
        standardInstalledPath,
        'vad',
        'ggml-silero-v6.2.0.bin',
      );
      await installations.saveInstalledAndActivate(standardInstallation);

      final leases = SqfliteModelUsageLeaseRepository(database);
      final engineFactory = WhisperAsrEngineFactory(
        installations: installations,
        leases: leases,
        riskMonitor: createPlatformAsrDeviceRiskMonitor(),
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
      final meetingReadiness = CheckMeetingReadinessUseCase(
        device: DeviceRecordingReadinessProbe(
          captureFactory: RecordPcmAudioCapture.new,
          storageCapacity: const DeviceRecordingStorageCapacityProvider(),
        ),
        preferences: preferences,
        installations: installations,
        registry: registry,
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
        meetingReadiness: meetingReadiness,
        whisperVadModelPath: whisperVadModelPath,
      );
    } on Object catch (error, stackTrace) {
      for (final dispose in rollback.reversed) {
        try {
          await dispose();
        } on Object {
          // 保留启动失败的原始错误，避免重试累积数据库与流资源。
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> dispose() async {
    await meetings.dispose();
    await installations.dispose();
    await database.close();
  }
}
