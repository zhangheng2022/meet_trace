import 'l10n.dart';

extension UiMessageLocalizations on AppLocalizations {
  String localizeRuntimeResourceName(String? name) => switch (name) {
    'speaker.diarization' => speakerDiarizationResource,
    null => 'SenseVoice + Silero VAD',
    _ => name,
  };

  String localizeRuntimeMessage(String? code, String message) {
    final retry = RegExp(r'^重试未成功：(.*)$').firstMatch(message);
    if (retry != null) {
      return retryFailedPrefix(localizeRuntimeMessage(code, retry.group(1)!));
    }
    if (code?.startsWith('model.download.http.') ?? false) {
      return modelFileDownloadHttpError(code!.split('.').last);
    }
    return switch (code) {
      'model.download.url' => modelDownloadHttpsOnly,
      'model.download.range' => modelDownloadResumeRangeInvalid,
      'model.download.size' => modelFileExceedsManifestSize,
      'model.download.timeout' => modelFileDownloadTimeout,
      'model.integrity' ||
      'vad.integrity' ||
      'speaker.integrity' => modelIntegrityFailed,
      'model.path.invalid' ||
      'vad.path.invalid' ||
      'speaker.path.invalid' => modelPathInvalid,
      'model.prepare.failed' ||
      'vad.prepare.failed' ||
      'speaker.archive.invalid' => modelPreparationFailed,
      'model.download.failed' ||
      'vad.download.incomplete' ||
      'speaker.download.incomplete' => modelDownloadFailedRetry,
      _ => localizeUiMessage(message),
    };
  }

