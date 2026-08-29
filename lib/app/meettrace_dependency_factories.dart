import 'package:flutter/foundation.dart';

import '../data/services/asr/asr_preview_coordinator.dart';
import '../data/services/audio/device_recording_storage_capacity.dart';
import '../data/services/audio/pcm_audio_playback_service.dart';
import '../data/services/audio/platform_recording_foreground_lifecycle.dart';
import '../data/services/audio/platform_recording_input_recovery.dart';
import '../data/services/audio/record_input_device_catalog.dart';
import '../data/services/audio/record_pcm_audio_capture.dart';
import '../data/services/audio/recording_continuity_event_store.dart';
import '../data/services/audio/recording_checkpoint_store.dart';
import '../data/services/audio/reliable_recording_service.dart';
import '../data/services/models/model_download_types.dart';
import '../data/services/monitoring/sentry_bootstrap.dart';
import '../data/services/sharing/text_share_service.dart';
import '../data/services/sharing/pcm_wav_audio_share_service.dart';
import '../data/services/storage/local_data_control_service.dart';
import '../data/services/storage/meeting_directory_deletion_service.dart';
import '../data/services/vad/silero_vad_segmenter.dart';
import '../domain/models/meeting.dart';
import '../domain/models/app_theme.dart';
import '../domain/models/app_language.dart';
import '../domain/use_cases/delete_meeting.dart';
import '../domain/use_cases/initialize_runtime_assets.dart';
import '../domain/use_cases/manage_recording_session.dart';
import '../domain/use_cases/revise_final_transcript.dart';
import '../domain/use_cases/rename_meeting.dart';
import '../domain/use_cases/share_meeting_audio.dart';
import '../domain/use_cases/start_meeting.dart';
import '../domain/use_cases/build_meeting_share.dart';
import '../ui/core/asr_model_option.dart';
import '../ui/features/meetings/view_models/detail/meeting_detail_view_model.dart';
import '../ui/features/meetings/view_models/list/meeting_list_view_model.dart';
import '../ui/features/meetings/view_models/recording/recording_session_view_model.dart';
import '../ui/features/meetings/view_models/start/start_meeting_view_model.dart';
import '../ui/features/settings/view_models/data_controls_view_model.dart';
import '../ui/features/settings/view_models/model_settings_view_model.dart';
import '../ui/features/settings/view_models/theme_settings_view_model.dart';
import '../ui/features/settings/view_models/language_settings_view_model.dart';
import '../ui/features/startup/view_models/runtime_initialization_view_model.dart';
import '../ui/features/updates/view_models/app_update_view_model.dart';
import 'meettrace_dependencies.dart';

extension MeetTraceViewModelFactories on MeetTraceDependencies {
  AppUpdateViewModel? createAppUpdateViewModel() =>
      updates?.createViewModel(storage.meetings);

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
      renaming: RenameMeetingUseCase(meetings: storage.meetings),
    );
  }

  MeetingDetailViewModel createMeetingDetailViewModel(
    Meeting selectedMeeting, {
    required BuildMeetingShareUseCase Function() shareBuilderProvider,
    required String Function(String meetingTitle) audioShareTitleBuilder,
    required String Function() audioFileNameFallbackBuilder,
    required String Function(int number) speakerLabelBuilder,
  }) {
    final sharing = const SharePlusTextShareService();
    return MeetingDetailViewModel(
      meeting: selectedMeeting,
      meetings: storage.meetings,
      transcripts: storage.transcripts,
      transcription: meeting.finalTranscription,
      diarization: meeting.diarization,
      diarizationPreferences: storage.diarizationPreferences,
      processingTasks: storage.processingTasks,
      transcriptRevision: ReviseFinalTranscriptUseCase(
        meetings: storage.meetings,
        transcripts: storage.transcripts,
        now: DateTime.now,
      ),
      sharing: sharing,
      audioSharing: ShareMeetingAudioUseCase(
        PcmWavAudioShareService(
          layout: storage.fileLayout,
          shareTitleBuilder: audioShareTitleBuilder,
          fileNameFallbackBuilder: audioFileNameFallbackBuilder,
        ),
      ),
      deletion: DeleteMeetingUseCase(
        meetings: storage.meetings,
        files: MeetingDirectoryDeletionService(layout: storage.fileLayout),
      ),
      playback: PcmAudioPlaybackService(
        output: AudioplayersDeviceAudioOutput(),
        temporaryDirectory: storage.fileLayout.rootPath,
      ),
      shareBuilderProvider: shareBuilderProvider,
      speakerLabelBuilder: speakerLabelBuilder,
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
      recordingInputPreferences: defaultTargetPlatform == TargetPlatform.windows
          ? storage.recordingInputPreferences
          : null,
      recordingInputDevices: defaultTargetPlatform == TargetPlatform.windows
          ? RecordInputDeviceCatalog()
          : null,
    );
  }

  DataControlsViewModel createDataControlsViewModel({
    required String Function() diagnosticsSubjectBuilder,
  }) {
    return DataControlsViewModel(
      dataControl: LocalDataControlService(
        layout: storage.fileLayout,
        meetings: storage.meetings,
        installations: storage.installations,
      ),
      sharing: const SharePlusTextShareService(),
      diagnosticsSubjectBuilder: diagnosticsSubjectBuilder,
    );
  }

  ThemeSettingsViewModel createThemeSettingsViewModel(
    ValueNotifier<AppThemeMode> themeMode,
  ) {
    return ThemeSettingsViewModel(
      preferences: storage.themePreferences,
      themeMode: themeMode,
    );
  }

  LanguageSettingsViewModel createLanguageSettingsViewModel(
    ValueNotifier<AppLanguageMode> languageMode,
  ) {
    return LanguageSettingsViewModel(
      preferences: storage.languagePreferences,
      languageMode: languageMode,
    );
  }

  StartMeetingViewModel createStartMeetingViewModel({
    required String Function(DateTime) meetingTitleFactory,
  }) {
    return StartMeetingViewModel(
      startMeeting: StartMeetingUseCase(
        meetings: storage.meetings,
        engineFactory: meeting.engineFactory,
        readinessChecker: meeting.meetingReadiness,
        meetingIdFactory: () =>
            'meeting-${DateTime.now().microsecondsSinceEpoch}',
        now: DateTime.now,
        recordingInputLock: meeting.recordingInputLock,
        meetingTitleFactory: meetingTitleFactory,
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
      initialInput: session.recordingInput,
      inputRecoveryPlanner: createRecordingInputRecoveryPlanner(),
      layout: storage.fileLayout,
      checkpoints: JsonRecordingCheckpointStore(storage.fileLayout),
      continuityEvents: JsonRecordingContinuityEventStore(storage.fileLayout),
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
      telemetry: sentryRecordingTelemetryGate,
      desktopLifecycle: meeting.desktopLifecycle,
      recordingSystemLifecycle: recording,
    );
  }
}
