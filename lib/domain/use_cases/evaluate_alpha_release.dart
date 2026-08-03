import 'dart:math' as math;

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
    this.iosInterruptionRecoveryPassed,
    this.adaptiveNavigationAccessibilityPassed,
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
    this.acceptanceEvidence,
    this.apkAuditPassed,
    this.iosBuildAuditPassed,
    this.senseVoiceLicenseConfirmed,
  });

  factory AlphaReleaseEvaluationInput.fromJson(Map<String, Object?> json) {
    final corpus = _map(json['corpus']);
    final environment = _map(json['environment']);
    final model = _map(json['senseVoice']);
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
      iosInterruptionRecoveryPassed: _boolean(
        environment?['iosInterruptionRecoveryPassed'],
      ),
      adaptiveNavigationAccessibilityPassed: _boolean(
        environment?['adaptiveNavigationAccessibilityPassed'],
      ),
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
  final bool? iosInterruptionRecoveryPassed;
  final bool? adaptiveNavigationAccessibilityPassed;
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
  final Map<String, String>? acceptanceEvidence;
  final bool? apkAuditPassed;
  final bool? iosBuildAuditPassed;
  final bool? senseVoiceLicenseConfirmed;

  AlphaReleaseEvaluationInput copyWith({
    List<double>? rtfSamples,
    String? rawMetricsRef,
    bool? iosBackgroundRecordingPassed,
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
    iosInterruptionRecoveryPassed: iosInterruptionRecoveryPassed,
    adaptiveNavigationAccessibilityPassed:
        adaptiveNavigationAccessibilityPassed,
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
    acceptanceEvidence: acceptanceEvidence,
    apkAuditPassed: apkAuditPassed,
    iosBuildAuditPassed: iosBuildAuditPassed,
    senseVoiceLicenseConfirmed: senseVoiceLicenseConfirmed,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 3,
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
      'iosInterruptionRecoveryPassed': iosInterruptionRecoveryPassed,
      'adaptiveNavigationAccessibilityPassed':
          adaptiveNavigationAccessibilityPassed,
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
    'schemaVersion': 2,
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
        'environment.iosInterruptionRecovery',
        'iOS 系统音频中断恢复通过',
        input.iosInterruptionRecoveryPassed,
      ),
      _boolGate(
        'environment.accessibility',
        '双平台导航、字体和辅助技术通过',
        input.adaptiveNavigationAccessibilityPassed,
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
        'acceptance.AT01-AT15',
        'AT-01 至 AT-15 均有证据引用',
        evidenceCount,
        (v) => v == 15,
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
    for (var i = 1; i <= 15; i++) 'AT-${i.toString().padLeft(2, '0')}',
  ].where((id) => evidence[id]?.trim().isNotEmpty == true).length;
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

Map<String, String>? _strings(Object? value) {
  if (value is! Map<String, Object?> ||
      value.values.any((item) => item is! String)) {
    return null;
  }
  return Map.unmodifiable(
    value.map((key, item) => MapEntry(key, item! as String)),
  );
}