  String localizeUiMessage(String message) {
    final retry = RegExp(r'^重试未成功：(.*)$').firstMatch(message);
    if (retry != null) {
      return retryFailedPrefix(localizeUiMessage(retry.group(1)!));
    }
    final direct = switch (message) {
      '主题设置保存失败，已恢复原选择' => themeSaveFailedMessage,
      'SenseVoice 尚未安装或校验未通过' => senseVoiceNotReady,
      '正在扫描麦克风' => scanningMicrophones,
      '未发现其他麦克风' => noOtherMicrophonesFound,
      '无法读取 Windows 麦克风列表，请检查系统麦克风权限后重试' => cannotReadWindowsMicrophones,
      '麦克风扫描失败' => microphoneScanFailed,
      '麦克风偏好保存失败，请重试' => microphonePreferenceSaveFailed,
      '模型状态读取失败' => modelStatusReadFailed,
      '模型设置加载失败' => modelSettingsLoadFailed,
      '操作失败，请重试' => operationFailedRetry,
      '存储用量读取失败' => storageUsageReadFailed,
      '已打开系统分享面板；诊断信息不含标题、转录、音频或本地路径' => diagnosticsShareOpened,
      '诊断信息导出失败，请重试' => diagnosticsExportFailed,
      '正在准备本地数据' => preparingLocalData,
      '已暂不使用移动网络。连接 Wi-Fi 后可重试，现有会议数据不会改变。' => mobileDataDeclined,
      '正在从当前进度继续下载' => continuingDownload,
      '正在检查本地转录资源' => checkingLocalTranscriptionResources,
      '离线转录资源准备失败，请重试' => offlineResourcesFailed,
      '离线语音运行时初始化失败，请重试' => runtimeInitializationFailed,
      '固定运行资源超过 300,000,000 字节，必须重新评审 PRD' => runtimeResourcesOverLimit,
      '正在检查本地运行资源' => checkingLocalRuntimeResources,
      '首次初始化需要联网下载离线运行资源' => initializationNeedsNetwork,
      '下载已暂停，已完成的分片会保留' => downloadPausedChunksPreserved,
      '模型下载只允许 HTTPS' => modelDownloadHttpsOnly,
      '服务器返回了不兼容的续传范围' => modelDownloadResumeRangeInvalid,
      '服务器返回的模型文件超过 Manifest 大小' => modelFileExceedsManifestSize,
      '模型文件下载超时，请重试' => modelFileDownloadTimeout,
      '缺少模型文件' => modelFileMissing,
      'SHA-256 不匹配' => modelFileShaMismatch,
      '文件不在 Manifest 中' => modelFileNotInManifest,
      '录音无法启动，请检查麦克风权限和可用空间' => recordingCannotStart,
      '暂停录音失败，录音状态未改变' => pauseRecordingFailed,
      '恢复录音失败，请结束会议以保留已有音频' => resumeRecordingFailed,
      '音频封存失败，请保留应用数据并重试恢复' => audioSealFailed,
      '说话人标签已保存' => speakerLabelSaved,
      '说话人标签保存失败，请重试' => speakerLabelSaveRetry,
      '转录修订已保存为新版本' => transcriptRevisionSaved,
      '转录修订保存失败，请检查内容后重试' => transcriptRevisionSaveFailed,
      '说话人分离已完成' => speakerSeparationCompleted,
      '说话人分离失败，已按单一说话人显示；最终转录不受影响' => speakerSeparationDegraded,
      '最终转录失败，事实音频和旧结果均已保留' => finalTranscriptionFailedPreserved,
      '最终转录状态加载失败，请重试' => finalTranscriptStatusLoadFailed,
      '说话人分离失败，最终转录仍可查看；可稍后重试' => speakerSeparationFailedRetry,
      '事实音频播放失败' => sourceAudioPlaybackFailed,
      '已打开系统分享面板，内容不包含原始音频' => sharePanelOpenedNoAudio,
      '分享失败，请重试' => shareFailedRetry,
      '无法读取事实音频或可用空间，请重试' => cannotReadAudioOrSpace,
      '音频分享操作已完成，临时文件已清理' => audioShareCompletedCleaned,
      '已取消音频分享，临时文件已清理' => audioShareCancelledCleaned,
      '已打开系统分享面板，平台未返回操作结果；临时文件已清理' => audioShareOutcomeUnavailable,
      '音频分享失败，临时文件已清理，请重试' => audioShareFailedCleaned,
      '音频分享临时文件清理失败，请重启应用后重试' => audioShareCleanupFailed,
      '会议及其本地派生数据已删除' => meetingDerivedDataDeleted,
      '会议删除未完成，请重试' => meetingDeleteIncomplete,
      '删除失败，会议数据仍保留' => deleteFailedPreserved,
      '重命名失败，原会议标题仍保留' => renameFailedOriginalPreserved,
      'SenseVoice 初始化失败，正在返回资源修复流程' => senseVoiceInitializationRepair,
      '会议启动失败，请检查录音权限、存储空间和默认模型后重试' => meetingStartFailed,
      '未检测到可用麦克风，请连接或启用输入设备后重试。' => noMicrophoneAvailable,
      '所选麦克风当前不可用，请在设置中重新选择。' => preferredMicrophoneUnavailable,
      '麦克风当前不可用，请检查输入设备后重试。' => microphoneCurrentlyUnavailable,
      '需要麦克风权限。授权后才能开始会议，未授权时不会创建会议。' => microphonePermissionStartRequirement,
      '存储空间不足。请至少保留 128 MB 可用空间后重试。' => storageStartRequirement,
      'SenseVoice 尚未准备完成，请返回初始化流程校验并修复' => senseVoiceNeedsRepair,
      '录音无法启动，请确认麦克风可用后重试' => recordingStartMicrophoneRetry,
      '无法使用麦克风，请在系统设置中授予麦克风权限后重试' => microphonePermissionDenied,
      '存储空间不足，请至少保留 128 MB 可用空间后重试' => recordingStorageInsufficient,
      '未检测到可用麦克风，请连接或启用输入设备后重试' => recordingInputUnavailable,
      '该会议已有事实音频，为避免覆盖已停止录音' => recordingAudioAlreadyExists,
      _ => null,
    };
    if (direct != null) {
      return direct;
    }
    final http = RegExp(r'^模型文件下载失败：HTTP (\d+)$').firstMatch(message);
    if (http != null) {
      return modelFileDownloadHttpError(http.group(1)!);
    }
    final size = RegExp(r'^文件大小应为 (\d+)，实际为 (\d+)$').firstMatch(message);
    if (size != null) {
      return modelFileSizeMismatch(size.group(1)!, size.group(2)!);
    }
    final incomplete = RegExp(r'^(.+) 下载不完整$').firstMatch(message);
    if (incomplete != null) {
      return modelFileDownloadIncomplete(incomplete.group(1)!);
    }
    final preparation = RegExp(r'^运行资源准备失败：(.+)$').firstMatch(message);
    if (preparation != null) {
      return runtimeResourcePreparationError(preparation.group(1)!);
    }
    final deviceCount = RegExp(r'^已发现 (\d+) 个 Windows 输入设备$')
        .firstMatch(message);
    if (deviceCount != null) {
      return windowsInputDeviceCount(int.parse(deviceCount.group(1)!));
    }
    final space = RegExp(r'^初始化至少需要 1 GiB 可用空间，还缺少 (\d+) 字节$')
        .firstMatch(message);
    if (space != null) {
      return initializationSpaceShortage(space.group(1)!);
    }
    final audioSpace = RegExp(r'^可用空间不足，还缺少 (.*)；未保留临时文件$').firstMatch(message);
    if (audioSpace != null) {
      return audioShareSpaceShortage(audioSpace.group(1)!);
    }
    final mobile = RegExp(r'^将使用移动网络下载约 ([\d.]+) MB，可能产生流量费用；下载可暂停并续传。$')
        .firstMatch(message);
    if (mobile != null) {
      return mobileDownloadWarning(mobile.group(1)!);
    }
    return localeName == 'zh' ? message : unexpectedError;
  }
}
