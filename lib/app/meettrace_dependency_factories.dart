import '../data/services/asr/asr_preview_coordinator.dart';
import '../data/services/audio/device_recording_storage_capacity.dart';
import '../data/services/audio/pcm_evidence_playback_service.dart';
import '../data/services/audio/platform_recording_foreground_lifecycle.dart';
import '../data/services/audio/record_pcm_audio_capture.dart';
import '../data/services/audio/recording_checkpoint_store.dart';
import '../data/services/audio/reliable_recording_service.dart';
import '../data/services/models/downloadable_model_service.dart';
import '../data/services/sharing/text_share_service.dart';
import '../data/services/storage/local_data_control_service.dart';
import '../data/services/storage/meeting_directory_deletion_service.dart';
import '../data/services/vad/silero_vad_segmenter.dart';
import '../domain/models/meeting.dart';
import '../domain/use_cases/delete_meeting.dart';
import '../domain/use_cases/initialize_runtime_assets.dart';
import '../domain/use_cases/manage_recording_session.dart';
import '../domain/use_cases/revise_final_transcript.dart';
import '../domain/use_cases/start_meeting.dart';
import '../ui/core/asr_model_option.dart';
import '../ui/features/meetings/view_models/detail/meeting_detail_view_model.dart';
import '../ui/features/meetings/view_models/list/meeting_list_view_model.dart';
import '../ui/features/meetings/view_models/recording/recording_session_view_model.dart';
import '../ui/features/meetings/view_models/start/start_meeting_view_model.dart';
import '../ui/features/settings/view_models/data_controls_view_model.dart';
import '../ui/features/settings/view_models/model_settings_view_model.dart';
import '../ui/features/startup/view_models/runtime_initialization_view_model.dart';
import 'meettrace_dependencies.dart';

extension MeetTraceViewModelFactories on MeetTraceDependencies {
  RuntimeInitializationViewModel createRuntimeInitializationViewModel({
    bool forceRepair = false,
  }) {
    return RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(runtime.runtimeAssets),
      forceRepair: forceRepair,
    );
  }

  MeetingListViewModel createMeetingListViewModel() {
    return MeetingListViewModel(
      meetings: storage.meetings,
      readinessChecker: meeting.meetingReadiness,
      deletion: DeleteMeetingUseCase(
        meetings: storage.meetings,
        files: MeetingDirectoryDeletionService(layout: storage.fileLayout),
      ),
    );
  }

  MeetingDetailViewModel createMeetingDetailViewModel(Meeting selectedMeeting) {
    final sharing = const SharePlusTextShareService();
    return MeetingDetailViewModel(
      meeting: selectedMeeting,
      meetings: storage.meetings,
      transcripts: storage.transcripts,
      transcription: meeting.finalTranscription,
      diarization: meeting.diarization,
      diarizationPreferences: storage.diarizationPreferences,
      processingTasks: storage.processingTasks,
      summaries: storage.summaries,
      summaryGeneration: meeting.summaryGeneration,
      transcriptRevision: ReviseFinalTranscriptUseCase(
        meetings: storage.meetings,
        transcripts: storage.transcripts,
        now: DateTime.now,
      ),
      sharing: sharing,
      deletion: DeleteMeetingUseCase(
        meetings: storage.meetings,
        files: MeetingDirectoryDeletionService(layout: storage.fileLayout),
      ),
      playback: PcmEvidencePlaybackService(
        output: AudioplayersDeviceAudioOutput(),
        temporaryDirectory: storage.fileLayout.rootPath,
      ),
    );
  }

  ModelSettingsViewModel createModelSettingsViewModel() {
    final model = runtime.registry.defaultModel;
    final manifest = runtime.modelManifest.models.singleWhere(
      (entry) => entry.modelId == model.modelId,
    );
    ModelDownloadCancellationToken? cancellation;

    Future<void> download() async {
      cancellation = ModelDownloadCancellationToken();
      try {
        await runtime.modelDownloads.download(
          descriptor: model,
          manifest: manifest,
          allowMeteredNetwork: await runtime.runtimeAssets.hasMobileConsent(),
          cancellation: cancellation,
        );
      } finally {
        cancellation = null;
      }
    }

    return ModelSettingsViewModel(
      preferences: storage.preferences,
      installations: storage.installations,
      registry: runtime.registry,
      actions: ModelMaintenanceActions(
        repair: download,
        pause: () => cancellation?.cancel(),
      ),
    );
  }

  DataControlsViewModel createDataControlsViewModel() {
    return DataControlsViewModel(
      dataControl: LocalDataControlService(
        layout: storage.fileLayout,
        meetings: storage.meetings,
        installations: storage.installations,
      ),
      sharing: const SharePlusTextShareService(),
    );
  }

  StartMeetingViewModel createStartMeetingViewModel() {
    return StartMeetingViewModel(
      startMeeting: StartMeetingUseCase(
        meetings: storage.meetings,
        engineFactory: meeting.engineFactory,
        readinessChecker: meeting.meetingReadiness,
        meetingIdFactory: () =>
            'meeting-${DateTime.now().microsecondsSinceEpoch}',
        now: DateTime.now,
      ),
    );
  }

  RecordingSessionViewModel createRecordingSessionViewModel(
    StartedMeetingSession session,
  ) {
    final preview = AsrPreviewCoordinator(
      vad: SileroVadSegmenter.official(modelPath: runtime.vadModelPath),
      engine: session.engine,
    );
    final recording = ReliableRecordingService(
      capture: RecordPcmAudioCapture(),
      layout: storage.fileLayout,
      checkpoints: JsonRecordingCheckpointStore(storage.fileLayout),
      storageCapacity: const DeviceRecordingStorageCapacityProvider(),
      foreground: createRecordingForegroundLifecycle(),
      previewSink: preview,
      audioLevelMeter: PcmAudioLevelMeter(),
    );
    return RecordingSessionViewModel(
      session: session,
      recording: recording,
      preview: preview,
      sessionLifecycle: ManageRecordingSessionUseCase(
        meetings: storage.meetings,
        recording: recording,
        preview: preview,
        now: DateTime.now,
      ),
    );
  }
}
