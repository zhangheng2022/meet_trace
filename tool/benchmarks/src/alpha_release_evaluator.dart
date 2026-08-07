import 'dart:math' as math;

/// 非阻断 Alpha 质量记录评估器；不参与 App 运行时或自动发布决策。
enum AlphaReleaseDecision { go, noGo, blocked }

enum ReleaseGateStatus { passed, failed, missing }

final class AlphaReleaseEvaluationInput {
  const AlphaReleaseEvaluationInput({
    this.corpusId,
    this.deviceId,
    this.rawMetricsRef,
    this.corpusSampleCount,
    this.corpusDeidentified,
    this.androidArm64DeviceTested,
    this.iosArm64DeviceTested,
    this.androidBackgroundRecordingPassed,
    this.iosBackgroundRecordingPassed,
    this.androidInterruptionRecoveryPassed,
    this.iosInterruptionRecoveryPassed,
    this.adaptiveNavigationAccessibilityPassed,
    this.alphaUpgradeResetPassed,
    this.textSharePassed,
    this.androidAudioSharePassed,
    this.iosAudioSharePassed,
    this.runtimeDownloadBytes,
    this.rtfSamples,
    this.sentenceLatencyMs,
    this.finalTranscriptionDurationMs,
    this.recordingCompletenessRatio,
    this.sustainedSevereOrCriticalThermal,
    this.batteryDeltaPercent,
    this.startTemperatureC,
    this.peakTemperatureC,
    this.peakRssBytes,
    this.keyFactRecallRatio,
    this.diarizationCorpusMinutes,
    this.diarizationTestedSpeakerCounts,
    this.diarizationDer,
    this.diarizationMaxSpeakerCountAbsoluteError,
    this.diarizationRtf,
    this.diarizationRepeatedRunPeakRssBytes,
    this.androidSpeakerDiarizationTested,
    this.iosSpeakerDiarizationTested,
    this.acceptanceEvidence,
    this.apkAuditPassed,
    this.iosBuildAuditPassed,
    this.senseVoiceLicenseConfirmed,
  });

  factory AlphaReleaseEvaluationInput.fromJson(Map<String, Object?> json) {
    final corpus = _map(json['corpus']);
    final environment = _map(json['environment']);
    final model = _map(json['senseVoice']);
    final diarization = _map(json['speakerDiarization']);
    final release = _map(json['release']);
    return AlphaReleaseEvaluationInput(
      corpusId: _string(corpus?['id']),
      deviceId: _string(environment?['deviceId']),
      rawMetricsRef: _string(json['rawMetricsRef']),
      corpusSampleCount: _integer(corpus?['sampleCount']),
      corpusDeidentified: _boolean(corpus?['deidentified']),
      androidArm64DeviceTested: _boolean(
        environment?['androidArm64DeviceTested'],
      ),
      iosArm64DeviceTested: _boolean(environment?['iosArm64DeviceTested']),
      androidBackgroundRecordingPassed: _boolean(
        environment?['androidBackgroundRecordingPassed'],
      ),
      iosBackgroundRecordingPassed: _boolean(
        environment?['iosBackgroundRecordingPassed'],
      ),
      androidInterruptionRecoveryPassed: _boolean(
        environment?['androidInterruptionRecoveryPassed'],
      ),
      iosInterruptionRecoveryPassed: _boolean(
        environment?['iosInterruptionRecoveryPassed'],
      ),
      adaptiveNavigationAccessibilityPassed: _boolean(
        environment?['adaptiveNavigationAccessibilityPassed'],
      ),
      alphaUpgradeResetPassed: _boolean(
        environment?['alphaUpgradeResetPassed'],
      ),
      textSharePassed: _boolean(environment?['textSharePassed']),
      androidAudioSharePassed: _boolean(
        environment?['androidAudioSharePassed'],
      ),
      iosAudioSharePassed: _boolean(environment?['iosAudioSharePassed']),
      runtimeDownloadBytes: _integer(model?['runtimeDownloadBytes']),
      rtfSamples: _numbers(model?['rtfSamples']),
      sentenceLatencyMs: _numbers(model?['sentenceLatencyMs']),
      finalTranscriptionDurationMs: _number(
        model?['finalTranscriptionDurationMs'],
      ),
      recordingCompletenessRatio: _number(model?['recordingCompletenessRatio']),
      sustainedSevereOrCriticalThermal: _boolean(
        model?['sustainedSevereOrCriticalThermal'],
      ),
      batteryDeltaPercent: _number(model?['batteryDeltaPercent']),
      startTemperatureC: _number(model?['startTemperatureC']),
      peakTemperatureC: _number(model?['peakTemperatureC']),
      peakRssBytes: _integer(model?['peakRssBytes']),
      keyFactRecallRatio: _number(model?['keyFactRecallRatio']),
      diarizationCorpusMinutes: _number(diarization?['corpusMinutes']),
      diarizationTestedSpeakerCounts: _integers(
        diarization?['testedSpeakerCounts'],
      ),
      diarizationDer: _number(diarization?['der']),
      diarizationMaxSpeakerCountAbsoluteError: _integer(
        diarization?['maxSpeakerCountAbsoluteError'],
      ),
      diarizationRtf: _number(diarization?['rtf']),
      diarizationRepeatedRunPeakRssBytes: _integer(
        diarization?['repeatedRunPeakRssBytes'],
      ),
      androidSpeakerDiarizationTested: _boolean(
        diarization?['androidArm64Tested'],
      ),
      iosSpeakerDiarizationTested: _boolean(diarization?['iosArm64Tested']),
      acceptanceEvidence: _strings(json['acceptanceEvidence']),
      apkAuditPassed: _boolean(release?['apkAuditPassed']),
      iosBuildAuditPassed: _boolean(release?['iosBuildAuditPassed']),
      senseVoiceLicenseConfirmed: _boolean(
        release?['senseVoiceLicenseConfirmed'],
      ),
    );
  }

