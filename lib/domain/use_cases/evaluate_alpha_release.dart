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
    this.sameCorpusForBothModels,
    this.sameDeviceForBothModels,
    this.lowEndArm64DeviceTested,
    this.standardModelResourceBytes,
    this.standardRtfSamples,
    this.standardSentenceLatencyMs,
    this.finalTranscriptionDurationMs,
    this.recordingCompletenessRatio,
    this.sustainedSevereOrCriticalThermal,
    this.standardEnergyWh,
    this.advancedEnergyWh,
    this.advancedRtfSamples,
    this.advancedSentenceLatencyMs,
    this.advancedFinalTranscriptionDurationMs,
    this.keyFactRecallRatio,
    this.acceptanceEvidence,
    this.apkAuditPassed,
    this.paraformerRedistributionConfirmed,
  });

  factory AlphaReleaseEvaluationInput.fromJson(Map<String, Object?> json) {
    final corpus = _map(json['corpus']);
    final environment = _map(json['environment']);
    final standard = _map(json['standardModel']);
    final advanced = _map(json['advancedModel']);
    final energy = _map(json['energy']);
    final release = _map(json['release']);
    return AlphaReleaseEvaluationInput(
      corpusId: _string(corpus?['id']),
      deviceId: _string(environment?['deviceId']),
      rawMetricsRef: _string(json['rawMetricsRef']),
      corpusSampleCount: _integer(corpus?['sampleCount']),
      corpusDeidentified: _boolean(corpus?['deidentified']),
      sameCorpusForBothModels: _boolean(
        environment?['sameCorpusForBothModels'],
      ),
      sameDeviceForBothModels: _boolean(
        environment?['sameDeviceForBothModels'],
      ),
      lowEndArm64DeviceTested: _boolean(
        environment?['lowEndArm64DeviceTested'],
      ),
      standardModelResourceBytes: _integer(standard?['resourceBytes']),
      standardRtfSamples: _numbers(standard?['rtfSamples']),
      standardSentenceLatencyMs: _numbers(standard?['sentenceLatencyMs']),
      finalTranscriptionDurationMs: _number(
        standard?['finalTranscriptionDurationMs'],
      ),
      recordingCompletenessRatio: _number(
        standard?['recordingCompletenessRatio'],
      ),
      sustainedSevereOrCriticalThermal: _boolean(
        standard?['sustainedSevereOrCriticalThermal'],
      ),
      standardEnergyWh: _number(energy?['standardWh']),
      advancedEnergyWh: _number(energy?['advancedWh']),
      advancedRtfSamples: _numbers(advanced?['rtfSamples']),
      advancedSentenceLatencyMs: _numbers(advanced?['sentenceLatencyMs']),
      advancedFinalTranscriptionDurationMs: _number(
        advanced?['finalTranscriptionDurationMs'],
      ),
      keyFactRecallRatio: _number(standard?['keyFactRecallRatio']),
      acceptanceEvidence: _strings(json['acceptanceEvidence']),
      apkAuditPassed: _boolean(release?['apkAuditPassed']),
      paraformerRedistributionConfirmed: _boolean(
        release?['paraformerRedistributionConfirmed'],
      ),
    );
  }

  final String? corpusId;
  final String? deviceId;
  final String? rawMetricsRef;
  final int? corpusSampleCount;
  final bool? corpusDeidentified;
  final bool? sameCorpusForBothModels;
  final bool? sameDeviceForBothModels;
  final bool? lowEndArm64DeviceTested;
  final int? standardModelResourceBytes;
  final List<double>? standardRtfSamples;
  final List<double>? standardSentenceLatencyMs;
  final double? finalTranscriptionDurationMs;
  final double? recordingCompletenessRatio;
  final bool? sustainedSevereOrCriticalThermal;
  final double? standardEnergyWh;
  final double? advancedEnergyWh;
  final List<double>? advancedRtfSamples;
  final List<double>? advancedSentenceLatencyMs;
  final double? advancedFinalTranscriptionDurationMs;
  final double? keyFactRecallRatio;
  final Map<String, String>? acceptanceEvidence;
  final bool? apkAuditPassed;
  final bool? paraformerRedistributionConfirmed;

  AlphaReleaseEvaluationInput copyWith({
    List<double>? standardRtfSamples,
    String? rawMetricsRef,
  }) => AlphaReleaseEvaluationInput(
    corpusId: corpusId,
    deviceId: deviceId,
    rawMetricsRef: rawMetricsRef ?? this.rawMetricsRef,
    corpusSampleCount: corpusSampleCount,
    corpusDeidentified: corpusDeidentified,
    sameCorpusForBothModels: sameCorpusForBothModels,
    sameDeviceForBothModels: sameDeviceForBothModels,
    lowEndArm64DeviceTested: lowEndArm64DeviceTested,
    standardModelResourceBytes: standardModelResourceBytes,
    standardRtfSamples: standardRtfSamples ?? this.standardRtfSamples,
    standardSentenceLatencyMs: standardSentenceLatencyMs,
    finalTranscriptionDurationMs: finalTranscriptionDurationMs,
    recordingCompletenessRatio: recordingCompletenessRatio,
    sustainedSevereOrCriticalThermal: sustainedSevereOrCriticalThermal,
    standardEnergyWh: standardEnergyWh,
    advancedEnergyWh: advancedEnergyWh,
    advancedRtfSamples: advancedRtfSamples,
    advancedSentenceLatencyMs: advancedSentenceLatencyMs,
    advancedFinalTranscriptionDurationMs: advancedFinalTranscriptionDurationMs,
    keyFactRecallRatio: keyFactRecallRatio,
    acceptanceEvidence: acceptanceEvidence,
    apkAuditPassed: apkAuditPassed,
    paraformerRedistributionConfirmed: paraformerRedistributionConfirmed,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'rawMetricsRef': rawMetricsRef,
    'corpus': {
      'id': corpusId,
      'sampleCount': corpusSampleCount,
      'deidentified': corpusDeidentified,
    },
    'environment': {
      'deviceId': deviceId,
      'sameCorpusForBothModels': sameCorpusForBothModels,
      'sameDeviceForBothModels': sameDeviceForBothModels,
      'lowEndArm64DeviceTested': lowEndArm64DeviceTested,
    },
    'standardModel': {
      'resourceBytes': standardModelResourceBytes,
      'rtfSamples': standardRtfSamples,
      'sentenceLatencyMs': standardSentenceLatencyMs,
      'finalTranscriptionDurationMs': finalTranscriptionDurationMs,
      'recordingCompletenessRatio': recordingCompletenessRatio,
      'sustainedSevereOrCriticalThermal': sustainedSevereOrCriticalThermal,
      'keyFactRecallRatio': keyFactRecallRatio,
    },
    'energy': {'standardWh': standardEnergyWh, 'advancedWh': advancedEnergyWh},
    'advancedModel': {
      'rtfSamples': advancedRtfSamples,
      'sentenceLatencyMs': advancedSentenceLatencyMs,
      'finalTranscriptionDurationMs': advancedFinalTranscriptionDurationMs,
    },
    'acceptanceEvidence': acceptanceEvidence,
    'release': {
      'apkAuditPassed': apkAuditPassed,
      'paraformerRedistributionConfirmed': paraformerRedistributionConfirmed,
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
    required this.comparison,
    required this.gates,
  });

  final AlphaReleaseDecision decision;
  final String? corpusId;
  final String? deviceId;
  final String? rawMetricsRef;
  final Map<String, Object?> comparison;
  final List<ReleaseGateResult> gates;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'decision': decision.name,
    'corpusId': corpusId,
    'deviceId': deviceId,
    'rawMetricsRef': rawMetricsRef,
    'comparison': comparison,
    'summary': {
      'passed': gates
          .where((gate) => gate.status == ReleaseGateStatus.passed)
          .length,
      'failed': gates
          .where((gate) => gate.status == ReleaseGateStatus.failed)
          .length,
      'missing': gates
          .where((gate) => gate.status == ReleaseGateStatus.missing)
          .length,
    },
    'gates': gates.map((gate) => gate.toJson()).toList(growable: false),
  };
}

