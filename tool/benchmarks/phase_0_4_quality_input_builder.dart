import 'dart:convert';

import 'package:meettrace/domain/use_cases/evaluate_alpha_release.dart';

import 'whisper_quality_protocol.dart';

const whisperBaseQualityModelId = 'whisper-cpp-base-q5_1-v1.9.1';
const whisperSmallQualityModelId = 'whisper-cpp-small-q5_1-v1.9.1';
const whisperBaselineProfileId = 'baseline-fixed-greedy-v1';
const whisperPreviewProfileId = 'preview-greedy-low-latency-v1';
const whisperFinalProfileId = 'final-beam-quality-v1';

final class Phase04QualityInputBuilder {
  const Phase04QualityInputBuilder();

  Map<String, Object?> promotableEvidence(Map<String, Object?> qualityReport) {
    final provenance = qualityReport['corpusProvenance'];
    final execution = qualityReport['execution'];
    final summaries = qualityReport['summaries'];
    final projected = <String, Object?>{
      for (final key in _promotableTopLevelKeys) key: qualityReport[key],
      'corpusProvenance': provenance is Map<String, Object?>
          ? {for (final key in _promotableProvenanceKeys) key: provenance[key]}
          : provenance,
      'execution': execution is Map<String, Object?>
          ? {for (final key in _promotableExecutionKeys) key: execution[key]}
          : execution,
      'summaries': summaries is List<Object?>
          ? [
              for (final summary in summaries)
                if (summary is Map<String, Object?>)
                  {for (final key in _promotableSummaryKeys) key: summary[key]}
                else
                  summary,
            ]
          : summaries,
    };
    _validatePromotableEvidence(projected);
    return jsonDecode(jsonEncode(projected)) as Map<String, Object?>;
  }