  final String? corpusId;
  final String? deviceId;
  final String? rawMetricsRef;
  final int? corpusSampleCount;
  final bool? corpusDeidentified;
  final bool? androidArm64DeviceTested;
  final bool? iosArm64DeviceTested;
  final bool? androidBackgroundRecordingPassed;
  final bool? iosBackgroundRecordingPassed;
  final bool? androidInterruptionRecoveryPassed;
  final bool? iosInterruptionRecoveryPassed;
  final bool? adaptiveNavigationAccessibilityPassed;
  final bool? alphaUpgradeResetPassed;
  final bool? textSharePassed;
  final bool? androidAudioSharePassed;
  final bool? iosAudioSharePassed;
  final int? runtimeDownloadBytes;
  final List<double>? rtfSamples;
  final List<double>? sentenceLatencyMs;
  final double? finalTranscriptionDurationMs;
  final double? recordingCompletenessRatio;
  final bool? sustainedSevereOrCriticalThermal;
  final double? batteryDeltaPercent;
  final double? startTemperatureC;
  final double? peakTemperatureC;
  final int? peakRssBytes;
  final double? keyFactRecallRatio;
  final double? diarizationCorpusMinutes;
  final List<int>? diarizationTestedSpeakerCounts;
  final double? diarizationDer;
  final int? diarizationMaxSpeakerCountAbsoluteError;
  final double? diarizationRtf;
  final int? diarizationRepeatedRunPeakRssBytes;
  final bool? androidSpeakerDiarizationTested;
  final bool? iosSpeakerDiarizationTested;
  final Map<String, String>? acceptanceEvidence;
  final bool? apkAuditPassed;
  final bool? iosBuildAuditPassed;
  final bool? senseVoiceLicenseConfirmed;

