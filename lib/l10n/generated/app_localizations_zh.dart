// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '会迹 MeetTrace';

  @override
  String get settingsTitle => '设置';

  @override
  String get backToMeetings => '返回会议列表';

  @override
  String get languageSectionTitle => '语言';

  @override
  String get languageSaveFailedTitle => '语言设置未保存';

  @override
  String get languageSaveFailedMessage => '已恢复原选择。';

  @override
  String get languageOptionsSemantics => '应用语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageSystemDescription => '中文系统区域使用简体中文，其他区域使用英文';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageSimplifiedChineseDescription => '始终使用简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishDescription => '始终使用英文';

  @override
  String get appearanceSectionTitle => '外观';

  @override
  String get themeSaveFailedTitle => '主题设置未保存';

  @override
  String get themeOptionsSemantics => '外观主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystemDescription => '自动匹配设备外观';

  @override
  String get themeLightDescription => '始终使用浅色外观';

  @override
  String get themeDarkDescription => '始终使用深色外观';

  @override
  String get modelSettingsIncomplete => '模型设置未完成';

  @override
  String get meetingDefaultsTitle => '会议默认';

  @override
  String get newMeetingTranscriptionModel => '新会议转录模型';

  @override
  String get reading => '正在读取';

  @override
  String get modelLockDescription => '只影响后续新会议；录音开始后模型锁定，不会自动切换。';

  @override
  String get recordingInputTitle => '录音输入';

  @override
  String get recordingInputDescription => '新会议开始时锁定这里的选择；会议中设备断开时仅回退一次系统默认麦克风。';

  @override
  String get microphoneSettingsIncomplete => '麦克风设置未完成';

  @override
  String get readingWindowsMicrophones => '正在读取 Windows 麦克风列表';

  @override
  String get windowsRecordingDevices => 'Windows 录音输入设备';

  @override
  String get systemDefaultMicrophone => '系统默认麦克风';

  @override
  String get systemDefaultMicrophoneDescription => '由 Windows 在每场会议开始时解析';

  @override
  String get microphoneUnavailable => '当前不可用，请连接设备或选择其他麦克风';

  @override
  String get windowsInputDevice => 'Windows 输入设备';

  @override
  String get noOtherMicrophones => '未发现其他麦克风，仍可使用系统默认麦克风。';

  @override
  String get rescanningWindowsMicrophones => '正在重新扫描 Windows 麦克风列表';

  @override
  String get rescanMicrophones => '重新扫描麦克风';

  @override
  String get offlineResourcesTitle => '离线转录资源';

  @override
  String get readingOfflineResources => '正在读取离线转录资源';

  @override
  String get noOfflineResources => '没有可用的离线转录资源。';

  @override
  String modelVersionAutoLanguage(String version, String itn) {
    return '版本 $version · 自动识别语言$itn';
  }

  @override
  String get itnEnabledSuffix => ' · ITN 已开启';

  @override
  String get downloadAndRepair => '下载并修复';

  @override
  String get pauseDownload => '暂停下载';

  @override
  String get continueOrRetry => '继续或重试';

  @override
  String get verifyAndUpdate => '校验并更新';

  @override
  String offlineResourceProgress(String status) {
    return '$status离线转录资源';
  }

  @override
  String offlineResourceStatus(String status) {
    return '$status，离线转录资源状态';
  }

  @override
  String get modelMaintenanceActions => '模型维护操作';

  @override
  String get verifyAndRepair => '校验并修复';

  @override
  String get verifyAndRepairDescription => '核对本地文件完整性，必要时重新下载';

  @override
  String get maintainOfflineResources => '维护离线转录资源';

  @override
  String get maintainResources => '维护资源';

  @override
  String get storagePrivacyTitle => '存储与隐私';

  @override
  String get readingLocalStorage => '正在读取本地存储用量';

  @override
  String get storageReadFailed => '存储用量读取失败';

  @override
  String get storageUnchangedRetry => '本地数据没有被修改，可以重新读取。';

  @override
  String get readAgain => '重新读取';

  @override
  String get storageAppTotal => '应用总计';

  @override
  String get storageMeetings => '会议数据';

  @override
  String get storageModels => '模型数据';

  @override
  String get storageDatabase => '数据库';

  @override
  String get storageDeviceAvailable => '设备可用';

  @override
  String get localStoragePrivacyDescription =>
      '会议录音、最终转录与运行资源只保存在本机；卸载应用可能永久删除这些数据。';

  @override
  String get remoteDiagnosticsTitle => '远程诊断';

  @override
  String get remoteDiagnosticsEnabled => '允许匿名错误与性能诊断';

  @override
  String get remoteDiagnosticsDescription =>
      '默认开启。关闭后停止新的错误、性能与指标采集；已缓存或上传的数据不能撤回，Windows 原生崩溃处理最迟在下次启动完全关闭。';

  @override
  String get remoteDiagnosticsSaveFailed => '设置未应用，已恢复本次显示；下次启动以本机保存值为准。';

  @override
  String get gotIt => '知道了';

  @override
  String get diagnosticsTitle => '诊断';

  @override
  String get diagnosticsShareSubject => '会迹诊断信息';

  @override
  String get viewShareDiagnostics => '查看并分享诊断信息';

  @override
  String get diagnosticsContents => '仅含状态、用量、模型版本和错误码';

  @override
  String get confirmShareDiagnostics => '确认分享诊断信息';

  @override
  String get shareDiagnosticsQuestion => '分享诊断信息？';

  @override
  String get diagnosticsPrivacy => '诊断信息不包含会议标题、最终转录、事实音频或本地路径。';

  @override
  String get cancel => '取消';

  @override
  String get viewAndShare => '查看并分享';

  @override
  String get modelStatusNotDownloaded => '未下载';

  @override
  String get modelStatusChecking => '检查中';

  @override
  String get modelStatusDownloading => '下载中';

  @override
  String get modelStatusPaused => '已暂停';

  @override
  String get modelStatusVerifying => '校验中';

  @override
  String get modelStatusInstalled => '已安装';

  @override
  String get modelStatusUpdateAvailable => '可更新';

  @override
  String get modelStatusDeleting => '删除中';

  @override
  String get modelStatusDownloadFailed => '下载失败';

  @override
  String get modelStatusInsufficientSpace => '空间不足';

  @override
  String get languageChineseShort => '中';

  @override
  String get languageCantoneseShort => '粤';

  @override
  String get languageEnglishShort => '英';

  @override
  String get languageJapaneseShort => '日';

  @override
  String get languageKoreanShort => '韩';

  @override
  String get modelLanguageSeparator => '·';

  @override
  String get semanticListSeparator => '，';

  @override
  String get semanticSentenceSeparator => '；';

  @override
  String get shareLabelSeparator => '：';

  @override
  String defaultMeetingTitle(String dateTime) {
    return '$dateTime 会议';
  }

  @override
  String get untitledMeeting => '未命名会议';

  @override
  String get meetingTimeLabel => '会议时间';

  @override
  String get finalTranscriptTitle => '最终转录';

  @override
  String get speakerOne => '说话人 1';

  @override
  String speakerNumber(int number) {
    return '说话人 $number';
  }

  @override
  String get shareExportFooter => '由会迹从本机最终转录导出；不包含原始音频。';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get tomorrow => '明天';

  @override
  String get meetingStatusPreparing => '准备中';

  @override
  String get meetingStatusRecording => '录音中';

  @override
  String get meetingStatusProcessing => '处理中';

  @override
  String get meetingStatusCompleted => '已完成';

  @override
  String get meetingStatusFailed => '失败';

  @override
  String get meetingStatusGeneratingFinal => '正在生成最终转录';

  @override
  String get meetingStatusProcessingFailed => '处理失败';

  @override
  String get meetingStatusFailedAudioHint => '失败 · 打开查看事实音频状态';

  @override
  String get viewRecordingConditions => '查看录音条件';

  @override
  String get recheckRecordingConditions => '重新检查录音条件';

  @override
  String get localRecording => '本地录音';

  @override
  String get usesDefaultModel => '使用默认模型';

  @override
  String get checkingRecordingConditions => '正在检查录音条件';

  @override
  String get microphoneStorageDefaultModel => '麦克风、存储与默认模型';

  @override
  String get recordingConditionsReady => '录音条件已就绪';

  @override
  String audioLocalModelAvailable(String model) {
    return '音频仅保存在本机 · $model可用';
  }

  @override
  String get defaultModel => '默认模型';

  @override
  String get microphonePermissionRequired => '需要麦克风权限';

  @override
  String get authorizeWhenStarting => '开始会议时授权';

  @override
  String get storageInsufficient => '存储空间不足';

  @override
  String get keepAtLeast128Mb => '至少保留 128 MB';

  @override
  String get defaultModelUnavailable => '默认模型不可用';

  @override
  String get currentModel => '当前模型';

  @override
  String modelNeedsAttention(String model) {
    return '$model需要处理';
  }

  @override
  String get cannotCheckRecordingConditions => '无法检查录音条件';

  @override
  String get tapToRecheck => '点按重新检查';

  @override
  String additionalIssues(String primary, int count) {
    return '$primary，另有 $count 项';
  }

  @override
  String get meetingsTitle => '会议';

  @override
  String meetingCount(int count) {
    return '共 $count 场';
  }

  @override
  String get preparingRecording => '正在准备录音';

  @override
  String get startMeeting => '开始会议';

  @override
  String get preparingRecordingEllipsis => '正在准备录音…';

  @override
  String get loadingMeetings => '正在加载会议';

  @override
  String get meetingLoadFailed => '会议加载失败';

  @override
  String get localDataPreservedRetry => '本地数据仍保留在设备上，请重试。';

  @override
  String get retryLoading => '重试加载';

  @override
  String get noMeetings => '还没有会议';

  @override
  String get noMeetingsDescription => '开始录音后，会议会安全地保存在这台设备上。';

  @override
  String get rename => '重命名';

  @override
  String get renameMeetingHint => '打开会议标题编辑面板';

  @override
  String get delete => '删除';

  @override
  String get deleteMeetingHint => '打开永久删除确认';

  @override
  String get openSettings => '打开设置';

  @override
  String get closeRecordingConditions => '关闭录音条件面板';

  @override
  String permanentlyDeleteMeetingSemantics(String title) {
    return '永久删除$title';
  }

  @override
  String permanentlyDeleteMeetingQuestion(String title) {
    return '永久删除「$title」？';
  }

  @override
  String get permanentlyDeleteMeetingMessage =>
      '将删除本场事实音频、转录、说话人标签及处理记录。此操作无法撤销。';

  @override
  String get permanentlyDelete => '永久删除';

  @override
  String get meetingLocalDataDeleted => '会议及本地数据已删除';

  @override
  String get deleteFailed => '删除失败';

  @override
  String get meetingCannotDeleteNow => '会议正在录音或处理中，暂时不能删除';

  @override
  String get closeRenameMeeting => '关闭重命名会议面板';

  @override
  String get meetingTitleUpdated => '会议标题已更新';

  @override
  String get brandSemantics => '会迹，MeetTrace';

  @override
  String get renameMeetingTitle => '重命名会议';

  @override
  String get meetingTitleRequired => '请输入会议标题';

  @override
  String get meetingTitleSingleLine => '会议标题只能使用单行文本';

  @override
  String meetingTitleMaxLength(int count) {
    return '会议标题最多 $count 个字符';
  }

  @override
  String get saving => '正在保存';

  @override
  String get save => '保存';

  @override
  String get meetingTitleLabel => '会议标题';

  @override
  String get meetingTitleHint => '输入会议标题';

  @override
  String get renameFailedPreserved => '重命名失败，原会议标题仍保留。请重试。';

  @override
  String get recordingConditionsTitle => '录音条件';

  @override
  String get recordingConditionsDescription => '开始会议前会再次检查；录音和转录资源只保存在本机。';

  @override
  String get recordingConditionsDetails => '录音条件详情';

  @override
  String get recordingConditionsStatus => '录音条件状态';

  @override
  String get microphonePermission => '麦克风权限';

  @override
  String get canRecordMeetingAudio => '应用可以录制会议音频';

  @override
  String get meetingNotCreatedBeforePermission => '授权前不会创建会议';

  @override
  String get authorized => '已授权';

  @override
  String get awaitingAuthorization => '待授权';

  @override
  String get localStorage => '本地存储';

  @override
  String get spaceAvailable => '空间充足';

  @override
  String get spaceInsufficient => '空间不足';

  @override
  String get offlineTranscription => '离线转录';

  @override
  String modelUsedForMeeting(String model) {
    return '$model用于会中与最终转录';
  }

  @override
  String get available => '可用';

  @override
  String get needsRepair => '需修复';

  @override
  String minimumStorageRequired(String minimum) {
    return '开始会议至少需要 $minimum';
  }

  @override
  String availableStorageMinimum(String available, String minimum) {
    return '可用 $available · 最低要求 $minimum';
  }

  @override
  String get authorizeMicrophone => '授权麦克风';

  @override
  String get recheck => '重新检查';

  @override
  String get repairOfflineResources => '修复离线资源';

  @override
  String get selectMeeting => '选择一场会议';

  @override
  String get selectMeetingDescription => '会议事实、录音状态和模型来源会显示在这里。';

  @override
  String get startTime => '开始时间';

  @override
  String get recordingDuration => '录音时长';

  @override
  String get sourceAudio => '事实音频';

  @override
  String get meetingModel => '本场模型';

  @override
  String get meetingFacts => '会议事实';

  @override
  String get liveTranscriptReferenceOnly => '实时转录仅供参考';

  @override
  String get sourceAudioLocalFirst => '事实音频本地优先';

  @override
  String get openFullRecord => '打开完整记录';

  @override
  String get openFullMeetingRecord => '打开完整会议记录';

  @override
  String get recordingContinues => '录音不中断';

  @override
  String get audioNotStarted => '录音尚未开始';

  @override
  String get audioWritingLocally => '正在本机持续写入';

  @override
  String get audioSavedLocally => '已保存在本机';

  @override
  String get audioSealing => '正在封存';

  @override
  String get meetingProcessingCompleted => '会议处理已完成';

  @override
  String get openMeetingForSaveStatus => '打开会议查看保存状态';

  @override
  String get factCreatedDescription => '录音尚未开始。本场模型会在开始后锁定。';

  @override
  String get factRecordingDescription => '事实音频正在本机持续写入。推理变慢或失败不会中断录音。';

  @override
  String get factProcessingDescription => '事实音频已经封存，当前正在使用本场锁定模型生成最终转录。';

  @override
  String get factFinalReadyDescription => '最终转录已经就绪。打开完整记录可查看带说话人标签和时间戳的转录。';

  @override
  String get factCompletedDescription => '会议处理已经完成。打开完整记录可查看当前可用结果。';

  @override
  String get factDerivedFailedDescription =>
      '派生处理失败，但事实音频仍保存在本机。打开完整记录可查看原因并重试。';

  @override
  String get factMeetingFailedDescription => '会议处理失败。打开完整记录可核对原因和事实音频状态。';

  @override
  String get localModel => '本地模型';

  @override
  String get deleting => '正在删除';

  @override
  String get renaming => '正在重命名';

  @override
  String openMeetingSemantics(String title, String dateTime, String status) {
    return '打开会议：$title，$dateTime，$status';
  }

  @override
  String get deletingLocalMeetingData => '正在删除本机会议数据';

  @override
  String get savingMeetingTitle => '正在保存新会议标题';

  @override
  String get viewFailureAndAudio => '查看失败原因和事实音频状态';

  @override
  String get viewMeetingDetails => '查看会议详情';

  @override
  String get swipeRenameDelete => '向左滑动显示重命名和删除操作';

  @override
  String get swipeRename => '向左滑动显示重命名操作';

  @override
  String get renameMeetingAction => '重命名会议';

  @override
  String get deleteMeetingAction => '删除会议';

  @override
  String get endMeetingAndReturn => '结束会议并返回';

  @override
  String get endSaveMeetingSemantics => '结束并保存会议';

  @override
  String get endSaveMeetingQuestion => '结束并保存会议？';

  @override
  String get endSaveMeetingMessage => '结束后会先封存本机事实音频，再进入最终转录。当前实时转录仅供预览。';

  @override
  String get continueRecording => '继续录音';

  @override
  String get endAndSave => '结束并保存';

  @override
  String get startingRecording => '正在启动录音';

  @override
  String get liveTranscript => '实时转录';

  @override
  String segmentCount(int count) {
    return '$count 段';
  }

  @override
  String get liveTranscriptReferenceFooter => '仅供参考，结束后生成最终转录。';

  @override
  String get finalFromFullAudio => '结束后仍会基于完整音频生成最终转录。';

  @override
  String get speechAppearsHere => '检测到语音后在这里显示文字。';

  @override
  String get previewPausedWithRecording => '已随录音暂停';

  @override
  String get previewNormal => '正常';

  @override
  String get previewBacklogged => '积压，录音仍在继续';

  @override
  String get previewStoppedRecordingContinues => '已停止，录音仍在继续';

  @override
  String get previewEnded => '已结束';

  @override
  String get meetingLockedModelFallback => '本场模型';

  @override
  String get recordingErrorGuidance => '请保留应用数据，并按当前可用操作继续。事实音频状态以上方提示为准。';

  @override
  String meetingModelLocked(String model) {
    return '$model · 本场锁定';
  }

  @override
  String get recordingStatePreparing => '准备录音';

  @override
  String get recordingStateRecovering => '正在恢复';

  @override
  String get recordingStateInterrupted => '录音已中断';

  @override
  String get recordingStatePaused => '已暂停';

  @override
  String get recordingStateSaving => '正在保存';

  @override
  String get recordingStateSaved => '已保存';

  @override
  String get recordingStateError => '录音异常';

  @override
  String get recordingFactStarting => '正在启动事实录音';

  @override
  String get recordingFactWriting => '事实音频正在安全写入';

  @override
  String get recordingFactRecovering => '输入中断，正在切换系统默认麦克风';

  @override
  String get recordingFactInterrupted => '事实录音已中断，可结束会议以保存已有音频';

  @override
  String get recordingFactPaused => '事实录音已暂停';

  @override
  String get recordingFactSealing => '正在封存事实音频';

  @override
  String get recordingFactSaved => '事实音频已保存';

  @override
  String get recordingFactError => '事实录音发生错误';

  @override
  String get resume => '继续';

  @override
  String get pause => '暂停';

  @override
  String get sealingAudio => '正在封存音频';

  @override
  String get endMeeting => '结束会议';

  @override
  String get waveformWaitingSemantics => '麦克风输入波形，等待录音';

  @override
  String get waveformWaitingLabel => '麦克风输入 · 等待录音';

  @override
  String get waveformLiveSemantics => '麦克风输入波形，实时反馈';

  @override
  String get waveformLiveLabel => '麦克风输入 · 实时反馈';

  @override
  String get waveformPausedSemantics => '麦克风输入波形，录音已暂停';

  @override
  String get waveformPausedLabel => '麦克风输入 · 已暂停';

  @override
  String get waveformStoppedSemantics => '麦克风输入波形，录音已停止';

  @override
  String get waveformStoppedLabel => '麦克风输入 · 已停止';

  @override
  String get meetingDetailsTitle => '会议详情';

  @override
  String get loadingMeetingResult => '加载会议结果';

  @override
  String get noFinalTranscript => '暂无最终转录';

  @override
  String get sourceAudioReturnLater => '事实录音仍保存在本机，可稍后返回继续处理。';

  @override
  String get lastProcessingIncomplete => '最近一次处理未完成';

  @override
  String get operationStatus => '操作状态';

  @override
  String get factRecord => '事实记录';

  @override
  String get sourceAudioSaved => '事实音频已保存';

  @override
  String get sourceAudioTimestampVerification => '最终转录带有时间戳，可回到本机原音频核对。';

  @override
  String get finalTranscriptIncomplete => '最终转录未完成';

  @override
  String get retryFinalTranscript => '重试最终转录';

  @override
  String get finalShowsSpeakers => '完成后将一次显示最终转录和说话人标签。';

  @override
  String get speakerSeparationUnavailableOutcome => '说话人区分当前不可用；完成后将按单一说话人显示。';

  @override
  String get generatingFinalResult => '正在生成最终结果';

  @override
  String processingSemanticsLabel(String model, String outcome) {
    return '正在生成最终结果。$model 正在处理完整录音。$outcome事实录音已保存在本机，处理不会改写原始音频。';
  }

  @override
  String modelProcessingFullRecording(String model) {
    return '$model 正在处理完整录音。';
  }

  @override
  String get sourceAudioNotRewritten => '事实录音已保存在本机，处理不会改写原始音频。';

  @override
  String get stopPlayback => '停止播放';

  @override
  String get playRecording => '播放录音';

  @override
  String get localSourceRecording => '本地事实录音';

  @override
  String recordingLocalDuration(String duration) {
    return '录音仅保存在本机 · $duration';
  }

  @override
  String get saveRevision => '保存修订';

  @override
  String get shareMeeting => '分享会议';

  @override
  String get closeShareMeeting => '关闭分享会议面板';

  @override
  String get shareMeetingDescription => '文本只包含最终转录；事实音频需要单独确认。';

  @override
  String get meetingShareMethods => '会议分享方式';

  @override
  String get plainText => '纯文本';

  @override
  String get plainTextDescription => '适合消息和邮件正文';

  @override
  String get markdownDescription => '保留标题、时间戳和结构';

  @override
  String get shareAudioSeparately => '单独分享音频';

  @override
  String get shareAudioSeparatelyDescription => '生成临时 WAV，并再次确认隐私风险';

  @override
  String get audioShareInsufficientSpace => '音频分享空间不足';

  @override
  String get audioFileNameFallback => '会议录音';

  @override
  String get availableSpaceInsufficient => '可用空间不足';

  @override
  String temporaryWavShortage(String shortage) {
    return '生成临时 WAV 还缺少 $shortage，未创建任何文件。';
  }

  @override
  String get confirmShareMeetingAudio => '确认分享会议音频';

  @override
  String get confirmShareAudioQuestion => '确认单独分享音频？';

  @override
  String audioShareConfirmation(String title, String duration, String size) {
    return '会议：$title\n时长：$duration\n文件：$size WAV\n\n录音可能包含敏感或私密信息。确认后才会生成临时副本并打开系统分享面板；不会附带转录文本。';
  }

  @override
  String get generateAndShare => '生成并分享';

  @override
  String get moreMeetingActions => '更多会议操作';

  @override
  String get closeMoreMeetingActions => '关闭更多会议操作';

  @override
  String get moreActions => '更多操作';

  @override
  String get moreActionsDescription => '低频操作集中在这里；删除会议后无法恢复。';

  @override
  String get regenerateTranscript => '重新生成转录';

  @override
  String useLockedModel(String model) {
    return '继续使用本场锁定的 $model';
  }

  @override
  String get deleteMeeting => '删除会议';

  @override
  String get deleteMeetingAllDerived => '同时删除事实录音和全部派生结果';

  @override
  String get confirmPermanentDeleteMeeting => '确认永久删除会议';

  @override
  String get permanentlyDeleteThisMeeting => '永久删除这场会议？';

  @override
  String get deleteThisMeetingMessage => '将删除本场事实录音、转录、说话人标签和处理记录，无法撤销。';

  @override
  String get deleteAllData => '删除全部数据';

  @override
  String get edit => '编辑';

  @override
  String get transcriptRevisionDescription => '保存后会生成新的最终转录版本，事实音频和时间轴保持不变。';

  @override
  String get noRecognizedSpeech => '未识别到可显示的语音内容。';

  @override
  String get speaker => '说话人';

  @override
  String get transcriptContent => '转录内容';

  @override
  String get speakersTitle => '说话人';

  @override
  String get noSpeakerSegments => '暂无说话人片段';

  @override
  String speakerSegmentCount(int speakers, int segments) {
    return '$speakers 位说话人 · $segments 个片段';
  }

  @override
  String get manage => '管理';

  @override
  String get closeSpeakerManagement => '关闭说话人管理面板';

  @override
  String get speakerReprocessing => '正在重新区分说话人，最终转录仍可查看。';

  @override
  String get speakerModelUnavailable => '本机说话人模型不可用。';

  @override
  String get speakerModelUnavailableManual => '本机说话人模型不可用，可手工修改标签。';

  @override
  String get speakerAutoDisabled => '自动区分已关闭，现有标签保持不变。';

  @override
  String get speakerDegradedSingle => '自动区分未完成，当前按单一说话人显示。';

  @override
  String get speakerDegradedEditable => '自动区分未完成，当前标签仍可查看和修改。';

  @override
  String get editSpeakerLabel => '修改说话人标签';

  @override
  String get speakerManagement => '说话人管理';

  @override
  String get editSpeakerDescription => '只修改显示标签，不会改变事实音频、转录内容或时间轴。';

  @override
  String get speakerManagementDescription => '自动区分和标签修改不会改变事实音频或转录时间轴。';

  @override
  String get displayName => '显示名称';

  @override
  String get speakerNameHint => '输入说话人名称';

  @override
  String get speakerLabelSaveFailed => '标签保存未完成，请检查名称后重试。';

  @override
  String get automaticSpeakerSeparation => '自动区分说话人';

  @override
  String get automaticSpeakerSeparationDescription => '关闭后不再自动处理；现有标签保持不变。';

  @override
  String get speakerUnavailableNoLabels => '本机说话人模型不可用，暂无可管理的标签。';

  @override
  String get speakerUnavailableExistingLabels => '本机说话人模型不可用，仍可手工修改现有标签。';

  @override
  String get speakerSeparationProcessing => '说话人分离处理中';

  @override
  String get status => '状态';

  @override
  String get reprocess => '重新处理';

  @override
  String get labels => '标签';

  @override
  String get noEditableSpeakerLabels => '暂无可修改的说话人标签。';

  @override
  String get speakerLabelsSemantics => '说话人标签';

  @override
  String get startupStoppedForData => '为保护本地数据，启动已停止。';

  @override
  String get cannotReadLocalData => '无法读取本地数据';

  @override
  String get cleanupNotRun => '自动清理未执行。请检查设备存储状态后重试。';

  @override
  String get localInitializationIncomplete => '本地能力未完成初始化。';

  @override
  String get localCapabilitiesNotReady => '本地能力准备未完成';

  @override
  String get ensureStorageRetry => '请确认设备空间充足后重试。';

  @override
  String preparingMeetTraceStage(String stage) {
    return '正在准备会迹，$stage';
  }

  @override
  String get preparingMeetTrace => '正在准备会迹';

  @override
  String stepOfFour(int step) {
    return '步骤 $step / 4';
  }

  @override
  String get offlineResourcePreparationProgress => '离线转录资源准备进度';

  @override
  String get localEvidencePreserved => '会议记录与事实音频仍保存在本机';

  @override
  String get agreeAndDownload => '同意并下载';

  @override
  String get avoidMobileNetwork => '暂不使用移动网络';

  @override
  String get continueDownload => '继续下载';

  @override
  String get retry => '重试';

  @override
  String get openLocalWorkspace => '打开本地工作区';

  @override
  String get openLocalWorkspaceDescription => '正在恢复会议记录并确认本地数据可用。';

  @override
  String get checkOfflineResources => '检查离线资源';

  @override
  String get checkOfflineResourcesDescription => '正在核对本地文件与固定资源清单。';

  @override
  String get awaitNetworkConfirmation => '等待网络确认';

  @override
  String get awaitNetworkConfirmationDescription => '确认网络后即可开始下载。';

  @override
  String get freeDeviceSpace => '需要释放设备空间';

  @override
  String get freeDeviceSpaceDescription => '释放足够空间后可以重新检查。';

  @override
  String get downloadOfflineResources => '下载离线资源';

  @override
  String get downloadOfflineResourcesDescription => '下载可暂停，已完成的部分会保留。';

  @override
  String get downloadPaused => '下载已暂停';

  @override
  String get downloadPausedDescription => '继续后将从当前进度恢复。';

  @override
  String get verifyResourceIntegrity => '校验资源完整性';

  @override
  String get verifyResourceIntegrityDescription => '正在确认文件大小与完整性。';

  @override
  String get enableOfflineTranscription => '启用离线转录';

  @override
  String get enableOfflineTranscriptionDescription => '正在加载本地推理能力。';

  @override
  String get resourcePreparationIncomplete => '资源准备未完成';

  @override
  String get resourcePreparationIncompleteDescription => '请检查提示后重试。';

  @override
  String get offlineTranscriptionReady => '离线转录已就绪';

  @override
  String get offlineTranscriptionReadyDescription => '正在进入会迹。';

  @override
  String get startupLocalCapabilitiesIncomplete => '会迹本地能力准备未完成';

  @override
  String get startupNeedsAttention => '启动需要你的处理';

  @override
  String get updateClearsLocalData => '更新会清除本地数据';

  @override
  String get newVersionFound => '发现会迹新版本';

  @override
  String get confirmUpdateDataRisk => '更新前必须确认本地数据风险';

  @override
  String get newVersionPassedReleaseGate => '新版本已通过公开发布门禁';

  @override
  String destructiveUpdateMessage(String version, int build) {
    return '版本 $version（构建 $build）提高了数据代。安装后首次启动会清除本机会议音频、转录、模型和设置，并重新初始化。请先分享或导出需要保留的内容。';
  }

  @override
  String updateReadyMessage(String version, int build) {
    return '版本 $version（构建 $build）已准备好。继续后将交给系统安装器、TestFlight 或 Microsoft Store，系统仍可能要求你的确认。';
  }

  @override
  String get handleLater => '稍后处理';

  @override
  String get confirmRiskContinue => '确认风险并继续';

  @override
  String get continueUpdate => '继续更新';

  @override
  String get updateHandedToSystem => '已交给系统更新';

  @override
  String get updateDoesNotForceInterrupt => '录音和本地数据不会在应用内被强制中断';

  @override
  String get updateDeferred => '更新已延后';

  @override
  String get updateDeferredDescription => '会议录音或最终处理结束后再提示';

  @override
  String get cannotOpenSystemUpdate => '暂时无法打开系统更新';

  @override
  String get checkSystemInstallAuthorization => '请检查系统安装授权后重试';

  @override
  String get unexpectedError => '操作未完成，请重试。';

  @override
  String get finalTranscriptStatusLoadFailed => '最终转录状态加载失败，请重试';

  @override
  String audioShareSpaceShortage(String shortage) {
    return '可用空间不足，还缺少 $shortage；未保留临时文件';
  }

  @override
  String get themeSaveFailedMessage => '主题设置保存失败，已恢复原选择';

  @override
  String get senseVoiceNotReady => 'SenseVoice 尚未安装或校验未通过';

  @override
  String get scanningMicrophones => '正在扫描麦克风';

  @override
  String get noOtherMicrophonesFound => '未发现其他麦克风';

  @override
  String windowsInputDeviceCount(int count) {
    return '已发现 $count 个 Windows 输入设备';
  }

  @override
  String get cannotReadWindowsMicrophones => '无法读取 Windows 麦克风列表，请检查系统麦克风权限后重试';

  @override
  String get microphoneScanFailed => '麦克风扫描失败';

  @override
  String get microphonePreferenceSaveFailed => '麦克风偏好保存失败，请重试';

  @override
  String get modelStatusReadFailed => '模型状态读取失败';

  @override
  String get modelSettingsLoadFailed => '模型设置加载失败';

  @override
  String get operationFailedRetry => '操作失败，请重试';

  @override
  String get storageUsageReadFailed => '存储用量读取失败';

  @override
  String get diagnosticsShareOpened => '已打开系统分享面板；诊断信息不含标题、转录、音频或本地路径';

  @override
  String get diagnosticsExportFailed => '诊断信息导出失败，请重试';

  @override
  String get preparingLocalData => '正在准备本地数据';

  @override
  String get mobileDataDeclined => '已暂不使用移动网络。连接 Wi-Fi 后可重试，现有会议数据不会改变。';

  @override
  String get continuingDownload => '正在从当前进度继续下载';

  @override
  String get checkingLocalTranscriptionResources => '正在检查本地转录资源';

  @override
  String get offlineResourcesFailed => '离线转录资源准备失败，请重试';

  @override
  String retryFailedPrefix(String message) {
    return '重试未成功：$message';
  }

  @override
  String get runtimeInitializationFailed => '离线语音运行时初始化失败，请重试';

  @override
  String get runtimeResourcesOverLimit => '固定运行资源超过 300,000,000 字节，必须重新评审 PRD';

  @override
  String get checkingLocalRuntimeResources => '正在检查本地运行资源';

  @override
  String initializationSpaceShortage(String bytes) {
    return '初始化至少需要 1 GiB 可用空间，还缺少 $bytes 字节';
  }

  @override
  String get initializationNeedsNetwork => '首次初始化需要联网下载离线运行资源';

  @override
  String mobileDownloadWarning(String megabytes) {
    return '将使用移动网络下载约 $megabytes MB，可能产生流量费用；下载可暂停并续传。';
  }

  @override
  String get downloadPausedChunksPreserved => '下载已暂停，已完成的分片会保留';

  @override
  String get modelDownloadHttpsOnly => '模型下载只允许 HTTPS';

  @override
  String modelFileDownloadHttpError(String status) {
    return '模型文件下载失败：HTTP $status';
  }

  @override
  String get modelDownloadResumeRangeInvalid => '服务器返回了不兼容的续传范围';

  @override
  String get modelFileExceedsManifestSize => '服务器返回的模型文件超过 Manifest 大小';

  @override
  String get modelFileDownloadTimeout => '模型文件下载超时，请重试';

  @override
  String get modelFileMissing => '缺少模型文件';

  @override
  String modelFileSizeMismatch(String expected, String actual) {
    return '文件大小应为 $expected，实际为 $actual';
  }

  @override
  String get modelFileShaMismatch => 'SHA-256 不匹配';

  @override
  String get modelFileNotInManifest => '文件不在 Manifest 中';

  @override
  String modelFileDownloadIncomplete(String path) {
    return '$path 下载不完整';
  }

  @override
  String runtimeResourcePreparationError(String detail) {
    return '运行资源准备失败：$detail';
  }

  @override
  String get modelIntegrityFailed => '模型文件完整性校验失败，请重试下载并修复';

  @override
  String get modelPathInvalid => '模型文件路径无效，请重试资源修复';

  @override
  String get modelPreparationFailed => '运行资源准备失败，请重试';

  @override
  String get modelDownloadFailedRetry => '模型下载失败，请重试';

  @override
  String get recordingCannotStart => '录音无法启动，请检查麦克风权限和可用空间';

  @override
  String get pauseRecordingFailed => '暂停录音失败，录音状态未改变';

  @override
  String get resumeRecordingFailed => '恢复录音失败，请结束会议以保留已有音频';

  @override
  String get audioSealFailed => '音频封存失败，请保留应用数据并重试恢复';

  @override
  String get speakerLabelSaved => '说话人标签已保存';

  @override
  String get speakerLabelSaveRetry => '说话人标签保存失败，请重试';

  @override
  String get transcriptRevisionSaved => '转录修订已保存为新版本';

  @override
  String get transcriptRevisionSaveFailed => '转录修订保存失败，请检查内容后重试';

  @override
  String get speakerSeparationCompleted => '说话人分离已完成';

  @override
  String get speakerSeparationDegraded => '说话人分离失败，已按单一说话人显示；最终转录不受影响';

  @override
  String get finalTranscriptionFailedPreserved => '最终转录失败，事实音频和旧结果均已保留';

  @override
  String get speakerSeparationFailedRetry => '说话人分离失败，最终转录仍可查看；可稍后重试';

  @override
  String get sourceAudioPlaybackFailed => '事实音频播放失败';

  @override
  String get sharePanelOpenedNoAudio => '已打开系统分享面板，内容不包含原始音频';

  @override
  String get shareFailedRetry => '分享失败，请重试';

  @override
  String get cannotReadAudioOrSpace => '无法读取事实音频或可用空间，请重试';

  @override
  String get audioShareCompletedCleaned => '音频分享操作已完成，临时文件已清理';

  @override
  String get audioShareCancelledCleaned => '已取消音频分享，临时文件已清理';

  @override
  String get audioShareOutcomeUnavailable => '已打开系统分享面板，平台未返回操作结果；临时文件已清理';

  @override
  String get audioShareFailedCleaned => '音频分享失败，临时文件已清理，请重试';

  @override
  String get audioShareCleanupFailed => '音频分享临时文件清理失败，请重启应用后重试';

  @override
  String get meetingDerivedDataDeleted => '会议及其本地派生数据已删除';

  @override
  String get meetingDeleteIncomplete => '会议删除未完成，请重试';

  @override
  String get deleteFailedPreserved => '删除失败，会议数据仍保留';

  @override
  String get renameFailedOriginalPreserved => '重命名失败，原会议标题仍保留';

  @override
  String get cannotStartMeeting => '无法开始会议';

  @override
  String get defaultModelTemporarilyUnavailable => '默认模型暂时不可用，请前往设置检查';

  @override
  String get senseVoiceInitializationRepair => 'SenseVoice 初始化失败，正在返回资源修复流程';

  @override
  String get meetingStartFailed => '会议启动失败，请检查录音权限、存储空间和默认模型后重试';

  @override
  String get noMicrophoneAvailable => '未检测到可用麦克风，请连接或启用输入设备后重试。';

  @override
  String get preferredMicrophoneUnavailable => '所选麦克风当前不可用，请在设置中重新选择。';

  @override
  String get microphoneCurrentlyUnavailable => '麦克风当前不可用，请检查输入设备后重试。';

  @override
  String get microphonePermissionStartRequirement =>
      '需要麦克风权限。授权后才能开始会议，未授权时不会创建会议。';

  @override
  String get storageStartRequirement => '存储空间不足。请至少保留 128 MB 可用空间后重试。';

  @override
  String get senseVoiceNeedsRepair => 'SenseVoice 尚未准备完成，请返回初始化流程校验并修复';

  @override
  String get recordingStartMicrophoneRetry => '录音无法启动，请确认麦克风可用后重试';

  @override
  String get microphonePermissionDenied => '无法使用麦克风，请在系统设置中授予麦克风权限后重试';

  @override
  String get recordingStorageInsufficient => '存储空间不足，请至少保留 128 MB 可用空间后重试';

  @override
  String get recordingInputUnavailable => '未检测到可用麦克风，请连接或启用输入设备后重试';

  @override
  String get recordingAudioAlreadyExists => '该会议已有事实音频，为避免覆盖已停止录音';

  @override
  String get speakerDiarizationResource => '说话人分离';

  @override
  String audioShareSystemTitle(String title) {
    return '分享会议录音：$title';
  }
}