final class EvaluateAlphaReleaseUseCase {
  const EvaluateAlphaReleaseUseCase();

  AlphaReleaseEvaluationReport execute(AlphaReleaseEvaluationInput input) {
    final rtfP95 = _p95(input.standardRtfSamples, minimumSamples: 20);
    final latencyP95 = _p95(
      input.standardSentenceLatencyMs,
      minimumSamples: 20,
    );
    final advancedRtfP95 = _p95(input.advancedRtfSamples, minimumSamples: 20);
    final advancedLatencyP95 = _p95(
      input.advancedSentenceLatencyMs,
      minimumSamples: 20,
    );
    final relativeEnergy = _ratio(
      input.standardEnergyWh,
      input.advancedEnergyWh,
    );
    final acceptanceCount = _acceptanceEvidenceCount(input.acceptanceEvidence);
    final gates = <ReleaseGateResult>[
      _referenceGate('corpus.id', '评测语料必须具有不含音频路径的可追溯标识', input.corpusId),
      _thresholdGate(
        'corpus.sampleCount',
        '去敏会议语料不少于 20 段',
        input.corpusSampleCount,
        (value) => value >= 20,
      ),
      _boolGate('corpus.deidentified', '评测语料已去敏', input.corpusDeidentified),
      _boolGate(
        'environment.sameCorpus',
        '双模型使用相同语料',
        input.sameCorpusForBothModels,
      ),
      _boolGate(
        'environment.sameDevice',
        '双模型使用相同设备和环境',
        input.sameDeviceForBothModels,
      ),
      _textGate('environment.deviceId', '评测设备必须具有可追溯标识', input.deviceId),
      _boolGate(
        'environment.lowEndArm64',
        '已在最低目标 arm64 实体设备验证',
        input.lowEndArm64DeviceTested,
      ),
      _referenceGate(
        'evidence.rawMetrics',
        '双模型原始指标具有可追溯引用',
        input.rawMetricsRef,
      ),
      _thresholdGate(
        'standard.resourceBytes',
        '标准模型资源不超过 100 MiB',
        input.standardModelResourceBytes,
        (value) => value <= 100 * 1024 * 1024,
      ),
      _thresholdGate(
        'standard.rtfP95',
        '最低目标设备 RTF P95 严格小于 0.5',
        rtfP95,
        (value) => value < 0.5,
      ),
      _thresholdGate(
        'standard.sentenceLatencyP95Ms',
        '句后出字 P95 不超过 3000 ms',
        latencyP95,
        (value) => value <= 3000,
      ),
      _thresholdGate(
        'standard.finalTranscriptionDurationMs',
        '30 分钟最终转录不超过 300000 ms',
        input.finalTranscriptionDurationMs,
        (value) => value <= 300000,
      ),
      _thresholdGate(
        'standard.recordingCompletenessRatio',
        '30 分钟录音完整率为 100%',
        input.recordingCompletenessRatio,
        (value) => value >= 1,
      ),
      _inverseBoolGate(
        'standard.thermal',
        '30 分钟内不持续进入 Severe/Critical',
        input.sustainedSevereOrCriticalThermal,
      ),
      _thresholdGate(
        'standard.relativeEnergy',
        '标准模型能耗不高于高级模型的 70%',
        relativeEnergy,
        (value) => value <= 0.7,
      ),
      _thresholdGate(
        'standard.keyFactRecallRatio',
        '20 段评测关键事实召回率不低于 85%',
        input.keyFactRecallRatio,
        (value) => value >= 0.85,
      ),
      _thresholdGate(
        'advanced.rtfSampleCount',
        '高级模型使用相同语料记录不少于 20 个 RTF 样本',
        _sampleCount(input.advancedRtfSamples),
        (value) => value >= 20,
      ),
      _thresholdGate(
        'advanced.sentenceLatencySampleCount',
        '高级模型使用相同语料记录不少于 20 个句后延迟样本',
        _sampleCount(input.advancedSentenceLatencyMs),
        (value) => value >= 20,
      ),
      _thresholdGate(
        'advanced.finalTranscriptionDurationMs',
        '高级模型记录 30 分钟最终转录耗时供支持分级',
        input.advancedFinalTranscriptionDurationMs,
        (value) => value >= 0,
      ),
      _thresholdGate(
        'acceptance.AT01-AT16',
        'AT-01 至 AT-16 均有非空证据引用',
        acceptanceCount,
        (value) => value == 16,
      ),
      _boolGate(
        'release.apkAudit',
        'APK 的 ABI、模型、密钥、许可和体积审计通过',
        input.apkAuditPassed,
      ),
      _boolGate(
        'license.paraformer',
        'Paraformer 转换权重再分发许可已确认',
        input.paraformerRedistributionConfirmed,
      ),
    ];
    final hasFailure = gates.any(
      (gate) => gate.status == ReleaseGateStatus.failed,
    );
    final hasMissing = gates.any(
      (gate) => gate.status == ReleaseGateStatus.missing,
    );
    return AlphaReleaseEvaluationReport(
      decision: hasFailure
          ? AlphaReleaseDecision.noGo
          : hasMissing
          ? AlphaReleaseDecision.blocked
          : AlphaReleaseDecision.go,
      corpusId: input.corpusId,
      deviceId: input.deviceId,
      rawMetricsRef: input.rawMetricsRef,
      comparison: {
        'standardModel': {
          'rtfP50': _percentile(
            input.standardRtfSamples,
            percentile: 0.5,
            minimumSamples: 20,
          ),
          'rtfP95': rtfP95,
          'sentenceLatencyP50Ms': _percentile(
            input.standardSentenceLatencyMs,
            percentile: 0.5,
            minimumSamples: 20,
          ),
          'sentenceLatencyP95Ms': latencyP95,
          'finalTranscriptionDurationMs': input.finalTranscriptionDurationMs,
        },
        'advancedModel': {
          'rtfP50': _percentile(
            input.advancedRtfSamples,
            percentile: 0.5,
            minimumSamples: 20,
          ),
          'rtfP95': advancedRtfP95,
          'sentenceLatencyP50Ms': _percentile(
            input.advancedSentenceLatencyMs,
            percentile: 0.5,
            minimumSamples: 20,
          ),
          'sentenceLatencyP95Ms': advancedLatencyP95,
          'finalTranscriptionDurationMs':
              input.advancedFinalTranscriptionDurationMs,
        },
        'standardToAdvancedEnergyRatio': relativeEnergy,
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
  final containsAudioPath =
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
        : containsAudioPath
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

double? _p95(List<double>? samples, {required int minimumSamples}) {
  return _percentile(samples, percentile: 0.95, minimumSamples: minimumSamples);
}

double? _percentile(
  List<double>? samples, {
  required double percentile,
  required int minimumSamples,
}) {
  if (samples == null || samples.length < minimumSamples) {
    return null;
  }
  if (samples.any((sample) => !sample.isFinite || sample < 0)) {
    return null;
  }
  final sorted = [...samples]..sort();
  final rank = math.max(1, (sorted.length * percentile).ceil());
  return sorted[rank - 1];
}

int? _sampleCount(List<double>? samples) {
  if (samples == null ||
      samples.any((sample) => !sample.isFinite || sample < 0)) {
    return null;
  }
  return samples.length;
}

double? _ratio(double? numerator, double? denominator) {
  if (numerator == null ||
      denominator == null ||
      !numerator.isFinite ||
      !denominator.isFinite ||
      numerator < 0 ||
      denominator <= 0) {
    return null;
  }
  return numerator / denominator;
}

int? _acceptanceEvidenceCount(Map<String, String>? evidence) {
  if (evidence == null) {
    return null;
  }
  return [
    for (var index = 1; index <= 16; index++)
      'AT-${index.toString().padLeft(2, '0')}',
  ].where((id) => evidence[id]?.trim().isNotEmpty == true).length;
}

Map<String, Object?>? _map(Object? value) =>
    value is Map<String, Object?> ? value : null;

String? _string(Object? value) => value is String ? value : null;

bool? _boolean(Object? value) => value is bool ? value : null;

int? _integer(Object? value) => value is int ? value : null;

double? _number(Object? value) => value is num ? value.toDouble() : null;

List<double>? _numbers(Object? value) {
  if (value is! List<Object?>) {
    return null;
  }
  final numbers = value.whereType<num>().map((number) => number.toDouble());
  if (numbers.length != value.length) {
    return null;
  }
  return List.unmodifiable(numbers);
}

Map<String, String>? _strings(Object? value) {
  if (value is! Map<String, Object?>) {
    return null;
  }
  if (value.values.any((item) => item is! String)) {
    return null;
  }
  return Map.unmodifiable(
    value.map((key, item) => MapEntry(key, item! as String)),
  );
}