  AlphaReleaseEvaluationInput copyWith({
    List<double>? rtfSamples,
    String? rawMetricsRef,
    bool? iosBackgroundRecordingPassed,
    double? diarizationDer,
    int? diarizationMaxSpeakerCountAbsoluteError,
    double? diarizationRtf,
    List<int>? diarizationTestedSpeakerCounts,
    Map<String, String>? acceptanceEvidence,
    bool? androidAudioSharePassed,
  }) => AlphaReleaseEvaluationInput(
    corpusId: corpusId,
    deviceId: deviceId,
    rawMetricsRef: rawMetricsRef ?? this.rawMetricsRef,
    corpusSampleCount: corpusSampleCount,
    corpusDeidentified: corpusDeidentified,
    androidArm64DeviceTested: androidArm64DeviceTested,
    iosArm64DeviceTested: iosArm64DeviceTested,
    androidBackgroundRecordingPassed: androidBackgroundRecordingPassed,
    iosBackgroundRecordingPassed:
        iosBackgroundRecordingPassed ?? this.iosBackgroundRecordingPassed,
    androidInterruptionRecoveryPassed: androidInterruptionRecoveryPassed,
    iosInterruptionRecoveryPassed: iosInterruptionRecoveryPassed,
    adaptiveNavigationAccessibilityPassed:
        adaptiveNavigationAccessibilityPassed,
    alphaUpgradeResetPassed: alphaUpgradeResetPassed,
    textSharePassed: textSharePassed,
    androidAudioSharePassed:
        androidAudioSharePassed ?? this.androidAudioSharePassed,
    iosAudioSharePassed: iosAudioSharePassed,
    runtimeDownloadBytes: runtimeDownloadBytes,
    rtfSamples: rtfSamples ?? this.rtfSamples,
    sentenceLatencyMs: sentenceLatencyMs,
    finalTranscriptionDurationMs: finalTranscriptionDurationMs,
    recordingCompletenessRatio: recordingCompletenessRatio,
    sustainedSevereOrCriticalThermal: sustainedSevereOrCriticalThermal,
    batteryDeltaPercent: batteryDeltaPercent,
    startTemperatureC: startTemperatureC,
    peakTemperatureC: peakTemperatureC,
    peakRssBytes: peakRssBytes,
    keyFactRecallRatio: keyFactRecallRatio,
    diarizationCorpusMinutes: diarizationCorpusMinutes,
    diarizationTestedSpeakerCounts:
        diarizationTestedSpeakerCounts ?? this.diarizationTestedSpeakerCounts,
    diarizationDer: diarizationDer ?? this.diarizationDer,
    diarizationMaxSpeakerCountAbsoluteError:
        diarizationMaxSpeakerCountAbsoluteError ??
        this.diarizationMaxSpeakerCountAbsoluteError,
    diarizationRtf: diarizationRtf ?? this.diarizationRtf,
    diarizationRepeatedRunPeakRssBytes: diarizationRepeatedRunPeakRssBytes,
    androidSpeakerDiarizationTested: androidSpeakerDiarizationTested,
    iosSpeakerDiarizationTested: iosSpeakerDiarizationTested,
    acceptanceEvidence: acceptanceEvidence ?? this.acceptanceEvidence,
    apkAuditPassed: apkAuditPassed,
    iosBuildAuditPassed: iosBuildAuditPassed,
    senseVoiceLicenseConfirmed: senseVoiceLicenseConfirmed,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 4,
    'rawMetricsRef': rawMetricsRef,
    'corpus': {
      'id': corpusId,
      'sampleCount': corpusSampleCount,
      'deidentified': corpusDeidentified,
    },
    'environment': {
      'deviceId': deviceId,
      'androidArm64DeviceTested': androidArm64DeviceTested,
      'iosArm64DeviceTested': iosArm64DeviceTested,
      'androidBackgroundRecordingPassed': androidBackgroundRecordingPassed,
      'iosBackgroundRecordingPassed': iosBackgroundRecordingPassed,
      'androidInterruptionRecoveryPassed': androidInterruptionRecoveryPassed,
      'iosInterruptionRecoveryPassed': iosInterruptionRecoveryPassed,
      'adaptiveNavigationAccessibilityPassed':
          adaptiveNavigationAccessibilityPassed,
      'alphaUpgradeResetPassed': alphaUpgradeResetPassed,
      'textSharePassed': textSharePassed,
      'androidAudioSharePassed': androidAudioSharePassed,
      'iosAudioSharePassed': iosAudioSharePassed,
    },
    'senseVoice': {
      'runtimeDownloadBytes': runtimeDownloadBytes,
      'rtfSamples': rtfSamples,
      'sentenceLatencyMs': sentenceLatencyMs,
      'finalTranscriptionDurationMs': finalTranscriptionDurationMs,
      'recordingCompletenessRatio': recordingCompletenessRatio,
      'sustainedSevereOrCriticalThermal': sustainedSevereOrCriticalThermal,
      'batteryDeltaPercent': batteryDeltaPercent,
      'startTemperatureC': startTemperatureC,
      'peakTemperatureC': peakTemperatureC,
      'peakRssBytes': peakRssBytes,
      'keyFactRecallRatio': keyFactRecallRatio,
    },
    'speakerDiarization': {
      'corpusMinutes': diarizationCorpusMinutes,
      'testedSpeakerCounts': diarizationTestedSpeakerCounts,
      'der': diarizationDer,
      'maxSpeakerCountAbsoluteError': diarizationMaxSpeakerCountAbsoluteError,
      'rtf': diarizationRtf,
      'repeatedRunPeakRssBytes': diarizationRepeatedRunPeakRssBytes,
      'androidArm64Tested': androidSpeakerDiarizationTested,
      'iosArm64Tested': iosSpeakerDiarizationTested,
    },
    'acceptanceEvidence': acceptanceEvidence,
    'release': {
      'apkAuditPassed': apkAuditPassed,
      'iosBuildAuditPassed': iosBuildAuditPassed,
      'senseVoiceLicenseConfirmed': senseVoiceLicenseConfirmed,
    },
  };
}

