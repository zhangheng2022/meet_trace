import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'会迹 MeetTrace'**
  String get appName;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @moreSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'More settings'**
  String get moreSettingsTitle;

  /// No description provided for @backToMeetings.
  ///
  /// In en, this message translates to:
  /// **'Back to meetings'**
  String get backToMeetings;

  /// No description provided for @appearanceLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance and language'**
  String get appearanceLanguageTitle;

  /// No description provided for @languageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageSectionTitle;

  /// No description provided for @languageSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Language setting not saved'**
  String get languageSaveFailedTitle;

  /// No description provided for @languageSaveFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'The previous language has been restored.'**
  String get languageSaveFailedMessage;

  /// No description provided for @languageOptionsSemantics.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageOptionsSemantics;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @languageSystemDescription.
  ///
  /// In en, this message translates to:
  /// **'Use Chinese for Chinese system locales; otherwise use English'**
  String get languageSystemDescription;

  /// No description provided for @languageSimplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageSimplifiedChinese;

  /// No description provided for @languageSimplifiedChineseDescription.
  ///
  /// In en, this message translates to:
  /// **'Always use Simplified Chinese'**
  String get languageSimplifiedChineseDescription;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageEnglishDescription.
  ///
  /// In en, this message translates to:
  /// **'Always use English'**
  String get languageEnglishDescription;

  /// No description provided for @appearanceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance mode'**
  String get appearanceSectionTitle;

  /// No description provided for @themeSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme setting not saved'**
  String get themeSaveFailedTitle;

  /// No description provided for @themeOptionsSemantics.
  ///
  /// In en, this message translates to:
  /// **'Appearance theme'**
  String get themeOptionsSemantics;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystemDescription.
  ///
  /// In en, this message translates to:
  /// **'Match the device appearance automatically'**
  String get themeSystemDescription;

  /// No description provided for @themeLightDescription.
  ///
  /// In en, this message translates to:
  /// **'Always use the light appearance'**
  String get themeLightDescription;

  /// No description provided for @themeDarkDescription.
  ///
  /// In en, this message translates to:
  /// **'Always use the dark appearance'**
  String get themeDarkDescription;

  /// No description provided for @modelSettingsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Model settings incomplete'**
  String get modelSettingsIncomplete;

  /// No description provided for @meetingDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting defaults'**
  String get meetingDefaultsTitle;

  /// No description provided for @newMeetingTranscriptionModel.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition engine'**
  String get newMeetingTranscriptionModel;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @modelLockDescription.
  ///
  /// In en, this message translates to:
  /// **'Future meetings only; locked after recording starts—no automatic switching.'**
  String get modelLockDescription;

  /// No description provided for @recordingInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording input'**
  String get recordingInputTitle;

  /// No description provided for @recordingInputDescription.
  ///
  /// In en, this message translates to:
  /// **'This selection is locked when a new meeting starts. If the device disconnects during a meeting, the app falls back to the system default microphone once.'**
  String get recordingInputDescription;

  /// No description provided for @microphoneSettingsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Microphone setting incomplete'**
  String get microphoneSettingsIncomplete;

  /// No description provided for @readingWindowsMicrophones.
  ///
  /// In en, this message translates to:
  /// **'Reading Windows microphones'**
  String get readingWindowsMicrophones;

  /// No description provided for @windowsRecordingDevices.
  ///
  /// In en, this message translates to:
  /// **'Windows recording input devices'**
  String get windowsRecordingDevices;

  /// No description provided for @systemDefaultMicrophone.
  ///
  /// In en, this message translates to:
  /// **'System default microphone'**
  String get systemDefaultMicrophone;

  /// No description provided for @systemDefaultMicrophoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Resolved by Windows when each meeting starts'**
  String get systemDefaultMicrophoneDescription;

  /// No description provided for @microphoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Currently unavailable. Connect the device or select another microphone.'**
  String get microphoneUnavailable;

  /// No description provided for @windowsInputDevice.
  ///
  /// In en, this message translates to:
  /// **'Windows input device'**
  String get windowsInputDevice;

  /// No description provided for @noOtherMicrophones.
  ///
  /// In en, this message translates to:
  /// **'No other microphones were found. You can still use the system default microphone.'**
  String get noOtherMicrophones;

  /// No description provided for @rescanningWindowsMicrophones.
  ///
  /// In en, this message translates to:
  /// **'Rescanning Windows microphones'**
  String get rescanningWindowsMicrophones;

  /// No description provided for @rescanMicrophones.
  ///
  /// In en, this message translates to:
  /// **'Rescan microphones'**
  String get rescanMicrophones;

  /// No description provided for @offlineResourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Local resources'**
  String get offlineResourcesTitle;

  /// No description provided for @readingOfflineResources.
  ///
  /// In en, this message translates to:
  /// **'Reading offline transcription resources'**
  String get readingOfflineResources;

  /// No description provided for @noOfflineResources.
  ///
  /// In en, this message translates to:
  /// **'No offline transcription resources are available.'**
  String get noOfflineResources;

  /// No description provided for @modelVersionAutoLanguage.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · Automatic language detection{itn}'**
  String modelVersionAutoLanguage(String version, String itn);

  /// No description provided for @itnEnabledSuffix.
  ///
  /// In en, this message translates to:
  /// **' · ITN enabled'**
  String get itnEnabledSuffix;

  /// No description provided for @downloadAndRepair.
  ///
  /// In en, this message translates to:
  /// **'Download and repair'**
  String get downloadAndRepair;

  /// No description provided for @pauseDownload.
  ///
  /// In en, this message translates to:
  /// **'Pause download'**
  String get pauseDownload;

  /// No description provided for @continueOrRetry.
  ///
  /// In en, this message translates to:
  /// **'Continue or retry'**
  String get continueOrRetry;

  /// No description provided for @verifyAndUpdate.
  ///
  /// In en, this message translates to:
  /// **'Verify and update'**
  String get verifyAndUpdate;

  /// No description provided for @offlineResourceProgress.
  ///
  /// In en, this message translates to:
  /// **'{status} offline transcription resources'**
  String offlineResourceProgress(String status);

  /// No description provided for @offlineResourceStatus.
  ///
  /// In en, this message translates to:
  /// **'{status}, offline transcription resource status'**
  String offlineResourceStatus(String status);

  /// No description provided for @modelMaintenanceActions.
  ///
  /// In en, this message translates to:
  /// **'Model maintenance actions'**
  String get modelMaintenanceActions;

  /// No description provided for @verifyAndRepair.
  ///
  /// In en, this message translates to:
  /// **'Verify and repair'**
  String get verifyAndRepair;

  /// No description provided for @verifyAndRepairDescription.
  ///
  /// In en, this message translates to:
  /// **'Check local file integrity and download again if needed'**
  String get verifyAndRepairDescription;

  /// No description provided for @maintainOfflineResources.
  ///
  /// In en, this message translates to:
  /// **'Maintain offline transcription resources'**
  String get maintainOfflineResources;

  /// No description provided for @maintainResources.
  ///
  /// In en, this message translates to:
  /// **'Maintain resources'**
  String get maintainResources;

  /// No description provided for @storagePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage and privacy'**
  String get storagePrivacyTitle;

  /// No description provided for @readingLocalStorage.
  ///
  /// In en, this message translates to:
  /// **'Reading local storage usage'**
  String get readingLocalStorage;

  /// No description provided for @storageReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read storage usage'**
  String get storageReadFailed;

  /// No description provided for @storageUnchangedRetry.
  ///
  /// In en, this message translates to:
  /// **'Local data was not changed. You can read it again.'**
  String get storageUnchangedRetry;

  /// No description provided for @readAgain.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get readAgain;

  /// No description provided for @storageAppTotal.
  ///
  /// In en, this message translates to:
  /// **'App total'**
  String get storageAppTotal;

  /// No description provided for @storageMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meeting data'**
  String get storageMeetings;

  /// No description provided for @storageModels.
  ///
  /// In en, this message translates to:
  /// **'Model data'**
  String get storageModels;

  /// No description provided for @storageDatabase.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get storageDatabase;

  /// No description provided for @storageDeviceAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available on device'**
  String get storageDeviceAvailable;

  /// No description provided for @localStoragePrivacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Meeting recordings, final transcripts, and runtime resources remain on this device. Uninstalling the app may permanently delete them.'**
  String get localStoragePrivacyDescription;

  /// No description provided for @remoteDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote diagnostics'**
  String get remoteDiagnosticsTitle;

  /// No description provided for @remoteDiagnosticsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Allow anonymous error and performance diagnostics'**
  String get remoteDiagnosticsEnabled;

  /// No description provided for @remoteDiagnosticsDescription.
  ///
  /// In en, this message translates to:
  /// **'On by default. Turning it off stops new errors, performance traces, and metrics. Cached or uploaded data cannot be recalled; Windows native crash handling is fully off by the next launch at the latest.'**
  String get remoteDiagnosticsDescription;

  /// No description provided for @remoteDiagnosticsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The setting was not applied. This screen was restored; the next launch uses the value saved on this device.'**
  String get remoteDiagnosticsSaveFailed;

  /// No description provided for @remoteDiagnosticsNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous remote diagnostics are on by default'**
  String get remoteDiagnosticsNoticeTitle;

  /// No description provided for @remoteDiagnosticsNoticeDescription.
  ///
  /// In en, this message translates to:
  /// **'MeetTrace sends scrubbed errors and performance data, never recordings or transcripts. You can turn this off in Settings; cached or uploaded data cannot be recalled.'**
  String get remoteDiagnosticsNoticeDescription;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsShareSubject.
  ///
  /// In en, this message translates to:
  /// **'MeetTrace diagnostics'**
  String get diagnosticsShareSubject;

  /// No description provided for @viewShareDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'View and share diagnostics'**
  String get viewShareDiagnostics;

  /// No description provided for @diagnosticsContents.
  ///
  /// In en, this message translates to:
  /// **'Contains only status, usage, model versions, and error codes'**
  String get diagnosticsContents;

  /// No description provided for @confirmShareDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Confirm sharing diagnostics'**
  String get confirmShareDiagnostics;

  /// No description provided for @shareDiagnosticsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Share diagnostics?'**
  String get shareDiagnosticsQuestion;

  /// No description provided for @diagnosticsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics do not include meeting titles, final transcripts, source audio, or local paths.'**
  String get diagnosticsPrivacy;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @viewAndShare.
  ///
  /// In en, this message translates to:
  /// **'View and share'**
  String get viewAndShare;

  /// No description provided for @modelStatusNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get modelStatusNotDownloaded;

  /// No description provided for @modelStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get modelStatusChecking;

  /// No description provided for @modelStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get modelStatusDownloading;

  /// No description provided for @modelStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get modelStatusPaused;

  /// No description provided for @modelStatusVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get modelStatusVerifying;

  /// No description provided for @modelStatusInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get modelStatusInstalled;

  /// No description provided for @modelStatusUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get modelStatusUpdateAvailable;

  /// No description provided for @modelStatusDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting'**
  String get modelStatusDeleting;

  /// No description provided for @modelStatusDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get modelStatusDownloadFailed;

  /// No description provided for @modelStatusInsufficientSpace.
  ///
  /// In en, this message translates to:
  /// **'Insufficient space'**
  String get modelStatusInsufficientSpace;

  /// No description provided for @languageChineseShort.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChineseShort;

  /// No description provided for @languageCantoneseShort.
  ///
  /// In en, this message translates to:
  /// **'Cantonese'**
  String get languageCantoneseShort;

  /// No description provided for @languageEnglishShort.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishShort;

  /// No description provided for @languageJapaneseShort.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapaneseShort;

  /// No description provided for @languageKoreanShort.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKoreanShort;

  /// No description provided for @modelLanguageSeparator.
  ///
  /// In en, this message translates to:
  /// **' · '**
  String get modelLanguageSeparator;

  /// No description provided for @semanticListSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get semanticListSeparator;

  /// No description provided for @semanticSentenceSeparator.
  ///
  /// In en, this message translates to:
  /// **'. '**
  String get semanticSentenceSeparator;

  /// No description provided for @shareLabelSeparator.
  ///
  /// In en, this message translates to:
  /// **': '**
  String get shareLabelSeparator;

  /// No description provided for @defaultMeetingTitle.
  ///
  /// In en, this message translates to:
  /// **'{dateTime} Meeting'**
  String defaultMeetingTitle(String dateTime);

  /// No description provided for @untitledMeeting.
  ///
  /// In en, this message translates to:
  /// **'Untitled meeting'**
  String get untitledMeeting;

  /// No description provided for @meetingTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Meeting time'**
  String get meetingTimeLabel;

  /// No description provided for @finalTranscriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Final transcript'**
  String get finalTranscriptTitle;

  /// No description provided for @speakerOne.
  ///
  /// In en, this message translates to:
  /// **'Speaker 1'**
  String get speakerOne;

  /// No description provided for @speakerNumber.
  ///
  /// In en, this message translates to:
  /// **'Speaker {number}'**
  String speakerNumber(int number);

  /// No description provided for @shareExportFooter.
  ///
  /// In en, this message translates to:
  /// **'Exported from the final transcript on this device by MeetTrace. Original audio is not included.'**
  String get shareExportFooter;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @meetingStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get meetingStatusPreparing;

  /// No description provided for @meetingStatusRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get meetingStatusRecording;

  /// No description provided for @meetingStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get meetingStatusProcessing;

  /// No description provided for @meetingStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get meetingStatusCompleted;

  /// No description provided for @meetingStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get meetingStatusFailed;

  /// No description provided for @meetingStatusGeneratingFinal.
  ///
  /// In en, this message translates to:
  /// **'Generating final transcript'**
  String get meetingStatusGeneratingFinal;

  /// No description provided for @meetingStatusProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed'**
  String get meetingStatusProcessingFailed;

  /// No description provided for @meetingStatusFailedAudioHint.
  ///
  /// In en, this message translates to:
  /// **'Failed · Open to check source audio'**
  String get meetingStatusFailedAudioHint;

  /// No description provided for @viewRecordingConditions.
  ///
  /// In en, this message translates to:
  /// **'View recording conditions'**
  String get viewRecordingConditions;

  /// No description provided for @recheckRecordingConditions.
  ///
  /// In en, this message translates to:
  /// **'Recheck recording conditions'**
  String get recheckRecordingConditions;

  /// No description provided for @localRecording.
  ///
  /// In en, this message translates to:
  /// **'Local recording'**
  String get localRecording;

  /// No description provided for @usesDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Uses the default model'**
  String get usesDefaultModel;

  /// No description provided for @checkingRecordingConditions.
  ///
  /// In en, this message translates to:
  /// **'Checking recording conditions'**
  String get checkingRecordingConditions;

  /// No description provided for @microphoneStorageDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Microphone, storage, and default model'**
  String get microphoneStorageDefaultModel;

  /// No description provided for @recordingConditionsReady.
  ///
  /// In en, this message translates to:
  /// **'Recording conditions are ready'**
  String get recordingConditionsReady;

  /// No description provided for @audioLocalModelAvailable.
  ///
  /// In en, this message translates to:
  /// **'Audio stays on this device · {model} is available'**
  String audioLocalModelAvailable(String model);

  /// No description provided for @defaultModel.
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get defaultModel;

  /// No description provided for @microphonePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required'**
  String get microphonePermissionRequired;

  /// No description provided for @authorizeWhenStarting.
  ///
  /// In en, this message translates to:
  /// **'Authorize when starting a meeting'**
  String get authorizeWhenStarting;

  /// No description provided for @storageInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient storage'**
  String get storageInsufficient;

  /// No description provided for @keepAtLeast128Mb.
  ///
  /// In en, this message translates to:
  /// **'Keep at least 128 MB available'**
  String get keepAtLeast128Mb;

  /// No description provided for @defaultModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Default model unavailable'**
  String get defaultModelUnavailable;

  /// No description provided for @currentModel.
  ///
  /// In en, this message translates to:
  /// **'Current model'**
  String get currentModel;

  /// No description provided for @modelNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'{model} needs attention'**
  String modelNeedsAttention(String model);

  /// No description provided for @cannotCheckRecordingConditions.
  ///
  /// In en, this message translates to:
  /// **'Could not check recording conditions'**
  String get cannotCheckRecordingConditions;

  /// No description provided for @tapToRecheck.
  ///
  /// In en, this message translates to:
  /// **'Tap to check again'**
  String get tapToRecheck;

  /// No description provided for @additionalIssues.
  ///
  /// In en, this message translates to:
  /// **'{primary}, plus {count} more'**
  String additionalIssues(String primary, int count);

  /// No description provided for @meetingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get meetingsTitle;

  /// No description provided for @meetingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 meeting} other{{count} meetings}}'**
  String meetingCount(int count);

  /// No description provided for @preparingRecording.
  ///
  /// In en, this message translates to:
  /// **'Preparing recording'**
  String get preparingRecording;

  /// No description provided for @startMeeting.
  ///
  /// In en, this message translates to:
  /// **'Start meeting'**
  String get startMeeting;

  /// No description provided for @preparingRecordingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Preparing recording…'**
  String get preparingRecordingEllipsis;

  /// No description provided for @loadingMeetings.
  ///
  /// In en, this message translates to:
  /// **'Loading meetings'**
  String get loadingMeetings;

  /// No description provided for @meetingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load meetings'**
  String get meetingLoadFailed;

  /// No description provided for @localDataPreservedRetry.
  ///
  /// In en, this message translates to:
  /// **'Local data is still on this device. Try again.'**
  String get localDataPreservedRetry;

  /// No description provided for @retryLoading.
  ///
  /// In en, this message translates to:
  /// **'Retry loading'**
  String get retryLoading;

  /// No description provided for @noMeetings.
  ///
  /// In en, this message translates to:
  /// **'No meetings yet'**
  String get noMeetings;

  /// No description provided for @noMeetingsDescription.
  ///
  /// In en, this message translates to:
  /// **'After you start recording, meetings are stored safely on this device.'**
  String get noMeetingsDescription;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameMeetingHint.
  ///
  /// In en, this message translates to:
  /// **'Open the meeting title editor'**
  String get renameMeetingHint;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteMeetingHint.
  ///
  /// In en, this message translates to:
  /// **'Open permanent deletion confirmation'**
  String get deleteMeetingHint;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @closeRecordingConditions.
  ///
  /// In en, this message translates to:
  /// **'Close recording conditions panel'**
  String get closeRecordingConditions;

  /// No description provided for @permanentlyDeleteMeetingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {title}'**
  String permanentlyDeleteMeetingSemantics(String title);

  /// No description provided for @permanentlyDeleteMeetingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete “{title}”?'**
  String permanentlyDeleteMeetingQuestion(String title);

  /// No description provided for @permanentlyDeleteMeetingMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the source audio, transcript, speaker labels, and processing records for this meeting. This cannot be undone.'**
  String get permanentlyDeleteMeetingMessage;

  /// No description provided for @permanentlyDelete.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete'**
  String get permanentlyDelete;

  /// No description provided for @meetingLocalDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'Meeting and local data deleted'**
  String get meetingLocalDataDeleted;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion failed'**
  String get deleteFailed;

  /// No description provided for @meetingCannotDeleteNow.
  ///
  /// In en, this message translates to:
  /// **'A meeting that is recording or processing cannot be deleted yet.'**
  String get meetingCannotDeleteNow;

  /// No description provided for @closeRenameMeeting.
  ///
  /// In en, this message translates to:
  /// **'Close rename meeting panel'**
  String get closeRenameMeeting;

  /// No description provided for @meetingTitleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Meeting title updated'**
  String get meetingTitleUpdated;

  /// No description provided for @brandSemantics.
  ///
  /// In en, this message translates to:
  /// **'MeetTrace'**
  String get brandSemantics;

  /// No description provided for @renameMeetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename meeting'**
  String get renameMeetingTitle;

  /// No description provided for @meetingTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a meeting title'**
  String get meetingTitleRequired;

  /// No description provided for @meetingTitleSingleLine.
  ///
  /// In en, this message translates to:
  /// **'The meeting title must be one line'**
  String get meetingTitleSingleLine;

  /// No description provided for @meetingTitleMaxLength.
  ///
  /// In en, this message translates to:
  /// **'The meeting title can contain at most {count} characters'**
  String meetingTitleMaxLength(int count);

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get saving;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @meetingTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Meeting title'**
  String get meetingTitleLabel;

  /// No description provided for @meetingTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a meeting title'**
  String get meetingTitleHint;

  /// No description provided for @renameFailedPreserved.
  ///
  /// In en, this message translates to:
  /// **'Renaming failed. The original meeting title is preserved. Try again.'**
  String get renameFailedPreserved;

  /// No description provided for @recordingConditionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording conditions'**
  String get recordingConditionsTitle;

  /// No description provided for @recordingConditionsDescription.
  ///
  /// In en, this message translates to:
  /// **'The app checks again before starting a meeting. Recording and transcription resources remain on this device.'**
  String get recordingConditionsDescription;

  /// No description provided for @recordingConditionsDetails.
  ///
  /// In en, this message translates to:
  /// **'Recording condition details'**
  String get recordingConditionsDetails;

  /// No description provided for @recordingConditionsStatus.
  ///
  /// In en, this message translates to:
  /// **'Recording condition status'**
  String get recordingConditionsStatus;

  /// No description provided for @microphonePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission'**
  String get microphonePermission;

  /// No description provided for @canRecordMeetingAudio.
  ///
  /// In en, this message translates to:
  /// **'The app can record meeting audio'**
  String get canRecordMeetingAudio;

  /// No description provided for @meetingNotCreatedBeforePermission.
  ///
  /// In en, this message translates to:
  /// **'No meeting is created before you authorize access'**
  String get meetingNotCreatedBeforePermission;

  /// No description provided for @authorized.
  ///
  /// In en, this message translates to:
  /// **'Authorized'**
  String get authorized;

  /// No description provided for @awaitingAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Awaiting authorization'**
  String get awaitingAuthorization;

  /// No description provided for @localStorage.
  ///
  /// In en, this message translates to:
  /// **'Local storage'**
  String get localStorage;

  /// No description provided for @spaceAvailable.
  ///
  /// In en, this message translates to:
  /// **'Enough space'**
  String get spaceAvailable;

  /// No description provided for @spaceInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Not enough space'**
  String get spaceInsufficient;

  /// No description provided for @offlineTranscription.
  ///
  /// In en, this message translates to:
  /// **'Offline transcription'**
  String get offlineTranscription;

  /// No description provided for @modelUsedForMeeting.
  ///
  /// In en, this message translates to:
  /// **'{model} is used for live and final transcription'**
  String modelUsedForMeeting(String model);

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @needsRepair.
  ///
  /// In en, this message translates to:
  /// **'Needs repair'**
  String get needsRepair;

  /// No description provided for @minimumStorageRequired.
  ///
  /// In en, this message translates to:
  /// **'Starting a meeting requires at least {minimum}'**
  String minimumStorageRequired(String minimum);

  /// No description provided for @availableStorageMinimum.
  ///
  /// In en, this message translates to:
  /// **'{available} available · {minimum} minimum'**
  String availableStorageMinimum(String available, String minimum);

  /// No description provided for @authorizeMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Authorize microphone'**
  String get authorizeMicrophone;

  /// No description provided for @recheck.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get recheck;

  /// No description provided for @repairOfflineResources.
  ///
  /// In en, this message translates to:
  /// **'Repair offline resources'**
  String get repairOfflineResources;

  /// No description provided for @selectMeeting.
  ///
  /// In en, this message translates to:
  /// **'Select a meeting'**
  String get selectMeeting;

  /// No description provided for @selectMeetingDescription.
  ///
  /// In en, this message translates to:
  /// **'Meeting facts, recording status, and model source appear here.'**
  String get selectMeetingDescription;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @recordingDuration.
  ///
  /// In en, this message translates to:
  /// **'Recording duration'**
  String get recordingDuration;

  /// No description provided for @sourceAudio.
  ///
  /// In en, this message translates to:
  /// **'Source audio'**
  String get sourceAudio;

  /// No description provided for @meetingModel.
  ///
  /// In en, this message translates to:
  /// **'Meeting model'**
  String get meetingModel;

  /// No description provided for @meetingFacts.
  ///
  /// In en, this message translates to:
  /// **'Meeting facts'**
  String get meetingFacts;

  /// No description provided for @liveTranscriptReferenceOnly.
  ///
  /// In en, this message translates to:
  /// **'Live transcription is for reference only'**
  String get liveTranscriptReferenceOnly;

  /// No description provided for @sourceAudioLocalFirst.
  ///
  /// In en, this message translates to:
  /// **'Source audio stays local'**
  String get sourceAudioLocalFirst;

  /// No description provided for @openFullRecord.
  ///
  /// In en, this message translates to:
  /// **'Open full record'**
  String get openFullRecord;

  /// No description provided for @openFullMeetingRecord.
  ///
  /// In en, this message translates to:
  /// **'Open full meeting record'**
  String get openFullMeetingRecord;

  /// No description provided for @recordingContinues.
  ///
  /// In en, this message translates to:
  /// **'Recording continues'**
  String get recordingContinues;

  /// No description provided for @audioNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Recording has not started'**
  String get audioNotStarted;

  /// No description provided for @audioWritingLocally.
  ///
  /// In en, this message translates to:
  /// **'Writing continuously on this device'**
  String get audioWritingLocally;

  /// No description provided for @audioSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get audioSavedLocally;

  /// No description provided for @audioSealing.
  ///
  /// In en, this message translates to:
  /// **'Sealing'**
  String get audioSealing;

  /// No description provided for @meetingProcessingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Meeting processing completed'**
  String get meetingProcessingCompleted;

  /// No description provided for @openMeetingForSaveStatus.
  ///
  /// In en, this message translates to:
  /// **'Open the meeting to check save status'**
  String get openMeetingForSaveStatus;

  /// No description provided for @factCreatedDescription.
  ///
  /// In en, this message translates to:
  /// **'Recording has not started. The meeting model is locked after it starts.'**
  String get factCreatedDescription;

  /// No description provided for @factRecordingDescription.
  ///
  /// In en, this message translates to:
  /// **'Source audio is being written continuously on this device. Slow or failed inference does not interrupt recording.'**
  String get factRecordingDescription;

  /// No description provided for @factProcessingDescription.
  ///
  /// In en, this message translates to:
  /// **'Source audio is sealed. The locked meeting model is generating the final transcript.'**
  String get factProcessingDescription;

  /// No description provided for @factFinalReadyDescription.
  ///
  /// In en, this message translates to:
  /// **'The final transcript is ready. Open the full record for speaker labels and timestamps.'**
  String get factFinalReadyDescription;

  /// No description provided for @factCompletedDescription.
  ///
  /// In en, this message translates to:
  /// **'Meeting processing completed. Open the full record to view the available result.'**
  String get factCompletedDescription;

  /// No description provided for @factDerivedFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Derived processing failed, but source audio remains on this device. Open the full record to review and retry.'**
  String get factDerivedFailedDescription;

  /// No description provided for @factMeetingFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Meeting processing failed. Open the full record to check the cause and source audio status.'**
  String get factMeetingFailedDescription;

  /// No description provided for @localModel.
  ///
  /// In en, this message translates to:
  /// **'Local model'**
  String get localModel;

  /// No description provided for @deleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting'**
  String get deleting;

  /// No description provided for @renaming.
  ///
  /// In en, this message translates to:
  /// **'Renaming'**
  String get renaming;

  /// No description provided for @openMeetingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Open meeting: {title}, {dateTime}, {status}'**
  String openMeetingSemantics(String title, String dateTime, String status);

  /// No description provided for @deletingLocalMeetingData.
  ///
  /// In en, this message translates to:
  /// **'Deleting local meeting data'**
  String get deletingLocalMeetingData;

  /// No description provided for @savingMeetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving the new meeting title'**
  String get savingMeetingTitle;

  /// No description provided for @viewFailureAndAudio.
  ///
  /// In en, this message translates to:
  /// **'View the failure and source audio status'**
  String get viewFailureAndAudio;

  /// No description provided for @viewMeetingDetails.
  ///
  /// In en, this message translates to:
  /// **'View meeting details'**
  String get viewMeetingDetails;

  /// No description provided for @swipeRenameDelete.
  ///
  /// In en, this message translates to:
  /// **'Swipe left to show rename and delete actions'**
  String get swipeRenameDelete;

  /// No description provided for @swipeRename.
  ///
  /// In en, this message translates to:
  /// **'Swipe left to show the rename action'**
  String get swipeRename;

  /// No description provided for @renameMeetingAction.
  ///
  /// In en, this message translates to:
  /// **'Rename meeting'**
  String get renameMeetingAction;

  /// No description provided for @deleteMeetingAction.
  ///
  /// In en, this message translates to:
  /// **'Delete meeting'**
  String get deleteMeetingAction;

  /// No description provided for @endMeetingAndReturn.
  ///
  /// In en, this message translates to:
  /// **'End meeting and return'**
  String get endMeetingAndReturn;

  /// No description provided for @endSaveMeetingSemantics.
  ///
  /// In en, this message translates to:
  /// **'End and save meeting'**
  String get endSaveMeetingSemantics;

  /// No description provided for @endSaveMeetingQuestion.
  ///
  /// In en, this message translates to:
  /// **'End and save meeting?'**
  String get endSaveMeetingQuestion;

  /// No description provided for @endSaveMeetingMessage.
  ///
  /// In en, this message translates to:
  /// **'The app first seals the local source audio, then generates the final transcript. The current live transcript is only a preview.'**
  String get endSaveMeetingMessage;

  /// No description provided for @continueRecording.
  ///
  /// In en, this message translates to:
  /// **'Continue recording'**
  String get continueRecording;

  /// No description provided for @endAndSave.
  ///
  /// In en, this message translates to:
  /// **'End and save'**
  String get endAndSave;

  /// No description provided for @startingRecording.
  ///
  /// In en, this message translates to:
  /// **'Starting recording'**
  String get startingRecording;

  /// No description provided for @liveTranscript.
  ///
  /// In en, this message translates to:
  /// **'Live transcript'**
  String get liveTranscript;

  /// No description provided for @segmentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 segment} other{{count} segments}}'**
  String segmentCount(int count);

  /// No description provided for @liveTranscriptReferenceFooter.
  ///
  /// In en, this message translates to:
  /// **'For reference only. The final transcript is generated after the meeting ends.'**
  String get liveTranscriptReferenceFooter;

  /// No description provided for @finalFromFullAudio.
  ///
  /// In en, this message translates to:
  /// **'The final transcript will still be generated from the complete audio after the meeting ends.'**
  String get finalFromFullAudio;

  /// No description provided for @speechAppearsHere.
  ///
  /// In en, this message translates to:
  /// **'Text appears here after speech is detected.'**
  String get speechAppearsHere;

  /// No description provided for @previewPausedWithRecording.
  ///
  /// In en, this message translates to:
  /// **'Paused with recording'**
  String get previewPausedWithRecording;

  /// No description provided for @previewNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get previewNormal;

  /// No description provided for @previewBacklogged.
  ///
  /// In en, this message translates to:
  /// **'Backlogged; recording continues'**
  String get previewBacklogged;

  /// No description provided for @previewStoppedRecordingContinues.
  ///
  /// In en, this message translates to:
  /// **'Stopped; recording continues'**
  String get previewStoppedRecordingContinues;

  /// No description provided for @previewEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get previewEnded;

  /// No description provided for @meetingLockedModelFallback.
  ///
  /// In en, this message translates to:
  /// **'Meeting model'**
  String get meetingLockedModelFallback;

  /// No description provided for @recordingErrorGuidance.
  ///
  /// In en, this message translates to:
  /// **'Keep the app data and use the available action. The source audio status is shown above.'**
  String get recordingErrorGuidance;

  /// No description provided for @meetingModelLocked.
  ///
  /// In en, this message translates to:
  /// **'{model} · Locked for this meeting'**
  String meetingModelLocked(String model);

  /// No description provided for @recordingStatePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing recording'**
  String get recordingStatePreparing;

  /// No description provided for @recordingStateRecovering.
  ///
  /// In en, this message translates to:
  /// **'Recovering'**
  String get recordingStateRecovering;

  /// No description provided for @recordingStateInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Recording interrupted'**
  String get recordingStateInterrupted;

  /// No description provided for @recordingStatePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recordingStatePaused;

  /// No description provided for @recordingStateSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get recordingStateSaving;

  /// No description provided for @recordingStateSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get recordingStateSaved;

  /// No description provided for @recordingStateError.
  ///
  /// In en, this message translates to:
  /// **'Recording error'**
  String get recordingStateError;

  /// No description provided for @recordingFactStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting source recording'**
  String get recordingFactStarting;

  /// No description provided for @recordingFactWriting.
  ///
  /// In en, this message translates to:
  /// **'Source audio is being written safely'**
  String get recordingFactWriting;

  /// No description provided for @recordingFactRecovering.
  ///
  /// In en, this message translates to:
  /// **'Input interrupted; switching to the system default microphone'**
  String get recordingFactRecovering;

  /// No description provided for @recordingFactInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Source recording stopped. End the meeting to preserve existing audio.'**
  String get recordingFactInterrupted;

  /// No description provided for @recordingFactPaused.
  ///
  /// In en, this message translates to:
  /// **'Source recording paused'**
  String get recordingFactPaused;

  /// No description provided for @recordingFactSealing.
  ///
  /// In en, this message translates to:
  /// **'Sealing source audio'**
  String get recordingFactSealing;

  /// No description provided for @recordingFactSaved.
  ///
  /// In en, this message translates to:
  /// **'Source audio saved'**
  String get recordingFactSaved;

  /// No description provided for @recordingFactError.
  ///
  /// In en, this message translates to:
  /// **'Source recording encountered an error'**
  String get recordingFactError;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @sealingAudio.
  ///
  /// In en, this message translates to:
  /// **'Sealing audio'**
  String get sealingAudio;

  /// No description provided for @endMeeting.
  ///
  /// In en, this message translates to:
  /// **'End meeting'**
  String get endMeeting;

  /// No description provided for @waveformWaitingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Microphone waveform, waiting for recording'**
  String get waveformWaitingSemantics;

  /// No description provided for @waveformWaitingLabel.
  ///
  /// In en, this message translates to:
  /// **'Microphone input · Waiting for recording'**
  String get waveformWaitingLabel;

  /// No description provided for @waveformLiveSemantics.
  ///
  /// In en, this message translates to:
  /// **'Microphone waveform, live feedback'**
  String get waveformLiveSemantics;

  /// No description provided for @waveformLiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Microphone input · Live feedback'**
  String get waveformLiveLabel;

  /// No description provided for @waveformPausedSemantics.
  ///
  /// In en, this message translates to:
  /// **'Microphone waveform, recording paused'**
  String get waveformPausedSemantics;

  /// No description provided for @waveformPausedLabel.
  ///
  /// In en, this message translates to:
  /// **'Microphone input · Paused'**
  String get waveformPausedLabel;

  /// No description provided for @waveformStoppedSemantics.
  ///
  /// In en, this message translates to:
  /// **'Microphone waveform, recording stopped'**
  String get waveformStoppedSemantics;

  /// No description provided for @waveformStoppedLabel.
  ///
  /// In en, this message translates to:
  /// **'Microphone input · Stopped'**
  String get waveformStoppedLabel;

  /// No description provided for @meetingDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting details'**
  String get meetingDetailsTitle;

  /// No description provided for @loadingMeetingResult.
  ///
  /// In en, this message translates to:
  /// **'Loading meeting result'**
  String get loadingMeetingResult;

  /// No description provided for @noFinalTranscript.
  ///
  /// In en, this message translates to:
  /// **'No final transcript'**
  String get noFinalTranscript;

  /// No description provided for @sourceAudioReturnLater.
  ///
  /// In en, this message translates to:
  /// **'Source audio remains on this device. Return later to continue processing.'**
  String get sourceAudioReturnLater;

  /// No description provided for @lastProcessingIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The latest processing attempt did not finish'**
  String get lastProcessingIncomplete;

  /// No description provided for @operationStatus.
  ///
  /// In en, this message translates to:
  /// **'Operation status'**
  String get operationStatus;

  /// No description provided for @factRecord.
  ///
  /// In en, this message translates to:
  /// **'FACT RECORD'**
  String get factRecord;

  /// No description provided for @sourceAudioSaved.
  ///
  /// In en, this message translates to:
  /// **'Source audio saved'**
  String get sourceAudioSaved;

  /// No description provided for @sourceAudioTimestampVerification.
  ///
  /// In en, this message translates to:
  /// **'The final transcript includes timestamps for checking against the original audio on this device.'**
  String get sourceAudioTimestampVerification;

  /// No description provided for @finalTranscriptIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Final transcript incomplete'**
  String get finalTranscriptIncomplete;

  /// No description provided for @retryFinalTranscript.
  ///
  /// In en, this message translates to:
  /// **'Retry final transcription'**
  String get retryFinalTranscript;

  /// No description provided for @finalShowsSpeakers.
  ///
  /// In en, this message translates to:
  /// **'The final transcript and speaker labels appear together when complete.'**
  String get finalShowsSpeakers;

  /// No description provided for @speakerSeparationUnavailableOutcome.
  ///
  /// In en, this message translates to:
  /// **'Speaker separation is unavailable. The result will use one speaker.'**
  String get speakerSeparationUnavailableOutcome;

  /// No description provided for @generatingFinalResult.
  ///
  /// In en, this message translates to:
  /// **'Generating final result'**
  String get generatingFinalResult;

  /// No description provided for @processingSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Generating final result. {model} is processing the complete recording. {outcome} Source audio is saved on this device. Processing never rewrites it.'**
  String processingSemanticsLabel(String model, String outcome);

  /// No description provided for @modelProcessingFullRecording.
  ///
  /// In en, this message translates to:
  /// **'{model} is processing the complete recording.'**
  String modelProcessingFullRecording(String model);

  /// No description provided for @sourceAudioNotRewritten.
  ///
  /// In en, this message translates to:
  /// **'Source audio is saved on this device. Processing never rewrites it.'**
  String get sourceAudioNotRewritten;

  /// No description provided for @stopPlayback.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get stopPlayback;

  /// No description provided for @playRecording.
  ///
  /// In en, this message translates to:
  /// **'Play recording'**
  String get playRecording;

  /// No description provided for @localSourceRecording.
  ///
  /// In en, this message translates to:
  /// **'Local source recording'**
  String get localSourceRecording;

  /// No description provided for @recordingLocalDuration.
  ///
  /// In en, this message translates to:
  /// **'Stored only on this device · {duration}'**
  String recordingLocalDuration(String duration);

  /// No description provided for @saveRevision.
  ///
  /// In en, this message translates to:
  /// **'Save revision'**
  String get saveRevision;

  /// No description provided for @shareMeeting.
  ///
  /// In en, this message translates to:
  /// **'Share meeting'**
  String get shareMeeting;

  /// No description provided for @closeShareMeeting.
  ///
  /// In en, this message translates to:
  /// **'Close share meeting panel'**
  String get closeShareMeeting;

  /// No description provided for @shareMeetingDescription.
  ///
  /// In en, this message translates to:
  /// **'Text includes only the final transcript. Sharing source audio requires separate confirmation.'**
  String get shareMeetingDescription;

  /// No description provided for @meetingShareMethods.
  ///
  /// In en, this message translates to:
  /// **'Meeting sharing methods'**
  String get meetingShareMethods;

  /// No description provided for @plainText.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get plainText;

  /// No description provided for @plainTextDescription.
  ///
  /// In en, this message translates to:
  /// **'Suitable for messages and email bodies'**
  String get plainTextDescription;

  /// No description provided for @markdownDescription.
  ///
  /// In en, this message translates to:
  /// **'Preserves the title, timestamps, and structure'**
  String get markdownDescription;

  /// No description provided for @shareAudioSeparately.
  ///
  /// In en, this message translates to:
  /// **'Share audio separately'**
  String get shareAudioSeparately;

  /// No description provided for @shareAudioSeparatelyDescription.
  ///
  /// In en, this message translates to:
  /// **'Creates a temporary WAV after another privacy confirmation'**
  String get shareAudioSeparatelyDescription;

  /// No description provided for @audioShareInsufficientSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough space to share audio'**
  String get audioShareInsufficientSpace;

  /// No description provided for @audioFileNameFallback.
  ///
  /// In en, this message translates to:
  /// **'Meeting recording'**
  String get audioFileNameFallback;

  /// No description provided for @availableSpaceInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient available space'**
  String get availableSpaceInsufficient;

  /// No description provided for @temporaryWavShortage.
  ///
  /// In en, this message translates to:
  /// **'Creating a temporary WAV requires {shortage} more. No file was created.'**
  String temporaryWavShortage(String shortage);

  /// No description provided for @confirmShareMeetingAudio.
  ///
  /// In en, this message translates to:
  /// **'Confirm sharing meeting audio'**
  String get confirmShareMeetingAudio;

  /// No description provided for @confirmShareAudioQuestion.
  ///
  /// In en, this message translates to:
  /// **'Share audio separately?'**
  String get confirmShareAudioQuestion;

  /// No description provided for @audioShareConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Meeting: {title}\nDuration: {duration}\nFile: {size} WAV\n\nThe recording may contain sensitive or private information. A temporary copy is created and the system share panel opens only after confirmation. Transcript text is not included.'**
  String audioShareConfirmation(String title, String duration, String size);

  /// No description provided for @generateAndShare.
  ///
  /// In en, this message translates to:
  /// **'Generate and share'**
  String get generateAndShare;

  /// No description provided for @moreMeetingActions.
  ///
  /// In en, this message translates to:
  /// **'More meeting actions'**
  String get moreMeetingActions;

  /// No description provided for @closeMoreMeetingActions.
  ///
  /// In en, this message translates to:
  /// **'Close more meeting actions'**
  String get closeMoreMeetingActions;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @moreActionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Less common actions are grouped here. Deleting a meeting cannot be undone.'**
  String get moreActionsDescription;

  /// No description provided for @regenerateTranscript.
  ///
  /// In en, this message translates to:
  /// **'Regenerate transcript'**
  String get regenerateTranscript;

  /// No description provided for @useLockedModel.
  ///
  /// In en, this message translates to:
  /// **'Continue using the locked {model} model'**
  String useLockedModel(String model);

  /// No description provided for @deleteMeeting.
  ///
  /// In en, this message translates to:
  /// **'Delete meeting'**
  String get deleteMeeting;

  /// No description provided for @deleteMeetingAllDerived.
  ///
  /// In en, this message translates to:
  /// **'Also deletes source audio and all derived results'**
  String get deleteMeetingAllDerived;

  /// No description provided for @confirmPermanentDeleteMeeting.
  ///
  /// In en, this message translates to:
  /// **'Confirm permanent meeting deletion'**
  String get confirmPermanentDeleteMeeting;

  /// No description provided for @permanentlyDeleteThisMeeting.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this meeting?'**
  String get permanentlyDeleteThisMeeting;

  /// No description provided for @deleteThisMeetingMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes the source recording, transcript, speaker labels, and processing records. It cannot be undone.'**
  String get deleteThisMeetingMessage;

  /// No description provided for @deleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get deleteAllData;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @transcriptRevisionDescription.
  ///
  /// In en, this message translates to:
  /// **'Saving creates a new final transcript version. Source audio and the timeline remain unchanged.'**
  String get transcriptRevisionDescription;

  /// No description provided for @noRecognizedSpeech.
  ///
  /// In en, this message translates to:
  /// **'No speech content is available to display.'**
  String get noRecognizedSpeech;

  /// No description provided for @speaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get speaker;

  /// No description provided for @transcriptContent.
  ///
  /// In en, this message translates to:
  /// **'Transcript content'**
  String get transcriptContent;

  /// No description provided for @speakersTitle.
  ///
  /// In en, this message translates to:
  /// **'Speakers'**
  String get speakersTitle;

  /// No description provided for @noSpeakerSegments.
  ///
  /// In en, this message translates to:
  /// **'No speaker segments'**
  String get noSpeakerSegments;

  /// No description provided for @speakerSegmentCount.
  ///
  /// In en, this message translates to:
  /// **'{speakers, plural, =1{1 speaker} other{{speakers} speakers}} · {segments, plural, =1{1 segment} other{{segments} segments}}'**
  String speakerSegmentCount(int speakers, int segments);

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @closeSpeakerManagement.
  ///
  /// In en, this message translates to:
  /// **'Close speaker management panel'**
  String get closeSpeakerManagement;

  /// No description provided for @speakerReprocessing.
  ///
  /// In en, this message translates to:
  /// **'Reprocessing speakers. The final transcript remains available.'**
  String get speakerReprocessing;

  /// No description provided for @speakerModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The on-device speaker model is unavailable.'**
  String get speakerModelUnavailable;

  /// No description provided for @speakerModelUnavailableManual.
  ///
  /// In en, this message translates to:
  /// **'The on-device speaker model is unavailable. Labels can still be edited manually.'**
  String get speakerModelUnavailableManual;

  /// No description provided for @speakerAutoDisabled.
  ///
  /// In en, this message translates to:
  /// **'Automatic separation is off. Existing labels are unchanged.'**
  String get speakerAutoDisabled;

  /// No description provided for @speakerDegradedSingle.
  ///
  /// In en, this message translates to:
  /// **'Automatic separation did not complete. The result currently uses one speaker.'**
  String get speakerDegradedSingle;

  /// No description provided for @speakerDegradedEditable.
  ///
  /// In en, this message translates to:
  /// **'Automatic separation did not complete. Current labels can still be viewed and edited.'**
  String get speakerDegradedEditable;

  /// No description provided for @editSpeakerLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit speaker label'**
  String get editSpeakerLabel;

  /// No description provided for @speakerManagement.
  ///
  /// In en, this message translates to:
  /// **'Speaker management'**
  String get speakerManagement;

  /// No description provided for @editSpeakerDescription.
  ///
  /// In en, this message translates to:
  /// **'Only the display label changes. Source audio, transcript content, and timeline remain unchanged.'**
  String get editSpeakerDescription;

  /// No description provided for @speakerManagementDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatic separation and label edits never change source audio or the transcript timeline.'**
  String get speakerManagementDescription;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @speakerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a speaker name'**
  String get speakerNameHint;

  /// No description provided for @speakerLabelSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The label was not saved. Check the name and try again.'**
  String get speakerLabelSaveFailed;

  /// No description provided for @automaticSpeakerSeparation.
  ///
  /// In en, this message translates to:
  /// **'Automatic speaker separation'**
  String get automaticSpeakerSeparation;

  /// No description provided for @automaticSpeakerSeparationDescription.
  ///
  /// In en, this message translates to:
  /// **'When off, automatic processing stops and existing labels remain unchanged.'**
  String get automaticSpeakerSeparationDescription;

  /// No description provided for @speakerUnavailableNoLabels.
  ///
  /// In en, this message translates to:
  /// **'The on-device speaker model is unavailable and there are no labels to manage.'**
  String get speakerUnavailableNoLabels;

  /// No description provided for @speakerUnavailableExistingLabels.
  ///
  /// In en, this message translates to:
  /// **'The on-device speaker model is unavailable. Existing labels can still be edited manually.'**
  String get speakerUnavailableExistingLabels;

  /// No description provided for @speakerSeparationProcessing.
  ///
  /// In en, this message translates to:
  /// **'Speaker separation in progress'**
  String get speakerSeparationProcessing;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @reprocess.
  ///
  /// In en, this message translates to:
  /// **'Reprocess'**
  String get reprocess;

  /// No description provided for @labels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get labels;

  /// No description provided for @noEditableSpeakerLabels.
  ///
  /// In en, this message translates to:
  /// **'No speaker labels are available to edit.'**
  String get noEditableSpeakerLabels;

  /// No description provided for @speakerLabelsSemantics.
  ///
  /// In en, this message translates to:
  /// **'Speaker labels'**
  String get speakerLabelsSemantics;

  /// No description provided for @startupStoppedForData.
  ///
  /// In en, this message translates to:
  /// **'Startup stopped to protect local data.'**
  String get startupStoppedForData;

  /// No description provided for @cannotReadLocalData.
  ///
  /// In en, this message translates to:
  /// **'Could not read local data'**
  String get cannotReadLocalData;

  /// No description provided for @cleanupNotRun.
  ///
  /// In en, this message translates to:
  /// **'Automatic cleanup did not run. Check device storage and try again.'**
  String get cleanupNotRun;

  /// No description provided for @localInitializationIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Local capabilities did not finish initializing.'**
  String get localInitializationIncomplete;

  /// No description provided for @localCapabilitiesNotReady.
  ///
  /// In en, this message translates to:
  /// **'Local capabilities are not ready'**
  String get localCapabilitiesNotReady;

  /// No description provided for @ensureStorageRetry.
  ///
  /// In en, this message translates to:
  /// **'Make sure the device has enough space and try again.'**
  String get ensureStorageRetry;

  /// No description provided for @preparingMeetTraceStage.
  ///
  /// In en, this message translates to:
  /// **'Preparing MeetTrace, {stage}'**
  String preparingMeetTraceStage(String stage);

  /// No description provided for @preparingMeetTrace.
  ///
  /// In en, this message translates to:
  /// **'Preparing MeetTrace'**
  String get preparingMeetTrace;

  /// No description provided for @stepOfFour.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 4'**
  String stepOfFour(int step);

  /// No description provided for @offlineResourcePreparationProgress.
  ///
  /// In en, this message translates to:
  /// **'Offline transcription resource preparation progress'**
  String get offlineResourcePreparationProgress;

  /// No description provided for @localEvidencePreserved.
  ///
  /// In en, this message translates to:
  /// **'Meeting records and source audio remain on this device'**
  String get localEvidencePreserved;

  /// No description provided for @agreeAndDownload.
  ///
  /// In en, this message translates to:
  /// **'Agree and download'**
  String get agreeAndDownload;

  /// No description provided for @avoidMobileNetwork.
  ///
  /// In en, this message translates to:
  /// **'Do not use mobile data'**
  String get avoidMobileNetwork;

  /// No description provided for @continueDownload.
  ///
  /// In en, this message translates to:
  /// **'Continue download'**
  String get continueDownload;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @openLocalWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open local workspace'**
  String get openLocalWorkspace;

  /// No description provided for @openLocalWorkspaceDescription.
  ///
  /// In en, this message translates to:
  /// **'Restoring meeting records and checking local data.'**
  String get openLocalWorkspaceDescription;

  /// No description provided for @checkOfflineResources.
  ///
  /// In en, this message translates to:
  /// **'Check offline resources'**
  String get checkOfflineResources;

  /// No description provided for @checkOfflineResourcesDescription.
  ///
  /// In en, this message translates to:
  /// **'Checking local files against the fixed resource manifest.'**
  String get checkOfflineResourcesDescription;

  /// No description provided for @awaitNetworkConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Await network confirmation'**
  String get awaitNetworkConfirmation;

  /// No description provided for @awaitNetworkConfirmationDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm the network to start downloading.'**
  String get awaitNetworkConfirmationDescription;

  /// No description provided for @freeDeviceSpace.
  ///
  /// In en, this message translates to:
  /// **'Free device space'**
  String get freeDeviceSpace;

  /// No description provided for @freeDeviceSpaceDescription.
  ///
  /// In en, this message translates to:
  /// **'Free enough space, then check again.'**
  String get freeDeviceSpaceDescription;

  /// No description provided for @downloadOfflineResources.
  ///
  /// In en, this message translates to:
  /// **'Download offline resources'**
  String get downloadOfflineResources;

  /// No description provided for @downloadOfflineResourcesDescription.
  ///
  /// In en, this message translates to:
  /// **'Downloads can be paused. Completed parts are preserved.'**
  String get downloadOfflineResourcesDescription;

  /// No description provided for @downloadPaused.
  ///
  /// In en, this message translates to:
  /// **'Download paused'**
  String get downloadPaused;

  /// No description provided for @downloadPausedDescription.
  ///
  /// In en, this message translates to:
  /// **'Continuing resumes from the current progress.'**
  String get downloadPausedDescription;

  /// No description provided for @verifyResourceIntegrity.
  ///
  /// In en, this message translates to:
  /// **'Verify resource integrity'**
  String get verifyResourceIntegrity;

  /// No description provided for @verifyResourceIntegrityDescription.
  ///
  /// In en, this message translates to:
  /// **'Checking file sizes and integrity.'**
  String get verifyResourceIntegrityDescription;

  /// No description provided for @enableOfflineTranscription.
  ///
  /// In en, this message translates to:
  /// **'Enable offline transcription'**
  String get enableOfflineTranscription;

  /// No description provided for @enableOfflineTranscriptionDescription.
  ///
  /// In en, this message translates to:
  /// **'Loading local inference capabilities.'**
  String get enableOfflineTranscriptionDescription;

  /// No description provided for @resourcePreparationIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Resource preparation incomplete'**
  String get resourcePreparationIncomplete;

  /// No description provided for @resourcePreparationIncompleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Review the message and try again.'**
  String get resourcePreparationIncompleteDescription;

  /// No description provided for @offlineTranscriptionReady.
  ///
  /// In en, this message translates to:
  /// **'Offline transcription ready'**
  String get offlineTranscriptionReady;

  /// No description provided for @offlineTranscriptionReadyDescription.
  ///
  /// In en, this message translates to:
  /// **'Entering MeetTrace.'**
  String get offlineTranscriptionReadyDescription;

  /// No description provided for @startupLocalCapabilitiesIncomplete.
  ///
  /// In en, this message translates to:
  /// **'MeetTrace local capability preparation incomplete'**
  String get startupLocalCapabilitiesIncomplete;

  /// No description provided for @startupNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Startup needs your attention'**
  String get startupNeedsAttention;

  /// No description provided for @updateClearsLocalData.
  ///
  /// In en, this message translates to:
  /// **'Update clears local data'**
  String get updateClearsLocalData;

  /// No description provided for @newVersionFound.
  ///
  /// In en, this message translates to:
  /// **'New MeetTrace version found'**
  String get newVersionFound;

  /// No description provided for @confirmUpdateDataRisk.
  ///
  /// In en, this message translates to:
  /// **'Confirm the local data risk before updating'**
  String get confirmUpdateDataRisk;

  /// No description provided for @newVersionPassedReleaseGate.
  ///
  /// In en, this message translates to:
  /// **'The new version passed the public release gate'**
  String get newVersionPassedReleaseGate;

  /// No description provided for @destructiveUpdateMessage.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (build {build}) raises the data generation. On first launch after installation, the app clears local meeting audio, transcripts, models, and settings, then initializes again. Share or export anything you need first.'**
  String destructiveUpdateMessage(String version, int build);

  /// No description provided for @updateReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (build {build}) is ready. Continuing hands off to the system installer, TestFlight, or Microsoft Store, which may still request confirmation.'**
  String updateReadyMessage(String version, int build);

  /// No description provided for @handleLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get handleLater;

  /// No description provided for @confirmRiskContinue.
  ///
  /// In en, this message translates to:
  /// **'Confirm risk and continue'**
  String get confirmRiskContinue;

  /// No description provided for @continueUpdate.
  ///
  /// In en, this message translates to:
  /// **'Continue update'**
  String get continueUpdate;

  /// No description provided for @updateHandedToSystem.
  ///
  /// In en, this message translates to:
  /// **'Handed off to system update'**
  String get updateHandedToSystem;

  /// No description provided for @updateDoesNotForceInterrupt.
  ///
  /// In en, this message translates to:
  /// **'Recording and local data are not forcibly interrupted in the app'**
  String get updateDoesNotForceInterrupt;

  /// No description provided for @updateDeferred.
  ///
  /// In en, this message translates to:
  /// **'Update deferred'**
  String get updateDeferred;

  /// No description provided for @updateDeferredDescription.
  ///
  /// In en, this message translates to:
  /// **'The app will prompt again after recording or final processing ends'**
  String get updateDeferredDescription;

  /// No description provided for @cannotOpenSystemUpdate.
  ///
  /// In en, this message translates to:
  /// **'Could not open system update'**
  String get cannotOpenSystemUpdate;

  /// No description provided for @checkSystemInstallAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Check system installation authorization and try again'**
  String get checkSystemInstallAuthorization;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'The operation did not complete. Try again.'**
  String get unexpectedError;

  /// No description provided for @finalTranscriptStatusLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load final transcript status. Try again.'**
  String get finalTranscriptStatusLoadFailed;

  /// No description provided for @audioShareSpaceShortage.
  ///
  /// In en, this message translates to:
  /// **'Insufficient available space. {shortage} more is required; no temporary file was kept.'**
  String audioShareSpaceShortage(String shortage);

  /// No description provided for @themeSaveFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'The previous theme was restored.'**
  String get themeSaveFailedMessage;

  /// No description provided for @senseVoiceNotReady.
  ///
  /// In en, this message translates to:
  /// **'SenseVoice is not installed or did not pass verification'**
  String get senseVoiceNotReady;

  /// No description provided for @scanningMicrophones.
  ///
  /// In en, this message translates to:
  /// **'Scanning microphones'**
  String get scanningMicrophones;

  /// No description provided for @noOtherMicrophonesFound.
  ///
  /// In en, this message translates to:
  /// **'No other microphones found'**
  String get noOtherMicrophonesFound;

  /// No description provided for @windowsInputDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'Found {count} Windows input devices'**
  String windowsInputDeviceCount(int count);

  /// No description provided for @cannotReadWindowsMicrophones.
  ///
  /// In en, this message translates to:
  /// **'Could not read Windows microphones. Check system microphone permission and try again.'**
  String get cannotReadWindowsMicrophones;

  /// No description provided for @microphoneScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Microphone scan failed'**
  String get microphoneScanFailed;

  /// No description provided for @microphonePreferenceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the microphone preference. Try again.'**
  String get microphonePreferenceSaveFailed;

  /// No description provided for @modelStatusReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read model status'**
  String get modelStatusReadFailed;

  /// No description provided for @modelSettingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load model settings'**
  String get modelSettingsLoadFailed;

  /// No description provided for @operationFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Operation failed. Try again.'**
  String get operationFailedRetry;

  /// No description provided for @storageUsageReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read storage usage'**
  String get storageUsageReadFailed;

  /// No description provided for @diagnosticsShareOpened.
  ///
  /// In en, this message translates to:
  /// **'The system share panel opened. Diagnostics do not include titles, transcripts, audio, or local paths.'**
  String get diagnosticsShareOpened;

  /// No description provided for @diagnosticsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export diagnostics. Try again.'**
  String get diagnosticsExportFailed;

  /// No description provided for @preparingLocalData.
  ///
  /// In en, this message translates to:
  /// **'Preparing local data'**
  String get preparingLocalData;

  /// No description provided for @mobileDataDeclined.
  ///
  /// In en, this message translates to:
  /// **'Mobile data is not being used. Connect to Wi-Fi and try again. Existing meeting data is unchanged.'**
  String get mobileDataDeclined;

  /// No description provided for @continuingDownload.
  ///
  /// In en, this message translates to:
  /// **'Continuing from the current download progress'**
  String get continuingDownload;

  /// No description provided for @checkingLocalTranscriptionResources.
  ///
  /// In en, this message translates to:
  /// **'Checking local transcription resources'**
  String get checkingLocalTranscriptionResources;

  /// No description provided for @offlineResourcesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare offline transcription resources. Try again.'**
  String get offlineResourcesFailed;

  /// No description provided for @retryFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Retry did not succeed: {message}'**
  String retryFailedPrefix(String message);

  /// No description provided for @runtimeInitializationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not initialize the offline speech runtime. Try again.'**
  String get runtimeInitializationFailed;

  /// No description provided for @runtimeResourcesOverLimit.
  ///
  /// In en, this message translates to:
  /// **'Fixed runtime resources exceed 300,000,000 bytes and require a PRD review'**
  String get runtimeResourcesOverLimit;

  /// No description provided for @checkingLocalRuntimeResources.
  ///
  /// In en, this message translates to:
  /// **'Checking local runtime resources'**
  String get checkingLocalRuntimeResources;

  /// No description provided for @initializationSpaceShortage.
  ///
  /// In en, this message translates to:
  /// **'Initialization requires at least 1 GiB of available space. {bytes} bytes are missing.'**
  String initializationSpaceShortage(String bytes);

  /// No description provided for @initializationNeedsNetwork.
  ///
  /// In en, this message translates to:
  /// **'The first initialization requires a network connection to download offline runtime resources'**
  String get initializationNeedsNetwork;

  /// No description provided for @mobileDownloadWarning.
  ///
  /// In en, this message translates to:
  /// **'Downloading about {megabytes} MB over mobile data may incur charges. The download can be paused and resumed.'**
  String mobileDownloadWarning(String megabytes);

  /// No description provided for @downloadPausedChunksPreserved.
  ///
  /// In en, this message translates to:
  /// **'Download paused. Completed chunks are preserved.'**
  String get downloadPausedChunksPreserved;

  /// No description provided for @modelDownloadHttpsOnly.
  ///
  /// In en, this message translates to:
  /// **'Model downloads require HTTPS.'**
  String get modelDownloadHttpsOnly;

  /// No description provided for @modelFileDownloadHttpError.
  ///
  /// In en, this message translates to:
  /// **'Model file download failed with HTTP {status}.'**
  String modelFileDownloadHttpError(String status);

  /// No description provided for @modelDownloadResumeRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server returned an incompatible resume range.'**
  String get modelDownloadResumeRangeInvalid;

  /// No description provided for @modelFileExceedsManifestSize.
  ///
  /// In en, this message translates to:
  /// **'The server returned a model file larger than the manifest size.'**
  String get modelFileExceedsManifestSize;

  /// No description provided for @modelFileDownloadTimeout.
  ///
  /// In en, this message translates to:
  /// **'The model file download timed out. Try again.'**
  String get modelFileDownloadTimeout;

  /// No description provided for @modelFileMissing.
  ///
  /// In en, this message translates to:
  /// **'A required model file is missing.'**
  String get modelFileMissing;

  /// No description provided for @modelFileSizeMismatch.
  ///
  /// In en, this message translates to:
  /// **'A model file should be {expected} bytes but is {actual} bytes.'**
  String modelFileSizeMismatch(String expected, String actual);

  /// No description provided for @modelFileShaMismatch.
  ///
  /// In en, this message translates to:
  /// **'A model file failed SHA-256 verification.'**
  String get modelFileShaMismatch;

  /// No description provided for @modelFileNotInManifest.
  ///
  /// In en, this message translates to:
  /// **'A model file is not listed in the manifest.'**
  String get modelFileNotInManifest;

  /// No description provided for @modelFileDownloadIncomplete.
  ///
  /// In en, this message translates to:
  /// **'{path} did not finish downloading.'**
  String modelFileDownloadIncomplete(String path);

  /// No description provided for @runtimeResourcePreparationError.
  ///
  /// In en, this message translates to:
  /// **'Runtime resource preparation failed: {detail}'**
  String runtimeResourcePreparationError(String detail);

  /// No description provided for @modelIntegrityFailed.
  ///
  /// In en, this message translates to:
  /// **'Model file verification failed. Retry to download and repair the files.'**
  String get modelIntegrityFailed;

  /// No description provided for @modelPathInvalid.
  ///
  /// In en, this message translates to:
  /// **'A model file path is invalid. Retry resource repair.'**
  String get modelPathInvalid;

  /// No description provided for @modelPreparationFailed.
  ///
  /// In en, this message translates to:
  /// **'Runtime resource preparation failed. Try again.'**
  String get modelPreparationFailed;

  /// No description provided for @modelDownloadFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Model download failed. Try again.'**
  String get modelDownloadFailedRetry;

  /// No description provided for @recordingCannotStart.
  ///
  /// In en, this message translates to:
  /// **'Recording could not start. Check microphone permission and available storage.'**
  String get recordingCannotStart;

  /// No description provided for @pauseRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not pause recording. Recording state did not change.'**
  String get pauseRecordingFailed;

  /// No description provided for @resumeRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resume recording. End the meeting to preserve existing audio.'**
  String get resumeRecordingFailed;

  /// No description provided for @audioSealFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not seal audio. Preserve app data and retry recovery.'**
  String get audioSealFailed;

  /// No description provided for @speakerLabelSaved.
  ///
  /// In en, this message translates to:
  /// **'Speaker label saved'**
  String get speakerLabelSaved;

  /// No description provided for @speakerLabelSaveRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not save the speaker label. Try again.'**
  String get speakerLabelSaveRetry;

  /// No description provided for @transcriptRevisionSaved.
  ///
  /// In en, this message translates to:
  /// **'Transcript revision saved as a new version'**
  String get transcriptRevisionSaved;

  /// No description provided for @transcriptRevisionSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the transcript revision. Check the content and try again.'**
  String get transcriptRevisionSaveFailed;

  /// No description provided for @speakerSeparationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Speaker separation completed'**
  String get speakerSeparationCompleted;

  /// No description provided for @speakerSeparationDegraded.
  ///
  /// In en, this message translates to:
  /// **'Speaker separation failed. The result uses one speaker and the final transcript is unaffected.'**
  String get speakerSeparationDegraded;

  /// No description provided for @finalTranscriptionFailedPreserved.
  ///
  /// In en, this message translates to:
  /// **'Final transcription failed. Source audio and the previous result are preserved.'**
  String get finalTranscriptionFailedPreserved;

  /// No description provided for @speakerSeparationFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Speaker separation failed. The final transcript remains available; try again later.'**
  String get speakerSeparationFailedRetry;

  /// No description provided for @sourceAudioPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play source audio'**
  String get sourceAudioPlaybackFailed;

  /// No description provided for @sharePanelOpenedNoAudio.
  ///
  /// In en, this message translates to:
  /// **'The system share panel opened. Original audio is not included.'**
  String get sharePanelOpenedNoAudio;

  /// No description provided for @shareFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Sharing failed. Try again.'**
  String get shareFailedRetry;

  /// No description provided for @cannotReadAudioOrSpace.
  ///
  /// In en, this message translates to:
  /// **'Could not read source audio or available space. Try again.'**
  String get cannotReadAudioOrSpace;

  /// No description provided for @audioShareCompletedCleaned.
  ///
  /// In en, this message translates to:
  /// **'Audio sharing completed and temporary files were removed'**
  String get audioShareCompletedCleaned;

  /// No description provided for @audioShareCancelledCleaned.
  ///
  /// In en, this message translates to:
  /// **'Audio sharing was canceled and temporary files were removed'**
  String get audioShareCancelledCleaned;

  /// No description provided for @audioShareOutcomeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The system share panel opened, but the platform did not return a result. Temporary files were removed.'**
  String get audioShareOutcomeUnavailable;

  /// No description provided for @audioShareFailedCleaned.
  ///
  /// In en, this message translates to:
  /// **'Audio sharing failed. Temporary files were removed. Try again.'**
  String get audioShareFailedCleaned;

  /// No description provided for @audioShareCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove temporary audio sharing files. Restart the app and try again.'**
  String get audioShareCleanupFailed;

  /// No description provided for @meetingDerivedDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'Meeting and local derived data deleted'**
  String get meetingDerivedDataDeleted;

  /// No description provided for @meetingDeleteIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Meeting deletion did not complete. Try again.'**
  String get meetingDeleteIncomplete;

  /// No description provided for @deleteFailedPreserved.
  ///
  /// In en, this message translates to:
  /// **'Deletion failed. Meeting data is preserved.'**
  String get deleteFailedPreserved;

  /// No description provided for @renameFailedOriginalPreserved.
  ///
  /// In en, this message translates to:
  /// **'Renaming failed. The original meeting title is preserved.'**
  String get renameFailedOriginalPreserved;

  /// No description provided for @cannotStartMeeting.
  ///
  /// In en, this message translates to:
  /// **'Could not start meeting'**
  String get cannotStartMeeting;

  /// No description provided for @defaultModelTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The default model is temporarily unavailable. Check it in Settings.'**
  String get defaultModelTemporarilyUnavailable;

  /// No description provided for @senseVoiceInitializationRepair.
  ///
  /// In en, this message translates to:
  /// **'SenseVoice initialization failed. Returning to resource repair.'**
  String get senseVoiceInitializationRepair;

  /// No description provided for @meetingStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the meeting. Check recording permission, storage, and the default model, then try again.'**
  String get meetingStartFailed;

  /// No description provided for @noMicrophoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'No microphone is available. Connect or enable an input device and try again.'**
  String get noMicrophoneAvailable;

  /// No description provided for @preferredMicrophoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The selected microphone is unavailable. Select another one in Settings.'**
  String get preferredMicrophoneUnavailable;

  /// No description provided for @microphoneCurrentlyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The microphone is unavailable. Check the input device and try again.'**
  String get microphoneCurrentlyUnavailable;

  /// No description provided for @microphonePermissionStartRequirement.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required. A meeting is created only after permission is granted.'**
  String get microphonePermissionStartRequirement;

  /// No description provided for @storageStartRequirement.
  ///
  /// In en, this message translates to:
  /// **'Insufficient storage. Keep at least 128 MB available and try again.'**
  String get storageStartRequirement;

  /// No description provided for @senseVoiceNeedsRepair.
  ///
  /// In en, this message translates to:
  /// **'SenseVoice is not ready. Return to initialization to verify and repair it.'**
  String get senseVoiceNeedsRepair;

  /// No description provided for @recordingStartMicrophoneRetry.
  ///
  /// In en, this message translates to:
  /// **'Recording could not start. Confirm that a microphone is available and try again.'**
  String get recordingStartMicrophoneRetry;

  /// No description provided for @microphonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Could not use the microphone. Grant microphone permission in system settings and try again.'**
  String get microphonePermissionDenied;

  /// No description provided for @recordingStorageInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient storage. Keep at least 128 MB available and try again.'**
  String get recordingStorageInsufficient;

  /// No description provided for @recordingInputUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No microphone is available. Connect or enable an input device and try again.'**
  String get recordingInputUnavailable;

  /// No description provided for @recordingAudioAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This meeting already has source audio. Recording stopped to avoid overwriting it.'**
  String get recordingAudioAlreadyExists;

  /// No description provided for @speakerDiarizationResource.
  ///
  /// In en, this message translates to:
  /// **'Speaker separation'**
  String get speakerDiarizationResource;

  /// No description provided for @audioShareSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'Share meeting recording: {title}'**
  String audioShareSystemTitle(String title);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