  Map<String, Object?> build({
    required Map<String, Object?> template,
    required Map<String, Object?> qualityReport,
    required String rawMetricsRef,
    required String rawMetricsSha256,
  }) {
    final projectedEvidence = promotableEvidence(qualityReport);
    _require(
      _jsonDeepEquals(qualityReport, projectedEvidence),
      '质量证据必须只包含可推广的聚合白名单字段',
    );
    _validatePromotableEvidence(qualityReport);
    _require(
      qualityReport['schemaVersion'] == whisperQualityMetricsSchemaVersion,
      '质量报告 schemaVersion 必须为 4',
    );
    _require(qualityReport['status'] == 'passed', '质量报告必须为 status=passed');
    _require(
      qualityReport['corpusEvidenceClass'] ==
          whisperProductMeetingEvidenceClass,
      '正式质量报告必须使用 product-meeting 证据',
    );
    _require(
      qualityReport['corpusDeidentified'] == true,
      '正式质量报告必须声明 corpusDeidentified=true',
    );
    _require(
      RegExp(r'^[0-9a-f]{64}$').hasMatch(rawMetricsSha256),
      '质量报告 SHA-256 无效',
    );
    _requireSafeRelativeRef(rawMetricsRef);
    final capturedAtUtc = _text(qualityReport, 'capturedAtUtc');
    _require(
      DateTime.tryParse(capturedAtUtc)?.isUtc == true,
      '质量报告 capturedAtUtc 必须是 UTC 时间',
    );

    final sampleCount = _integer(qualityReport, 'sampleCount');
    final provenance = _map(qualityReport, 'corpusProvenance');
    _sha256(provenance, 'reviewAttestationSha256');
    final reviewedAtUtc = _text(provenance, 'reviewedAtUtc');
    _require(
      reviewedAtUtc.endsWith('Z') &&
          DateTime.tryParse(reviewedAtUtc)?.isUtc == true,
      '正式质量报告必须绑定人工复核 UTC 时间',
    );
    final execution = _map(qualityReport, 'execution');
    _require(
      execution['platform'] == 'android-emulator',
      '阶段 0～4 质量报告必须来自 Android 模拟器',
    );
    final deviceId = _text(execution, 'deviceId');
    final declaredPipelines = _stringSet(execution, 'pipelineIds');
    final expectedPipelines = {
      whisperFixedWindowPipelineId,
      whisperVadSegmentedPipelineId,
      whisperVadRecallCandidatePipelineId,
    };
    _require(
      declaredPipelines.length == expectedPipelines.length &&
          declaredPipelines.containsAll(expectedPipelines),
      '质量报告必须声明固定窗口、生产 VAD 和召回候选 VAD',
    );

    final summaries = _summaryIndex(
      qualityReport['summaries'],
      deviceId: deviceId,
      sampleCount: sampleCount,
    );
    const modelIds = {whisperBaseQualityModelId, whisperSmallQualityModelId};
    const profileIds = {
      whisperBaselineProfileId,
      whisperPreviewProfileId,
      whisperFinalProfileId,
    };
    final requiredKeys = {
      for (final modelId in modelIds)
        for (final profileId in profileIds)
          for (final pipelineId in expectedPipelines)
            _summaryKey(modelId, profileId, pipelineId),
    };
    final matrixCompleted =
        summaries.length == requiredKeys.length &&
        summaries.keys.toSet().containsAll(requiredKeys);

    Map<String, Object?>? summary(
      String modelId,
      String profileId,
      String pipelineId,
    ) => summaries[_summaryKey(modelId, profileId, pipelineId)];

    final standardFixed = summary(
      whisperBaseQualityModelId,
      whisperFinalProfileId,
      whisperFixedWindowPipelineId,
    );
    final standardVad = summary(
      whisperBaseQualityModelId,
      whisperFinalProfileId,
      whisperVadSegmentedPipelineId,
    );
    final advancedFixed = summary(
      whisperSmallQualityModelId,
      whisperFinalProfileId,
      whisperFixedWindowPipelineId,
    );
    final advancedVad = summary(
      whisperSmallQualityModelId,
      whisperFinalProfileId,
      whisperVadSegmentedPipelineId,
    );
    final previewVad = summary(
      whisperBaseQualityModelId,
      whisperPreviewProfileId,
      whisperVadSegmentedPipelineId,
    );

    final input = jsonDecode(jsonEncode(template)) as Map<String, Object?>;
    input['evaluationScope'] = AlphaReleaseEvaluationScope.phase0To4.jsonValue;
    input['schemaVersion'] = alphaReleaseInputSchemaVersion;
    input['rawMetricsRef'] = rawMetricsRef;
    input['rawMetricsSha256'] = rawMetricsSha256;

    final corpus = _mutableMap(input, 'corpus');
    corpus
      ..['id'] = _text(qualityReport, 'corpusId')
      ..['sampleCount'] = sampleCount
      ..['deidentified'] = true
      ..['evidenceClass'] = whisperProductMeetingEvidenceClass
      ..['manifestSha256'] = _sha256(qualityReport, 'corpusManifestSha256');
    final targetProvenance = _mutableMap(corpus, 'provenance');
    targetProvenance
      ..['sourceId'] = _text(provenance, 'sourceId')
      ..['licenseId'] = _text(provenance, 'licenseId')
      ..['reviewAttestationSha256'] = _sha256(
        provenance,
        'reviewAttestationSha256',
      )
      ..['reviewedAtUtc'] = reviewedAtUtc;

    final environment = _mutableMap(input, 'environment');
    environment
      ..['deviceId'] = deviceId
      ..['sameCorpusForBothModels'] = true
      ..['sameDeviceForBothModels'] = true;

    final standard = _mutableMap(input, 'standardModel');
    standard
      ..['rtfSamples'] = _numberListOrNull(standardVad, 'rtfSamples')
      ..['sentenceLatencyMs'] = _numberListOrNull(
        standardVad,
        'sentenceLatencyMs',
      )
      ..['keyFactRecallRatio'] = _numberOrNull(
        standardVad,
        'keyFactRecallRatio',
      );

    final advanced = _mutableMap(input, 'advancedModel');
    advanced
      ..['rtfSamples'] = _numberListOrNull(advancedVad, 'rtfSamples')
      ..['sentenceLatencyMs'] = _numberListOrNull(
        advancedVad,
        'sentenceLatencyMs',
      );

    final vad = _mutableMap(input, 'vad');
    vad
      ..['silenceSampleCount'] = _integerOrNull(
        standardVad,
        'silenceSampleCount',
      )
      ..['silenceFalsePositiveCount'] = _integerOrNull(
        standardVad,
        'silenceFalsePositiveCount',
      )
      ..['noiseSampleCount'] = _integerOrNull(standardVad, 'noiseSampleCount')
      ..['baselineNoiseHallucinationCount'] = _integerOrNull(
        standardFixed,
        'noiseHallucinationCount',
      )
      ..['vadNoiseHallucinationCount'] = _integerOrNull(
        standardVad,
        'noiseHallucinationCount',
      );

    final quality = _mutableMap(input, 'quality');
    quality
      ..['fixedWindowBothModelsCompleted'] =
          standardFixed != null && advancedFixed != null
      ..['profilePipelineMatrixCompleted'] = matrixCompleted
      ..['previewSentenceLatencyMs'] = _numberListOrNull(
        previewVad,
        'sentenceLatencyMs',
      )
      ..['standardFixedWindowKeyFactRecallRatio'] = _numberOrNull(
        standardFixed,
        'keyFactRecallRatio',
      )
      ..['standardVadKeyFactRecallRatio'] = _numberOrNull(
        standardVad,
        'keyFactRecallRatio',
      )
      ..['advancedVadKeyFactRecallRatio'] = _numberOrNull(
        advancedVad,
        'keyFactRecallRatio',
      )
      ..['speechBoundaryKeyFactRecallRatio'] = _numberOrNull(
        standardVad,
        'speechBoundaryKeyFactRecallRatio',
      );
    return input;
  }
}