final class ReleaseGateResult {
  const ReleaseGateResult({
    required this.id,
    required this.requirement,
    required this.status,
    this.value,
  });

  final String id;
  final String requirement;
  final ReleaseGateStatus status;
  final Object? value;

  Map<String, Object?> toJson() => {
    'id': id,
    'requirement': requirement,
    'status': status.name,
    'value': value,
  };
}

final class AlphaReleaseEvaluationReport {
  const AlphaReleaseEvaluationReport({
    required this.decision,
    required this.corpusId,
    required this.deviceId,
    required this.rawMetricsRef,
    required this.metrics,
    required this.gates,
  });

  final AlphaReleaseDecision decision;
  final String? corpusId;
  final String? deviceId;
  final String? rawMetricsRef;
  final Map<String, Object?> metrics;
  final List<ReleaseGateResult> gates;

  Map<String, Object?> toJson() => {
    'schemaVersion': 3,
    'decision': decision.name,
    'corpusId': corpusId,
    'deviceId': deviceId,
    'rawMetricsRef': rawMetricsRef,
    'metrics': metrics,
    'gates': gates.map((gate) => gate.toJson()).toList(growable: false),
  };
}

final class EvaluateAlphaReleaseUseCase {
  const EvaluateAlphaReleaseUseCase();

