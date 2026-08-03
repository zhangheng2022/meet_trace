part of 'meettrace_dependencies.dart';

extension MeetTraceViewModelFactories on MeetTraceDependencies {
  RuntimeInitializationViewModel createRuntimeInitializationViewModel({
    bool forceRepair = false,
  }) {
    return RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(runtimeAssets),
      forceRepair: forceRepair,
    );
  }

  MeetingListViewModel createMeetingListViewModel() {
    return MeetingListViewModel(
      meetings: meetings,
      readinessChecker: meetingReadiness,
      deletion: DeleteMeetingUseCase(
        meetings: meetings,
        files: MeetingDirectoryDeletionService(layout: fileLayout),
      ),
    );
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
    final model = registry.defaultModel;
    final manifest = modelManifest.models.singleWhere(
      (entry) => entry.modelId == model.modelId,
    );
    ModelDownloadCancellationToken? cancellation;

    Future<void> download() async {
      cancellation = ModelDownloadCancellationToken();
      try {
        await modelDownloads.download(
          descriptor: model,
          manifest: manifest,
          allowMeteredNetwork: await runtimeAssets.hasMobileConsent(),
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
      actions: ModelMaintenanceActions(
        repair: download,
        pause: () => cancellation?.cancel(),
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
      startMeeting: StartMeetingUseCase(
        meetings: meetings,
        engineFactory: engineFactory,
        readinessChecker: meetingReadiness,
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
      vad: SileroVadSegmenter.official(modelPath: vadModelPath),
      engine: session.engine,
    );
    final recording = ReliableRecordingService(
      capture: RecordPcmAudioCapture(),
      layout: fileLayout,
      checkpoints: JsonRecordingCheckpointStore(fileLayout),
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
        meetings: meetings,
        recording: recording,
        preview: preview,
        now: DateTime.now,
      ),
    );
  }
}