Map<String, Map<String, Object?>> _summaryIndex(
  Object? raw, {
  required String deviceId,
  required int sampleCount,
}) {
  if (raw is! List<Object?>) {
    throw const FormatException('质量报告 summaries 必须是数组');
  }
  final result = <String, Map<String, Object?>>{};
  List<int>? expectedCoverage;
  for (var index = 0; index < raw.length; index++) {
    final summary = raw[index];
    if (summary is! Map<String, Object?>) {
      throw FormatException('summaries[$index] 必须是对象');
    }
    _require(
      summary['deviceId'] == deviceId && summary['sampleCount'] == sampleCount,
      'summaries[$index] 必须使用同一设备并完整覆盖语料',
    );
    final coverage = [
      _integer(summary, 'silenceSampleCount'),
      _integer(summary, 'noiseSampleCount'),
      _integer(summary, 'keyFactSampleCount'),
      _integer(summary, 'speechBoundaryStartSampleCount'),
      _integer(summary, 'speechBoundaryEndSampleCount'),
    ];
    _require(
      coverage[0] >= 20 &&
          coverage[1] >= 20 &&
          coverage[2] >= 20 &&
          coverage[3] >= 1 &&
          coverage[4] >= 1,
      'summaries[$index] 未覆盖正式产品会议的静音、纯噪声、关键事实或语音首尾门槛',
    );
    expectedCoverage ??= coverage;
    _require(
      _listEquals(expectedCoverage, coverage),
      'summaries[$index] 的产品会议分类计数与同轮其他矩阵项不一致',
    );
    final key = _summaryKey(
      _text(summary, 'modelId'),
      _text(summary, 'profileId'),
      _text(summary, 'pipelineId'),
    );
    _require(!result.containsKey(key), '质量报告存在重复矩阵项：$key');
    result[key] = summary;
  }
  return result;
}

String _summaryKey(String modelId, String profileId, String pipelineId) =>
    '$modelId\u0000$profileId\u0000$pipelineId';

Map<String, Object?> _mutableMap(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  final created = <String, Object?>{};
  parent[key] = created;
  return created;
}

Map<String, Object?> _map(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('$key 必须是对象');
  }
  return value;
}

String _text(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串');
  }
  return value.trim();
}

String _sha256(Map<String, Object?> parent, String key) {
  final value = _text(parent, key).toLowerCase();
  _require(RegExp(r'^[0-9a-f]{64}$').hasMatch(value), '$key 必须是 SHA-256');
  return value;
}

int _integer(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is! int || value < 0) {
    throw FormatException('$key 必须是非负整数');
  }
  return value;
}

int? _integerOrNull(Map<String, Object?>? parent, String key) =>
    parent == null ? null : _integer(parent, key);

double? _numberOrNull(Map<String, Object?>? parent, String key) {
  if (parent == null || parent[key] == null) {
    return null;
  }
  final value = parent[key];
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('$key 必须是非负有限数值或 null');
  }
  return value.toDouble();
}

List<double>? _numberListOrNull(Map<String, Object?>? parent, String key) {
  if (parent == null || parent[key] == null) {
    return null;
  }
  final value = parent[key];
  if (value is! List<Object?> ||
      value.any((item) => item is! num || !item.isFinite || item < 0)) {
    throw FormatException('$key 必须是非负有限数值数组或 null');
  }
  return value.cast<num>().map((item) => item.toDouble()).toList();
}