  AlphaReleaseEvaluationReport execute(AlphaReleaseEvaluationInput input) {
    final rtfP95 = _percentile(input.rtfSamples, 0.95);
    final latencyP95 = _percentile(input.sentenceLatencyMs, 0.95);
    final evidenceCount = _acceptanceEvidenceCount(input.acceptanceEvidence);
    final gates = <ReleaseGateResult>[
      _referenceGate('corpus.id', '评测语料必须具有去敏可追溯标识', input.corpusId),
      _thresholdGate(
        'corpus.sampleCount',
        '去敏语料不少于 20 段',
        input.corpusSampleCount,
        (v) => v >= 20,
      ),
      _boolGate('corpus.deidentified', '评测语料已去敏', input.corpusDeidentified),
      _textGate('environment.deviceId', '评测设备具有可追溯标识', input.deviceId),
      _boolGate(
        'environment.androidArm64',
        'Android arm64 目标真机已验证',
        input.androidArm64DeviceTested,
      ),
      _boolGate(
        'environment.iosArm64',
        'iOS arm64 目标真机已验证',
        input.iosArm64DeviceTested,
      ),
      _boolGate(
        'environment.androidBackgroundRecording',
        'Android 30 分钟后台录音完整',
        input.androidBackgroundRecordingPassed,
      ),
      _boolGate(
        'environment.iosBackgroundRecording',
        'iOS 30 分钟后台录音完整',
        input.iosBackgroundRecordingPassed,
      ),
      _boolGate(
        'environment.androidInterruptionRecovery',
        'Android 系统音频中断恢复通过',
        input.androidInterruptionRecoveryPassed,
      ),
      _boolGate(
        'environment.iosInterruptionRecovery',
        'iOS 系统音频中断恢复通过',
        input.iosInterruptionRecoveryPassed,
      ),
      _boolGate(
        'environment.accessibility',
        '双平台导航、字体和辅助技术通过',
        input.adaptiveNavigationAccessibilityPassed,
      ),
      _boolGate(
        'environment.alphaUpgradeReset',
        '旧 Alpha 升级全清并重新初始化通过',
        input.alphaUpgradeResetPassed,
      ),
      _boolGate(
        'environment.textShare',
        '文本分享仅包含允许的最终转录内容',
        input.textSharePassed,
      ),
      _boolGate(
        'environment.androidAudioShare',
        'Android 音频分享播放与全路径清理通过',
        input.androidAudioSharePassed,
      ),
      _boolGate(
        'environment.iosAudioShare',
        'iOS 音频分享播放与全路径清理通过',
        input.iosAudioSharePassed,
      ),
      _referenceGate('evidence.rawMetrics', '原始指标具有可追溯引用', input.rawMetricsRef),
      _thresholdGate(
        'senseVoice.runtimeDownloadBytes',
        'ASR 与 VAD 固定下载量不超过 300,000,000 字节',
        input.runtimeDownloadBytes,
        (v) => v <= 300000000,
      ),
      _thresholdGate(
        'senseVoice.rtfP95',
        'RTF P95 严格小于 0.5',
        rtfP95,
        (v) => v < 0.5,
      ),
      _thresholdGate(
        'senseVoice.sentenceLatencyP95Ms',
        '句后出字 P95 不超过 3000 ms',
        latencyP95,
        (v) => v <= 3000,
      ),
      _thresholdGate(
        'senseVoice.finalTranscriptionDurationMs',
        '30 分钟最终转录不超过 300000 ms',
        input.finalTranscriptionDurationMs,
        (v) => v <= 300000,
      ),
      _thresholdGate(
        'senseVoice.recordingCompletenessRatio',
        '30 分钟录音完整率为 100%',
        input.recordingCompletenessRatio,
        (v) => v >= 1,
      ),
      _inverseBoolGate(
        'senseVoice.thermal',
        '30 分钟内不持续 Severe/Critical',
        input.sustainedSevereOrCriticalThermal,
      ),
      _measurementGate(
        'senseVoice.batteryDeltaPercent',
        '记录 30 分钟绝对电量变化',
        input.batteryDeltaPercent,
      ),
      _measurementGate(
        'senseVoice.startTemperatureC',
        '记录测试起始温度',
        input.startTemperatureC,
      ),
      _measurementGate(
        'senseVoice.peakTemperatureC',
        '记录测试最高温度',
        input.peakTemperatureC,
      ),
      _thresholdGate(
        'senseVoice.peakRssBytes',
        '记录正数内存峰值',
        input.peakRssBytes,
        (v) => v > 0,
      ),
      _thresholdGate(
        'senseVoice.keyFactRecallRatio',
        '关键事实召回率不低于 85%',
        input.keyFactRecallRatio,
        (v) => v >= 0.85,
      ),
      _thresholdGate(
        'speakerDiarization.corpusMinutes',
        '普通话 2/3/4 人固定标注语料不少于 60 分钟',
        input.diarizationCorpusMinutes,
        (v) => v >= 60,
      ),
      _speakerCountsGate(input.diarizationTestedSpeakerCounts),
      _thresholdGate(
        'speakerDiarization.der',
        '说话人分离 DER 不超过 25%',
        input.diarizationDer,
        (v) => v >= 0 && v <= 0.25,
      ),
      _thresholdGate(
        'speakerDiarization.maxSpeakerCountAbsoluteError',
        '说话人数绝对误差不超过 1',
        input.diarizationMaxSpeakerCountAbsoluteError,
        (v) => v >= 0 && v <= 1,
      ),
      _thresholdGate(
        'speakerDiarization.rtf',
        '说话人分离 30 分钟 RTF 不超过 0.5',
        input.diarizationRtf,
        (v) => v > 0 && v <= 0.5,
      ),
      _thresholdGate(
        'speakerDiarization.repeatedRunPeakRssBytes',
        '记录 30 分钟重复分离任务的正数内存峰值',
        input.diarizationRepeatedRunPeakRssBytes,
        (v) => v > 0,
      ),
      _boolGate(
        'speakerDiarization.androidArm64',
        'Android arm64 真机说话人分离已验证',
        input.androidSpeakerDiarizationTested,
      ),
      _boolGate(
        'speakerDiarization.iosArm64',
        'iOS arm64 真机说话人分离已验证',
        input.iosSpeakerDiarizationTested,
      ),
      _thresholdGate(
        'acceptance.AT01-AT18',
        'AT-01 至 AT-18 均有证据引用',
        evidenceCount,
        (v) => v == 18,
      ),
      _boolGate(
        'release.apkAudit',
        'Android APK 不包含 ASR/VAD 权重',
        input.apkAuditPassed,
      ),
      _boolGate(
        'release.iosBuildAudit',
        'iOS 构建不包含 ASR/VAD 权重',
        input.iosBuildAuditPassed,
      ),
      _boolGate(
        'license.senseVoice',
        'SenseVoice 分发许可与 NOTICE 已确认',
        input.senseVoiceLicenseConfirmed,
      ),
    ];
    final failed = gates.any((gate) => gate.status == ReleaseGateStatus.failed);
    final missing = gates.any(
      (gate) => gate.status == ReleaseGateStatus.missing,
    );
    return AlphaReleaseEvaluationReport(
      decision: failed
          ? AlphaReleaseDecision.noGo
          : missing
          ? AlphaReleaseDecision.blocked
          : AlphaReleaseDecision.go,
      corpusId: input.corpusId,
      deviceId: input.deviceId,
      rawMetricsRef: input.rawMetricsRef,
      metrics: {
        'rtfP50': _percentile(input.rtfSamples, 0.5),
        'rtfP95': rtfP95,
        'sentenceLatencyP50Ms': _percentile(input.sentenceLatencyMs, 0.5),
        'sentenceLatencyP95Ms': latencyP95,
        'batteryDeltaPercent': input.batteryDeltaPercent,
        'startTemperatureC': input.startTemperatureC,
        'peakTemperatureC': input.peakTemperatureC,
        'peakRssBytes': input.peakRssBytes,
        'diarizationDer': input.diarizationDer,
        'diarizationMaxSpeakerCountAbsoluteError':
            input.diarizationMaxSpeakerCountAbsoluteError,
        'diarizationRtf': input.diarizationRtf,
        'diarizationRepeatedRunPeakRssBytes':
            input.diarizationRepeatedRunPeakRssBytes,
      },
      gates: List.unmodifiable(gates),
    );
  }
}

