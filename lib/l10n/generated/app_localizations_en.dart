// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => '会迹 MeetTrace';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get backToMeetings => 'Back to meetings';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSaveFailedTitle => 'Language setting not saved';

  @override
  String get languageSaveFailedMessage =>
      'The previous language has been restored.';

  @override
  String get languageOptionsSemantics => 'App language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageSystemDescription =>
      'Use Chinese for Chinese system locales; otherwise use English';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageSimplifiedChineseDescription =>
      'Always use Simplified Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishDescription => 'Always use English';

  @override
  String get appearanceSectionTitle => 'Appearance';

  @override
  String get themeSaveFailedTitle => 'Theme setting not saved';

  @override
  String get themeOptionsSemantics => 'Appearance theme';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystemDescription =>
      'Match the device appearance automatically';

  @override
  String get themeLightDescription => 'Always use the light appearance';

  @override
  String get themeDarkDescription => 'Always use the dark appearance';

  @override
  String get modelSettingsIncomplete => 'Model settings incomplete';

  @override
  String get meetingDefaultsTitle => 'Meeting defaults';

  @override
  String get newMeetingTranscriptionModel => 'New meeting transcription model';

  @override
  String get reading => 'Reading';

  @override
  String get modelLockDescription =>
      'Only affects future meetings. The model is locked after recording starts and never switches automatically.';

  @override
  String get recordingInputTitle => 'Recording input';

  @override
  String get recordingInputDescription =>
      'This selection is locked when a new meeting starts. If the device disconnects during a meeting, the app falls back to the system default microphone once.';

  @override
  String get microphoneSettingsIncomplete => 'Microphone setting incomplete';

  @override
  String get readingWindowsMicrophones => 'Reading Windows microphones';

  @override
  String get windowsRecordingDevices => 'Windows recording input devices';

  @override
  String get systemDefaultMicrophone => 'System default microphone';

  @override
  String get systemDefaultMicrophoneDescription =>
      'Resolved by Windows when each meeting starts';

  @override
  String get microphoneUnavailable =>
      'Currently unavailable. Connect the device or select another microphone.';

  @override
  String get windowsInputDevice => 'Windows input device';

  @override
  String get noOtherMicrophones =>
      'No other microphones were found. You can still use the system default microphone.';

  @override
  String get rescanningWindowsMicrophones => 'Rescanning Windows microphones';

  @override
  String get rescanMicrophones => 'Rescan microphones';

  @override
  String get offlineResourcesTitle => 'Offline transcription resources';

  @override
  String get readingOfflineResources =>
      'Reading offline transcription resources';

  @override
  String get noOfflineResources =>
      'No offline transcription resources are available.';

  @override
  String modelVersionAutoLanguage(String version, String itn) {
    return 'Version $version · Automatic language detection$itn';
  }

  @override
  String get itnEnabledSuffix => ' · ITN enabled';

  @override
  String get downloadAndRepair => 'Download and repair';

  @override
  String get pauseDownload => 'Pause download';

  @override
  String get continueOrRetry => 'Continue or retry';

  @override
  String get verifyAndUpdate => 'Verify and update';

  @override
  String offlineResourceProgress(String status) {
    return '$status offline transcription resources';
  }

  @override
  String offlineResourceStatus(String status) {
    return '$status, offline transcription resource status';
  }

  @override
  String get modelMaintenanceActions => 'Model maintenance actions';

  @override
  String get verifyAndRepair => 'Verify and repair';

  @override
  String get verifyAndRepairDescription =>
      'Check local file integrity and download again if needed';

  @override
  String get maintainOfflineResources =>
      'Maintain offline transcription resources';

  @override
  String get maintainResources => 'Maintain resources';

  @override
  String get storagePrivacyTitle => 'Storage and privacy';

  @override
  String get readingLocalStorage => 'Reading local storage usage';

  @override
  String get storageReadFailed => 'Could not read storage usage';

  @override
  String get storageUnchangedRetry =>
      'Local data was not changed. You can read it again.';

  @override
  String get readAgain => 'Read again';

  @override
  String get storageAppTotal => 'App total';

  @override
  String get storageMeetings => 'Meeting data';

  @override
  String get storageModels => 'Model data';

  @override
  String get storageDatabase => 'Database';

  @override
  String get storageDeviceAvailable => 'Available on device';

  @override
  String get localStoragePrivacyDescription =>
      'Meeting recordings, final transcripts, and runtime resources remain on this device. Uninstalling the app may permanently delete them.';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagnosticsShareSubject => 'MeetTrace diagnostics';

  @override
  String get viewShareDiagnostics => 'View and share diagnostics';

  @override
  String get diagnosticsContents =>
      'Contains only status, usage, model versions, and error codes';

  @override
  String get confirmShareDiagnostics => 'Confirm sharing diagnostics';

  @override
  String get shareDiagnosticsQuestion => 'Share diagnostics?';

  @override
  String get diagnosticsPrivacy =>
      'Diagnostics do not include meeting titles, final transcripts, source audio, or local paths.';

  @override
  String get cancel => 'Cancel';

  @override
  String get viewAndShare => 'View and share';

  @override
  String get modelStatusNotDownloaded => 'Not downloaded';

  @override
  String get modelStatusChecking => 'Checking';

  @override
  String get modelStatusDownloading => 'Downloading';

  @override
  String get modelStatusPaused => 'Paused';

  @override
  String get modelStatusVerifying => 'Verifying';

  @override
  String get modelStatusInstalled => 'Installed';

  @override
  String get modelStatusUpdateAvailable => 'Update available';

  @override
  String get modelStatusDeleting => 'Deleting';

  @override
  String get modelStatusDownloadFailed => 'Download failed';

  @override
  String get modelStatusInsufficientSpace => 'Insufficient space';

  @override
  String get languageChineseShort => 'Chinese';

  @override
  String get languageCantoneseShort => 'Cantonese';

  @override
  String get languageEnglishShort => 'English';

  @override
  String get languageJapaneseShort => 'Japanese';

  @override
  String get languageKoreanShort => 'Korean';

  @override
  String get modelLanguageSeparator => ' · ';

  @override
  String get semanticListSeparator => ', ';

  @override
  String get semanticSentenceSeparator => '. ';

  @override
  String get shareLabelSeparator => ': ';

  @override
  String defaultMeetingTitle(String dateTime) {
    return '$dateTime Meeting';
  }

  @override
  String get untitledMeeting => 'Untitled meeting';

  @override
  String get meetingTimeLabel => 'Meeting time';

  @override
  String get finalTranscriptTitle => 'Final transcript';

  @override
  String get speakerOne => 'Speaker 1';

  @override
  String speakerNumber(int number) {
    return 'Speaker $number';
  }

  @override
  String get shareExportFooter =>
      'Exported from the final transcript on this device by MeetTrace. Original audio is not included.';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get meetingStatusPreparing => 'Preparing';

  @override
  String get meetingStatusRecording => 'Recording';

  @override
  String get meetingStatusProcessing => 'Processing';

  @override
  String get meetingStatusCompleted => 'Completed';

  @override
  String get meetingStatusFailed => 'Failed';

  @override
  String get meetingStatusGeneratingFinal => 'Generating final transcript';

  @override
  String get meetingStatusProcessingFailed => 'Processing failed';

  @override
  String get meetingStatusFailedAudioHint =>
      'Failed · Open to check source audio';

  @override
  String get viewRecordingConditions => 'View recording conditions';

  @override
  String get recheckRecordingConditions => 'Recheck recording conditions';

  @override
  String get localRecording => 'Local recording';

  @override
  String get usesDefaultModel => 'Uses the default model';

  @override
  String get checkingRecordingConditions => 'Checking recording conditions';

  @override
  String get microphoneStorageDefaultModel =>
      'Microphone, storage, and default model';

  @override
  String get recordingConditionsReady => 'Recording conditions are ready';

  @override
  String audioLocalModelAvailable(String model) {
    return 'Audio stays on this device · $model is available';
  }

  @override
  String get defaultModel => 'Default model';

  @override
  String get microphonePermissionRequired => 'Microphone permission required';

  @override
  String get authorizeWhenStarting => 'Authorize when starting a meeting';

  @override
  String get storageInsufficient => 'Insufficient storage';

  @override
  String get keepAtLeast128Mb => 'Keep at least 128 MB available';

  @override
  String get defaultModelUnavailable => 'Default model unavailable';

  @override
  String get currentModel => 'Current model';

  @override
  String modelNeedsAttention(String model) {
    return '$model needs attention';
  }

  @override
  String get cannotCheckRecordingConditions =>
      'Could not check recording conditions';

  @override
  String get tapToRecheck => 'Tap to check again';

  @override
  String additionalIssues(String primary, int count) {
    return '$primary, plus $count more';
  }

  @override
  String get meetingsTitle => 'Meetings';

  @override
  String meetingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meetings',
      one: '1 meeting',
    );
    return '$_temp0';
  }

  @override
  String get preparingRecording => 'Preparing recording';

  @override
  String get startMeeting => 'Start meeting';

  @override
  String get preparingRecordingEllipsis => 'Preparing recording…';

  @override
  String get loadingMeetings => 'Loading meetings';

  @override
  String get meetingLoadFailed => 'Could not load meetings';

  @override
  String get localDataPreservedRetry =>
      'Local data is still on this device. Try again.';

  @override
  String get retryLoading => 'Retry loading';

  @override
  String get noMeetings => 'No meetings yet';

  @override
  String get noMeetingsDescription =>
      'After you start recording, meetings are stored safely on this device.';

  @override
  String get rename => 'Rename';

  @override
  String get renameMeetingHint => 'Open the meeting title editor';

  @override
  String get delete => 'Delete';

  @override
  String get deleteMeetingHint => 'Open permanent deletion confirmation';

  @override
  String get openSettings => 'Open settings';

  @override
  String get closeRecordingConditions => 'Close recording conditions panel';

  @override
  String permanentlyDeleteMeetingSemantics(String title) {
    return 'Permanently delete $title';
  }

  @override
  String permanentlyDeleteMeetingQuestion(String title) {
    return 'Permanently delete “$title”?';
  }

  @override
  String get permanentlyDeleteMeetingMessage =>
      'This removes the source audio, transcript, speaker labels, and processing records for this meeting. This cannot be undone.';

  @override
  String get permanentlyDelete => 'Permanently delete';

  @override
  String get meetingLocalDataDeleted => 'Meeting and local data deleted';

  @override
  String get deleteFailed => 'Deletion failed';

  @override
  String get meetingCannotDeleteNow =>
      'A meeting that is recording or processing cannot be deleted yet.';

  @override
  String get closeRenameMeeting => 'Close rename meeting panel';

  @override
  String get meetingTitleUpdated => 'Meeting title updated';

  @override
  String get brandSemantics => 'MeetTrace';

  @override
  String get renameMeetingTitle => 'Rename meeting';

  @override
  String get meetingTitleRequired => 'Enter a meeting title';

  @override
  String get meetingTitleSingleLine => 'The meeting title must be one line';

  @override
  String meetingTitleMaxLength(int count) {
    return 'The meeting title can contain at most $count characters';
  }

  @override
  String get saving => 'Saving';

  @override
  String get save => 'Save';

  @override
  String get meetingTitleLabel => 'Meeting title';

  @override
  String get meetingTitleHint => 'Enter a meeting title';

  @override
  String get renameFailedPreserved =>
      'Renaming failed. The original meeting title is preserved. Try again.';

  @override
  String get recordingConditionsTitle => 'Recording conditions';

  @override
  String get recordingConditionsDescription =>
      'The app checks again before starting a meeting. Recording and transcription resources remain on this device.';

  @override
  String get recordingConditionsDetails => 'Recording condition details';

  @override
  String get recordingConditionsStatus => 'Recording condition status';

  @override
  String get microphonePermission => 'Microphone permission';

  @override
  String get canRecordMeetingAudio => 'The app can record meeting audio';

  @override
  String get meetingNotCreatedBeforePermission =>
      'No meeting is created before you authorize access';

  @override
  String get authorized => 'Authorized';

  @override
  String get awaitingAuthorization => 'Awaiting authorization';

  @override
  String get localStorage => 'Local storage';

  @override
  String get spaceAvailable => 'Enough space';

  @override
  String get spaceInsufficient => 'Not enough space';

  @override
  String get offlineTranscription => 'Offline transcription';

  @override
  String modelUsedForMeeting(String model) {
    return '$model is used for live and final transcription';
  }

  @override
  String get available => 'Available';

  @override
  String get needsRepair => 'Needs repair';

  @override
  String minimumStorageRequired(String minimum) {
    return 'Starting a meeting requires at least $minimum';
  }

  @override
  String availableStorageMinimum(String available, String minimum) {
    return '$available available · $minimum minimum';
  }

  @override
  String get authorizeMicrophone => 'Authorize microphone';

  @override
  String get recheck => 'Check again';

  @override
  String get repairOfflineResources => 'Repair offline resources';

  @override
  String get selectMeeting => 'Select a meeting';

  @override
  String get selectMeetingDescription =>
      'Meeting facts, recording status, and model source appear here.';

  @override
  String get startTime => 'Start time';

  @override
  String get recordingDuration => 'Recording duration';

  @override
  String get sourceAudio => 'Source audio';

  @override
  String get meetingModel => 'Meeting model';

  @override
  String get meetingFacts => 'Meeting facts';

  @override
  String get liveTranscriptReferenceOnly =>
      'Live transcription is for reference only';

  @override
  String get sourceAudioLocalFirst => 'Source audio stays local';

  @override
  String get openFullRecord => 'Open full record';

  @override
  String get openFullMeetingRecord => 'Open full meeting record';

  @override
  String get recordingContinues => 'Recording continues';

  @override
  String get audioNotStarted => 'Recording has not started';

  @override
  String get audioWritingLocally => 'Writing continuously on this device';

  @override
  String get audioSavedLocally => 'Saved on this device';

  @override
  String get audioSealing => 'Sealing';

  @override
  String get meetingProcessingCompleted => 'Meeting processing completed';

  @override
  String get openMeetingForSaveStatus =>
      'Open the meeting to check save status';

  @override
  String get factCreatedDescription =>
      'Recording has not started. The meeting model is locked after it starts.';

  @override
  String get factRecordingDescription =>
      'Source audio is being written continuously on this device. Slow or failed inference does not interrupt recording.';

  @override
  String get factProcessingDescription =>
      'Source audio is sealed. The locked meeting model is generating the final transcript.';

  @override
  String get factFinalReadyDescription =>
      'The final transcript is ready. Open the full record for speaker labels and timestamps.';

  @override
  String get factCompletedDescription =>
      'Meeting processing completed. Open the full record to view the available result.';

  @override
  String get factDerivedFailedDescription =>
      'Derived processing failed, but source audio remains on this device. Open the full record to review and retry.';

  @override
  String get factMeetingFailedDescription =>
      'Meeting processing failed. Open the full record to check the cause and source audio status.';

  @override
  String get localModel => 'Local model';

  @override
  String get deleting => 'Deleting';

  @override
  String get renaming => 'Renaming';

  @override
  String openMeetingSemantics(String title, String dateTime, String status) {
    return 'Open meeting: $title, $dateTime, $status';
  }

  @override
  String get deletingLocalMeetingData => 'Deleting local meeting data';

  @override
  String get savingMeetingTitle => 'Saving the new meeting title';

  @override
  String get viewFailureAndAudio => 'View the failure and source audio status';

  @override
  String get viewMeetingDetails => 'View meeting details';

  @override
  String get swipeRenameDelete =>
      'Swipe left to show rename and delete actions';

  @override
  String get swipeRename => 'Swipe left to show the rename action';

  @override
  String get renameMeetingAction => 'Rename meeting';

  @override
  String get deleteMeetingAction => 'Delete meeting';

  @override
  String get endMeetingAndReturn => 'End meeting and return';

  @override
  String get endSaveMeetingSemantics => 'End and save meeting';

  @override
  String get endSaveMeetingQuestion => 'End and save meeting?';

  @override
  String get endSaveMeetingMessage =>
      'The app first seals the local source audio, then generates the final transcript. The current live transcript is only a preview.';

  @override
  String get continueRecording => 'Continue recording';

  @override
  String get endAndSave => 'End and save';

  @override
  String get startingRecording => 'Starting recording';

  @override
  String get liveTranscript => 'Live transcript';

  @override
  String segmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments',
      one: '1 segment',
    );
    return '$_temp0';
  }

  @override
  String get liveTranscriptReferenceFooter =>
      'For reference only. The final transcript is generated after the meeting ends.';

  @override
  String get finalFromFullAudio =>
      'The final transcript will still be generated from the complete audio after the meeting ends.';

  @override
  String get speechAppearsHere => 'Text appears here after speech is detected.';

  @override
  String get previewPausedWithRecording => 'Paused with recording';

  @override
  String get previewNormal => 'Normal';

  @override
  String get previewBacklogged => 'Backlogged; recording continues';

  @override
  String get previewStoppedRecordingContinues => 'Stopped; recording continues';

  @override
  String get previewEnded => 'Ended';

  @override
  String get meetingLockedModelFallback => 'Meeting model';

  @override
  String get recordingErrorGuidance =>
      'Keep the app data and use the available action. The source audio status is shown above.';

  @override
  String meetingModelLocked(String model) {
    return '$model · Locked for this meeting';
  }

  @override
  String get recordingStatePreparing => 'Preparing recording';

  @override
  String get recordingStateRecovering => 'Recovering';

  @override
  String get recordingStateInterrupted => 'Recording interrupted';

  @override
  String get recordingStatePaused => 'Paused';

  @override
  String get recordingStateSaving => 'Saving';

  @override
  String get recordingStateSaved => 'Saved';

  @override
  String get recordingStateError => 'Recording error';

  @override
  String get recordingFactStarting => 'Starting source recording';

  @override
  String get recordingFactWriting => 'Source audio is being written safely';

  @override
  String get recordingFactRecovering =>
      'Input interrupted; switching to the system default microphone';

  @override
  String get recordingFactInterrupted =>
      'Source recording stopped. End the meeting to preserve existing audio.';

  @override
  String get recordingFactPaused => 'Source recording paused';

  @override
  String get recordingFactSealing => 'Sealing source audio';

  @override
  String get recordingFactSaved => 'Source audio saved';

  @override
  String get recordingFactError => 'Source recording encountered an error';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get sealingAudio => 'Sealing audio';

  @override
  String get endMeeting => 'End meeting';

  @override
  String get waveformWaitingSemantics =>
      'Microphone waveform, waiting for recording';

  @override
  String get waveformWaitingLabel => 'Microphone input · Waiting for recording';

  @override
  String get waveformLiveSemantics => 'Microphone waveform, live feedback';

  @override
  String get waveformLiveLabel => 'Microphone input · Live feedback';

  @override
  String get waveformPausedSemantics => 'Microphone waveform, recording paused';

  @override
  String get waveformPausedLabel => 'Microphone input · Paused';

  @override
  String get waveformStoppedSemantics =>
      'Microphone waveform, recording stopped';

  @override
  String get waveformStoppedLabel => 'Microphone input · Stopped';

  @override
  String get meetingDetailsTitle => 'Meeting details';

  @override
  String get loadingMeetingResult => 'Loading meeting result';

  @override
  String get noFinalTranscript => 'No final transcript';

  @override
  String get sourceAudioReturnLater =>
      'Source audio remains on this device. Return later to continue processing.';

  @override
  String get lastProcessingIncomplete =>
      'The latest processing attempt did not finish';

  @override
  String get operationStatus => 'Operation status';

  @override
  String get factRecord => 'FACT RECORD';

  @override
  String get sourceAudioSaved => 'Source audio saved';

  @override
  String get sourceAudioTimestampVerification =>
      'The final transcript includes timestamps for checking against the original audio on this device.';

  @override
  String get finalTranscriptIncomplete => 'Final transcript incomplete';

  @override
  String get retryFinalTranscript => 'Retry final transcription';

  @override
  String get finalShowsSpeakers =>
      'The final transcript and speaker labels appear together when complete.';

  @override
  String get speakerSeparationUnavailableOutcome =>
      'Speaker separation is unavailable. The result will use one speaker.';

  @override
  String get generatingFinalResult => 'Generating final result';

  @override
  String processingSemanticsLabel(String model, String outcome) {
    return 'Generating final result. $model is processing the complete recording. $outcome Source audio is saved on this device. Processing never rewrites it.';
  }

  @override
  String modelProcessingFullRecording(String model) {
    return '$model is processing the complete recording.';
  }

  @override
  String get sourceAudioNotRewritten =>
      'Source audio is saved on this device. Processing never rewrites it.';

  @override
  String get stopPlayback => 'Stop playback';

  @override
  String get playRecording => 'Play recording';

  @override
  String get localSourceRecording => 'Local source recording';

  @override
  String recordingLocalDuration(String duration) {
    return 'Stored only on this device · $duration';
  }

  @override
  String get saveRevision => 'Save revision';

  @override
  String get shareMeeting => 'Share meeting';

  @override
  String get closeShareMeeting => 'Close share meeting panel';

  @override
  String get shareMeetingDescription =>
      'Text includes only the final transcript. Sharing source audio requires separate confirmation.';

  @override
  String get meetingShareMethods => 'Meeting sharing methods';

  @override
  String get plainText => 'Plain text';

  @override
  String get plainTextDescription => 'Suitable for messages and email bodies';

  @override
  String get markdownDescription =>
      'Preserves the title, timestamps, and structure';

  @override
  String get shareAudioSeparately => 'Share audio separately';

  @override
  String get shareAudioSeparatelyDescription =>
      'Creates a temporary WAV after another privacy confirmation';

  @override
  String get audioShareInsufficientSpace => 'Not enough space to share audio';

  @override
  String get audioFileNameFallback => 'Meeting recording';

  @override
  String get availableSpaceInsufficient => 'Insufficient available space';

  @override
  String temporaryWavShortage(String shortage) {
    return 'Creating a temporary WAV requires $shortage more. No file was created.';
  }

  @override
  String get confirmShareMeetingAudio => 'Confirm sharing meeting audio';

  @override
  String get confirmShareAudioQuestion => 'Share audio separately?';

  @override
  String audioShareConfirmation(String title, String duration, String size) {
    return 'Meeting: $title\nDuration: $duration\nFile: $size WAV\n\nThe recording may contain sensitive or private information. A temporary copy is created and the system share panel opens only after confirmation. Transcript text is not included.';
  }

  @override
  String get generateAndShare => 'Generate and share';

  @override
  String get moreMeetingActions => 'More meeting actions';

  @override
  String get closeMoreMeetingActions => 'Close more meeting actions';

  @override
  String get moreActions => 'More actions';

  @override
  String get moreActionsDescription =>
      'Less common actions are grouped here. Deleting a meeting cannot be undone.';

  @override
  String get regenerateTranscript => 'Regenerate transcript';

  @override
  String useLockedModel(String model) {
    return 'Continue using the locked $model model';
  }

  @override
  String get deleteMeeting => 'Delete meeting';

  @override
  String get deleteMeetingAllDerived =>
      'Also deletes source audio and all derived results';

  @override
  String get confirmPermanentDeleteMeeting =>
      'Confirm permanent meeting deletion';

  @override
  String get permanentlyDeleteThisMeeting => 'Permanently delete this meeting?';

  @override
  String get deleteThisMeetingMessage =>
      'This deletes the source recording, transcript, speaker labels, and processing records. It cannot be undone.';

  @override
  String get deleteAllData => 'Delete all data';

  @override
  String get edit => 'Edit';

  @override
  String get transcriptRevisionDescription =>
      'Saving creates a new final transcript version. Source audio and the timeline remain unchanged.';

  @override
  String get noRecognizedSpeech => 'No speech content is available to display.';

  @override
  String get speaker => 'Speaker';

  @override
  String get transcriptContent => 'Transcript content';

  @override
  String get speakersTitle => 'Speakers';

  @override
  String get noSpeakerSegments => 'No speaker segments';

  @override
  String speakerSegmentCount(int speakers, int segments) {
    String _temp0 = intl.Intl.pluralLogic(
      speakers,
      locale: localeName,
      other: '$speakers speakers',
      one: '1 speaker',
    );
    String _temp1 = intl.Intl.pluralLogic(
      segments,
      locale: localeName,
      other: '$segments segments',
      one: '1 segment',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get manage => 'Manage';

  @override
  String get closeSpeakerManagement => 'Close speaker management panel';

  @override
  String get speakerReprocessing =>
      'Reprocessing speakers. The final transcript remains available.';

  @override
  String get speakerModelUnavailable =>
      'The on-device speaker model is unavailable.';

  @override
  String get speakerModelUnavailableManual =>
      'The on-device speaker model is unavailable. Labels can still be edited manually.';

  @override
  String get speakerAutoDisabled =>
      'Automatic separation is off. Existing labels are unchanged.';

  @override
  String get speakerDegradedSingle =>
      'Automatic separation did not complete. The result currently uses one speaker.';

  @override
  String get speakerDegradedEditable =>
      'Automatic separation did not complete. Current labels can still be viewed and edited.';

  @override
  String get editSpeakerLabel => 'Edit speaker label';

  @override
  String get speakerManagement => 'Speaker management';

  @override
  String get editSpeakerDescription =>
      'Only the display label changes. Source audio, transcript content, and timeline remain unchanged.';

  @override
  String get speakerManagementDescription =>
      'Automatic separation and label edits never change source audio or the transcript timeline.';

  @override
  String get displayName => 'Display name';

  @override
  String get speakerNameHint => 'Enter a speaker name';

  @override
  String get speakerLabelSaveFailed =>
      'The label was not saved. Check the name and try again.';

  @override
  String get automaticSpeakerSeparation => 'Automatic speaker separation';

  @override
  String get automaticSpeakerSeparationDescription =>
      'When off, automatic processing stops and existing labels remain unchanged.';

  @override
  String get speakerUnavailableNoLabels =>
      'The on-device speaker model is unavailable and there are no labels to manage.';

  @override
  String get speakerUnavailableExistingLabels =>
      'The on-device speaker model is unavailable. Existing labels can still be edited manually.';

  @override
  String get speakerSeparationProcessing => 'Speaker separation in progress';

  @override
  String get status => 'Status';

  @override
  String get reprocess => 'Reprocess';

  @override
  String get labels => 'Labels';

  @override
  String get noEditableSpeakerLabels =>
      'No speaker labels are available to edit.';

  @override
  String get speakerLabelsSemantics => 'Speaker labels';

  @override
  String get startupStoppedForData => 'Startup stopped to protect local data.';

  @override
  String get cannotReadLocalData => 'Could not read local data';

  @override
  String get cleanupNotRun =>
      'Automatic cleanup did not run. Check device storage and try again.';

  @override
  String get localInitializationIncomplete =>
      'Local capabilities did not finish initializing.';

  @override
  String get localCapabilitiesNotReady => 'Local capabilities are not ready';

  @override
  String get ensureStorageRetry =>
      'Make sure the device has enough space and try again.';

  @override
  String preparingMeetTraceStage(String stage) {
    return 'Preparing MeetTrace, $stage';
  }

  @override
  String get preparingMeetTrace => 'Preparing MeetTrace';

  @override
  String stepOfFour(int step) {
    return 'Step $step of 4';
  }

  @override
  String get offlineResourcePreparationProgress =>
      'Offline transcription resource preparation progress';

  @override
  String get localEvidencePreserved =>
      'Meeting records and source audio remain on this device';

  @override
  String get agreeAndDownload => 'Agree and download';

  @override
  String get avoidMobileNetwork => 'Do not use mobile data';

  @override
  String get continueDownload => 'Continue download';

  @override
  String get retry => 'Retry';

  @override
  String get openLocalWorkspace => 'Open local workspace';

  @override
  String get openLocalWorkspaceDescription =>
      'Restoring meeting records and checking local data.';

  @override
  String get checkOfflineResources => 'Check offline resources';

  @override
  String get checkOfflineResourcesDescription =>
      'Checking local files against the fixed resource manifest.';

  @override
  String get awaitNetworkConfirmation => 'Await network confirmation';

  @override
  String get awaitNetworkConfirmationDescription =>
      'Confirm the network to start downloading.';

  @override
  String get freeDeviceSpace => 'Free device space';

  @override
  String get freeDeviceSpaceDescription =>
      'Free enough space, then check again.';

  @override
  String get downloadOfflineResources => 'Download offline resources';

  @override
  String get downloadOfflineResourcesDescription =>
      'Downloads can be paused. Completed parts are preserved.';

  @override
  String get downloadPaused => 'Download paused';

  @override
  String get downloadPausedDescription =>
      'Continuing resumes from the current progress.';

  @override
  String get verifyResourceIntegrity => 'Verify resource integrity';

  @override
  String get verifyResourceIntegrityDescription =>
      'Checking file sizes and integrity.';

  @override
  String get enableOfflineTranscription => 'Enable offline transcription';

  @override
  String get enableOfflineTranscriptionDescription =>
      'Loading local inference capabilities.';

  @override
  String get resourcePreparationIncomplete => 'Resource preparation incomplete';

  @override
  String get resourcePreparationIncompleteDescription =>
      'Review the message and try again.';

  @override
  String get offlineTranscriptionReady => 'Offline transcription ready';

  @override
  String get offlineTranscriptionReadyDescription => 'Entering MeetTrace.';

  @override
  String get startupLocalCapabilitiesIncomplete =>
      'MeetTrace local capability preparation incomplete';

  @override
  String get startupNeedsAttention => 'Startup needs your attention';

  @override
  String get updateClearsLocalData => 'Update clears local data';

  @override
  String get newVersionFound => 'New MeetTrace version found';

  @override
  String get confirmUpdateDataRisk =>
      'Confirm the local data risk before updating';

  @override
  String get newVersionPassedReleaseGate =>
      'The new version passed the public release gate';

  @override
  String destructiveUpdateMessage(String version, int build) {
    return 'Version $version (build $build) raises the data generation. On first launch after installation, the app clears local meeting audio, transcripts, models, and settings, then initializes again. Share or export anything you need first.';
  }

  @override
  String updateReadyMessage(String version, int build) {
    return 'Version $version (build $build) is ready. Continuing hands off to the system installer, TestFlight, or Microsoft Store, which may still request confirmation.';
  }

  @override
  String get handleLater => 'Later';

  @override
  String get confirmRiskContinue => 'Confirm risk and continue';

  @override
  String get continueUpdate => 'Continue update';

  @override
  String get updateHandedToSystem => 'Handed off to system update';

  @override
  String get updateDoesNotForceInterrupt =>
      'Recording and local data are not forcibly interrupted in the app';

  @override
  String get updateDeferred => 'Update deferred';

  @override
  String get updateDeferredDescription =>
      'The app will prompt again after recording or final processing ends';

  @override
  String get cannotOpenSystemUpdate => 'Could not open system update';

  @override
  String get checkSystemInstallAuthorization =>
      'Check system installation authorization and try again';

  @override
  String get unexpectedError => 'The operation did not complete. Try again.';

  @override
  String get finalTranscriptStatusLoadFailed =>
      'Could not load final transcript status. Try again.';

  @override
  String audioShareSpaceShortage(String shortage) {
    return 'Insufficient available space. $shortage more is required; no temporary file was kept.';
  }

  @override
  String get themeSaveFailedMessage => 'The previous theme was restored.';

  @override
  String get senseVoiceNotReady =>
      'SenseVoice is not installed or did not pass verification';

  @override
  String get scanningMicrophones => 'Scanning microphones';

  @override
  String get noOtherMicrophonesFound => 'No other microphones found';

  @override
  String windowsInputDeviceCount(int count) {
    return 'Found $count Windows input devices';
  }

  @override
  String get cannotReadWindowsMicrophones =>
      'Could not read Windows microphones. Check system microphone permission and try again.';

  @override
  String get microphoneScanFailed => 'Microphone scan failed';

  @override
  String get microphonePreferenceSaveFailed =>
      'Could not save the microphone preference. Try again.';

  @override
  String get modelStatusReadFailed => 'Could not read model status';

  @override
  String get modelSettingsLoadFailed => 'Could not load model settings';

  @override
  String get operationFailedRetry => 'Operation failed. Try again.';

  @override
  String get storageUsageReadFailed => 'Could not read storage usage';

  @override
  String get diagnosticsShareOpened =>
      'The system share panel opened. Diagnostics do not include titles, transcripts, audio, or local paths.';

  @override
  String get diagnosticsExportFailed =>
      'Could not export diagnostics. Try again.';

  @override
  String get preparingLocalData => 'Preparing local data';

  @override
  String get mobileDataDeclined =>
      'Mobile data is not being used. Connect to Wi-Fi and try again. Existing meeting data is unchanged.';

  @override
  String get continuingDownload =>
      'Continuing from the current download progress';

  @override
  String get checkingLocalTranscriptionResources =>
      'Checking local transcription resources';

  @override
  String get offlineResourcesFailed =>
      'Could not prepare offline transcription resources. Try again.';

  @override
  String retryFailedPrefix(String message) {
    return 'Retry did not succeed: $message';
  }

  @override
  String get runtimeInitializationFailed =>
      'Could not initialize the offline speech runtime. Try again.';

  @override
  String get runtimeResourcesOverLimit =>
      'Fixed runtime resources exceed 300,000,000 bytes and require a PRD review';

  @override
  String get checkingLocalRuntimeResources =>
      'Checking local runtime resources';

  @override
  String initializationSpaceShortage(String bytes) {
    return 'Initialization requires at least 1 GiB of available space. $bytes bytes are missing.';
  }

  @override
  String get initializationNeedsNetwork =>
      'The first initialization requires a network connection to download offline runtime resources';

  @override
  String mobileDownloadWarning(String megabytes) {
    return 'Downloading about $megabytes MB over mobile data may incur charges. The download can be paused and resumed.';
  }

  @override
  String get downloadPausedChunksPreserved =>
      'Download paused. Completed chunks are preserved.';

  @override
  String get modelDownloadHttpsOnly => 'Model downloads require HTTPS.';

  @override
  String modelFileDownloadHttpError(String status) {
    return 'Model file download failed with HTTP $status.';
  }

  @override
  String get modelDownloadResumeRangeInvalid =>
      'The server returned an incompatible resume range.';

  @override
  String get modelFileExceedsManifestSize =>
      'The server returned a model file larger than the manifest size.';

  @override
  String get modelFileDownloadTimeout =>
      'The model file download timed out. Try again.';

  @override
  String get modelFileMissing => 'A required model file is missing.';

  @override
  String modelFileSizeMismatch(String expected, String actual) {
    return 'A model file should be $expected bytes but is $actual bytes.';
  }

  @override
  String get modelFileShaMismatch =>
      'A model file failed SHA-256 verification.';

  @override
  String get modelFileNotInManifest =>
      'A model file is not listed in the manifest.';

  @override
  String modelFileDownloadIncomplete(String path) {
    return '$path did not finish downloading.';
  }

  @override
  String runtimeResourcePreparationError(String detail) {
    return 'Runtime resource preparation failed: $detail';
  }

  @override
  String get modelIntegrityFailed =>
      'Model file verification failed. Retry to download and repair the files.';

  @override
  String get modelPathInvalid =>
      'A model file path is invalid. Retry resource repair.';

  @override
  String get modelPreparationFailed =>
      'Runtime resource preparation failed. Try again.';

  @override
  String get modelDownloadFailedRetry => 'Model download failed. Try again.';

  @override
  String get recordingCannotStart =>
      'Recording could not start. Check microphone permission and available storage.';

  @override
  String get pauseRecordingFailed =>
      'Could not pause recording. Recording state did not change.';

  @override
  String get resumeRecordingFailed =>
      'Could not resume recording. End the meeting to preserve existing audio.';

  @override
  String get audioSealFailed =>
      'Could not seal audio. Preserve app data and retry recovery.';

  @override
  String get speakerLabelSaved => 'Speaker label saved';

  @override
  String get speakerLabelSaveRetry =>
      'Could not save the speaker label. Try again.';

  @override
  String get transcriptRevisionSaved =>
      'Transcript revision saved as a new version';

  @override
  String get transcriptRevisionSaveFailed =>
      'Could not save the transcript revision. Check the content and try again.';

  @override
  String get speakerSeparationCompleted => 'Speaker separation completed';

  @override
  String get speakerSeparationDegraded =>
      'Speaker separation failed. The result uses one speaker and the final transcript is unaffected.';

  @override
  String get finalTranscriptionFailedPreserved =>
      'Final transcription failed. Source audio and the previous result are preserved.';

  @override
  String get speakerSeparationFailedRetry =>
      'Speaker separation failed. The final transcript remains available; try again later.';

  @override
  String get sourceAudioPlaybackFailed => 'Could not play source audio';

  @override
  String get sharePanelOpenedNoAudio =>
      'The system share panel opened. Original audio is not included.';

  @override
  String get shareFailedRetry => 'Sharing failed. Try again.';

  @override
  String get cannotReadAudioOrSpace =>
      'Could not read source audio or available space. Try again.';

  @override
  String get audioShareCompletedCleaned =>
      'Audio sharing completed and temporary files were removed';

  @override
  String get audioShareCancelledCleaned =>
      'Audio sharing was canceled and temporary files were removed';

  @override
  String get audioShareOutcomeUnavailable =>
      'The system share panel opened, but the platform did not return a result. Temporary files were removed.';

  @override
  String get audioShareFailedCleaned =>
      'Audio sharing failed. Temporary files were removed. Try again.';

  @override
  String get audioShareCleanupFailed =>
      'Could not remove temporary audio sharing files. Restart the app and try again.';

  @override
  String get meetingDerivedDataDeleted =>
      'Meeting and local derived data deleted';

  @override
  String get meetingDeleteIncomplete =>
      'Meeting deletion did not complete. Try again.';

  @override
  String get deleteFailedPreserved =>
      'Deletion failed. Meeting data is preserved.';

  @override
  String get renameFailedOriginalPreserved =>
      'Renaming failed. The original meeting title is preserved.';

  @override
  String get cannotStartMeeting => 'Could not start meeting';

  @override
  String get defaultModelTemporarilyUnavailable =>
      'The default model is temporarily unavailable. Check it in Settings.';

  @override
  String get senseVoiceInitializationRepair =>
      'SenseVoice initialization failed. Returning to resource repair.';

  @override
  String get meetingStartFailed =>
      'Could not start the meeting. Check recording permission, storage, and the default model, then try again.';

  @override
  String get noMicrophoneAvailable =>
      'No microphone is available. Connect or enable an input device and try again.';

  @override
  String get preferredMicrophoneUnavailable =>
      'The selected microphone is unavailable. Select another one in Settings.';

  @override
  String get microphoneCurrentlyUnavailable =>
      'The microphone is unavailable. Check the input device and try again.';

  @override
  String get microphonePermissionStartRequirement =>
      'Microphone permission is required. A meeting is created only after permission is granted.';

  @override
  String get storageStartRequirement =>
      'Insufficient storage. Keep at least 128 MB available and try again.';

  @override
  String get senseVoiceNeedsRepair =>
      'SenseVoice is not ready. Return to initialization to verify and repair it.';

  @override
  String get recordingStartMicrophoneRetry =>
      'Recording could not start. Confirm that a microphone is available and try again.';

  @override
  String get microphonePermissionDenied =>
      'Could not use the microphone. Grant microphone permission in system settings and try again.';

  @override
  String get recordingStorageInsufficient =>
      'Insufficient storage. Keep at least 128 MB available and try again.';

  @override
  String get recordingInputUnavailable =>
      'No microphone is available. Connect or enable an input device and try again.';

  @override
  String get recordingAudioAlreadyExists =>
      'This meeting already has source audio. Recording stopped to avoid overwriting it.';

  @override
  String get speakerDiarizationResource => 'Speaker separation';

  @override
  String audioShareSystemTitle(String title) {
    return 'Share meeting recording: $title';
  }
}