Set<String> _stringSet(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is! List<Object?> ||
      value.any((item) => item is! String || item.trim().isEmpty)) {
    throw FormatException('$key 必须是非空字符串数组');
  }
  final values = value.cast<String>().map((item) => item.trim()).toSet();
  _require(values.length == value.length, '$key 不得重复');
  return values;
}

void _requireSafeRelativeRef(String value) {
  final normalized = value.replaceAll('\\', '/');
  final uri = Uri.tryParse(normalized);
  _require(
    normalized.isNotEmpty &&
        !normalized.startsWith('/') &&
        !RegExp(r'^[a-zA-Z]:/').hasMatch(normalized) &&
        uri != null &&
        !uri.hasScheme &&
        !normalized.split('/').contains('..') &&
        !RegExp(
          r'\.(wav|pcm|m4a|aac|mp3|ogg|flac)$',
          caseSensitive: false,
        ).hasMatch(normalized),
    'rawMetricsRef 必须是仓库内非音频相对引用',
  );
}

void _validatePromotableEvidence(Object? value, {String key = r'$'}) {
  if (value is Map<String, Object?>) {
    const forbiddenKeys = {
      'sourcePath',
      'pathEnv',
      'transcript',
      'rawText',
      'observations',
      'samples',
      'privateArtifacts',
    };
    for (final entry in value.entries) {
      _require(
        !forbiddenKeys.contains(entry.key),
        '质量证据不得包含私有字段：$key.${entry.key}',
      );
      _validatePromotableEvidence(entry.value, key: '$key.${entry.key}');
    }
    return;
  }
  if (value is List<Object?>) {
    for (var index = 0; index < value.length; index++) {
      _validatePromotableEvidence(value[index], key: '$key[$index]');
    }
    return;
  }
  if (value is String) {
    final normalized = value.replaceAll('\\', '/');
    _require(
      !normalized.startsWith('/') &&
          !RegExp(r'^[a-zA-Z]:/').hasMatch(normalized) &&
          !RegExp(
            r'\.(wav|pcm|m4a|aac|mp3|ogg|flac)(?:$|[?#])',
            caseSensitive: false,
          ).hasMatch(normalized),
      '质量证据不得包含绝对路径或音频引用：$key',
    );
  }
}

bool _jsonDeepEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is List<Object?> && right is List<Object?>) {
    return _listEquals(left, right, equals: _jsonDeepEquals);
  }
  if (left is Map<String, Object?> && right is Map<String, Object?>) {
    return left.length == right.length &&
        left.keys.every(
          (key) =>
              right.containsKey(key) && _jsonDeepEquals(left[key], right[key]),
        );
  }
  return left == right;
}

bool _listEquals(
  List<Object?> left,
  List<Object?> right, {
  bool Function(Object?, Object?) equals = _jsonDeepEquals,
}) =>
    left.length == right.length &&
    List.generate(
      left.length,
      (index) => equals(left[index], right[index]),
    ).every((value) => value);

void _require(bool condition, String message) {
  if (!condition) {
    throw FormatException(message);
  }
}

const _promotableTopLevelKeys = <String>[
  'schemaVersion',
  'status',
  'capturedAtUtc',
  'corpusId',
  'corpusDeidentified',
  'corpusEvidenceClass',
  'corpusManifestSha256',
  'sampleCount',
];

const _promotableProvenanceKeys = <String>[
  'sourceId',
  'licenseId',
  'reviewAttestationSha256',
  'reviewedAtUtc',
];

const _promotableExecutionKeys = <String>[
  'platform',
  'deviceId',
  'pipelineIds',
];

const _promotableSummaryKeys = <String>[
  'deviceId',
  'modelId',
  'modelVersion',
  'profileId',
  'pipelineId',
  'sampleCount',
  'rtfSamples',
  'sentenceLatencyMs',
  'keyFactRecallRatio',
  'keyFactSampleCount',
  'expectedKeyFactCount',
  'recalledKeyFactCount',
  'speechBoundarySampleCount',
  'speechBoundaryStartSampleCount',
  'speechBoundaryEndSampleCount',
  'expectedSpeechBoundaryKeyFactCount',
  'recalledSpeechBoundaryKeyFactCount',
  'speechBoundaryKeyFactRecallRatio',
  'silenceSampleCount',
  'silenceFalsePositiveCount',
  'noiseSampleCount',
  'noiseHallucinationCount',
];