ReleaseGateResult _textGate(String id, String requirement, String? value) {
  final normalized = value?.trim();
  return ReleaseGateResult(
    id: id,
    requirement: requirement,
    status: normalized == null || normalized.isEmpty
        ? ReleaseGateStatus.missing
        : ReleaseGateStatus.passed,
    value: normalized,
  );
}

ReleaseGateResult _referenceGate(String id, String requirement, String? value) {
  final normalized = value?.trim();
  final unsafe =
      normalized != null &&
      RegExp(
        r'\.(wav|pcm|m4a|aac|mp3|ogg|flac)(?:$|[?#])',
        caseSensitive: false,
      ).hasMatch(normalized);
  return ReleaseGateResult(
    id: id,
    requirement: requirement,
    status: normalized == null || normalized.isEmpty
        ? ReleaseGateStatus.missing
        : unsafe
        ? ReleaseGateStatus.failed
        : ReleaseGateStatus.passed,
    value: normalized,
  );
}

ReleaseGateResult _boolGate(String id, String requirement, bool? value) =>
    ReleaseGateResult(
      id: id,
      requirement: requirement,
      status: value == null
          ? ReleaseGateStatus.missing
          : value
          ? ReleaseGateStatus.passed
          : ReleaseGateStatus.failed,
      value: value,
    );

ReleaseGateResult _inverseBoolGate(
  String id,
  String requirement,
  bool? value,
) => ReleaseGateResult(
  id: id,
  requirement: requirement,
  status: value == null
      ? ReleaseGateStatus.missing
      : value
      ? ReleaseGateStatus.failed
      : ReleaseGateStatus.passed,
  value: value,
);

ReleaseGateResult _thresholdGate<T extends num>(
  String id,
  String requirement,
  T? value,
  bool Function(T value) passes,
) => ReleaseGateResult(
  id: id,
  requirement: requirement,
  status: value == null
      ? ReleaseGateStatus.missing
      : passes(value)
      ? ReleaseGateStatus.passed
      : ReleaseGateStatus.failed,
  value: value,
);

ReleaseGateResult _measurementGate(
  String id,
  String requirement,
  double? value,
) => ReleaseGateResult(
  id: id,
  requirement: requirement,
  status: value == null || !value.isFinite || value < 0
      ? value == null
            ? ReleaseGateStatus.missing
            : ReleaseGateStatus.failed
      : ReleaseGateStatus.passed,
  value: value,
);

double? _percentile(List<double>? samples, double percentile) {
  if (samples == null ||
      samples.length < 20 ||
      samples.any((v) => !v.isFinite || v < 0)) {
    return null;
  }
  final sorted = [...samples]..sort();
  return sorted[math.max(1, (sorted.length * percentile).ceil()) - 1];
}

int? _acceptanceEvidenceCount(Map<String, String>? evidence) {
  if (evidence == null) {
    return null;
  }
  return [
    for (var i = 1; i <= 18; i++) 'AT-${i.toString().padLeft(2, '0')}',
  ].where((id) => evidence[id]?.trim().isNotEmpty == true).length;
}

ReleaseGateResult _speakerCountsGate(List<int>? value) {
  if (value == null) {
    return const ReleaseGateResult(
      id: 'speakerDiarization.testedSpeakerCounts',
      requirement: '普通话 2、3、4 人语料均已验证',
      status: ReleaseGateStatus.missing,
    );
  }
  final normalized = value.toSet();
  final passed = normalized.length == 3 && normalized.containsAll({2, 3, 4});
  return ReleaseGateResult(
    id: 'speakerDiarization.testedSpeakerCounts',
    requirement: '普通话 2、3、4 人语料均已验证',
    status: passed ? ReleaseGateStatus.passed : ReleaseGateStatus.failed,
    value: List<int>.unmodifiable(value),
  );
}

Map<String, Object?>? _map(Object? value) =>
    value is Map<String, Object?> ? value : null;
String? _string(Object? value) => value is String ? value : null;
bool? _boolean(Object? value) => value is bool ? value : null;
int? _integer(Object? value) => value is int ? value : null;
double? _number(Object? value) => value is num ? value.toDouble() : null;
List<double>? _numbers(Object? value) {
  if (value is! List<Object?> || value.any((item) => item is! num)) {
    return null;
  }
  return List.unmodifiable(
    value.cast<num>().map((number) => number.toDouble()),
  );
}

List<int>? _integers(Object? value) {
  if (value is! List<Object?> || value.any((item) => item is! int)) {
    return null;
  }
  return List<int>.unmodifiable(value.cast<int>());
}

Map<String, String>? _strings(Object? value) {
  if (value is! Map<String, Object?> ||
      value.values.any((item) => item is! String)) {
    return null;
  }
  return Map.unmodifiable(
    value.map((key, item) => MapEntry(key, item! as String)),
  );
}
