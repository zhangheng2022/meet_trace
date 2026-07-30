import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'whisper_quality_protocol.dart';

final class WhisperQualityMetricsException implements Exception {
  const WhisperQualityMetricsException(this.message);

  final String message;

  @override
  String toString() => 'WhisperQualityMetricsException: $message';
}

final class WhisperQualityMetrics {
  const WhisperQualityMetrics();

  Map<String, Object?> evaluate(Map<String, Object?> input) {
    if (input['schemaVersion'] != whisperQualityMetricsSchemaVersion) {
      throw const WhisperQualityMetricsException('input.schemaVersion 必须为 3');
    }
    final corpus = _map(input['corpus'], 'corpus');
    final corpusId = _requiredText(corpus['id'], 'corpus.id');
    if (corpus['deidentified'] != true) {
      throw const WhisperQualityMetricsException(
        'corpus.deidentified 必须为 true',
      );
    }
    final evidenceClass = _evidenceClass(
      corpus['evidenceClass'],
      'corpus.evidenceClass',
    );
    final provenance = _map(corpus['provenance'], 'corpus.provenance');
    final sourceId = _requiredText(
      provenance['sourceId'],
      'corpus.provenance.sourceId',
    );
    final licenseId = _requiredText(
      provenance['licenseId'],
      'corpus.provenance.licenseId',
    );
    final samples = _samples(corpus['samples']);
    if (samples.length < 20) {
      throw const WhisperQualityMetricsException('语料必须至少包含 20 段');
    }
    final observations = _observations(input['observations'], samples);
    final groups = <String, List<_Observation>>{};
    final seenObservations = <String>{};
    for (final observation in observations) {
      final observationKey =
          '${observation.groupKey}\u0000${observation.sample.id}';
      if (!seenObservations.add(observationKey)) {
        throw WhisperQualityMetricsException(
          '同一模型/Profile 存在重复 sample：${observation.sample.id}',
        );
      }
      (groups[observation.groupKey] ??= []).add(observation);
    }
    if (groups.isEmpty) {
      throw const WhisperQualityMetricsException('observations 不能为空');
    }

    final summaries = <Map<String, Object?>>[];
    for (final entry in groups.entries) {
      final values = entry.value;
      final first = values.first;
      final observedSampleIds = values.map((value) => value.sample.id).toSet();
      if (observedSampleIds.length != samples.length ||
          !observedSampleIds.containsAll(samples.keys)) {
        throw WhisperQualityMetricsException(
          '${first.modelId}/${first.profileId} 必须完整覆盖全部 ${samples.length} 段语料',
        );
      }
      final rtfSamples = values
          .map((value) => value.inferenceDurationMs / value.sample.durationMs)
          .toList(growable: false);
      final latencySamples = values
          .map((value) => value.sentenceLatencyMs)
          .whereType<double>()
          .toList(growable: false);
      final silence = values
          .where((value) => value.sample.tags.contains('silence'))
          .toList(growable: false);
      final noise = values
          .where((value) => value.sample.tags.contains('noise-only'))
          .toList(growable: false);
      final expectedFacts = values.fold<int>(
        0,
        (total, value) => total + value.sample.expectedKeyFacts.length,
      );
      final recalledFacts = values.fold<int>(
        0,
        (total, value) =>
            total +
            value.recognizedKeyFacts
                .toSet()
                .intersection(value.sample.expectedKeyFacts.toSet())
                .length,
      );
      summaries.add({
        'deviceId': first.deviceId,
        'modelId': first.modelId,
        'modelVersion': first.modelVersion,
        'profileId': first.profileId,
        'pipelineId': first.pipelineId,
        'sampleCount': values.length,
        'rtfSamples': rtfSamples,
        'rtfP50': _percentile(rtfSamples, 0.5),
        'rtfP95': _percentile(rtfSamples, 0.95),
        'sentenceLatencyMs': latencySamples,
        'sentenceLatencySampleCount': latencySamples.length,
        'sentenceLatencyP50Ms': _percentile(latencySamples, 0.5),
        'sentenceLatencyP95Ms': _percentile(latencySamples, 0.95),
        'keyFactRecallRatio': expectedFacts == 0
            ? null
            : recalledFacts / expectedFacts,
        'emptyTextRatio':
            values.where((value) => !value.emittedText).length / values.length,
        'silenceSampleCount': silence.length,
        'silenceFalsePositiveCount': silence
            .where((value) => value.emittedText)
            .length,
        'noiseSampleCount': noise.length,
        'noiseHallucinationCount': noise
            .where((value) => value.emittedText)
            .length,
        'peakRssBytes': values
            .map((value) => value.peakRssBytes)
            .whereType<int>()
            .fold<int?>(null, (peak, value) => math.max(peak ?? 0, value)),
        'peakRssSampleCount': values
            .where((value) => value.peakRssBytes != null)
            .length,
        'energyWh': values.every((value) => value.energyWh != null)
            ? values.fold<double>(0, (total, value) => total + value.energyWh!)
            : null,
        'energySampleCount': values
            .where((value) => value.energyWh != null)
            .length,
        'energyEvidenceRefs': values
            .map((value) => value.energyEvidenceRef)
            .whereType<String>()
            .toSet()
            .toList(growable: false),
        'sustainedSevereOrCriticalThermal':
            values.every(
              (value) => value.sustainedSevereOrCriticalThermal != null,
            )
            ? values.any((value) => value.sustainedSevereOrCriticalThermal!)
            : null,
        'thermalSampleCount': values
            .where((value) => value.sustainedSevereOrCriticalThermal != null)
            .length,
        'thermalEvidenceRefs': values
            .map((value) => value.thermalEvidenceRef)
            .whereType<String>()
            .toSet()
            .toList(growable: false),
        'transcriptRefs': values
            .map((value) => value.transcriptRef)
            .whereType<String>()
            .toSet()
            .toList(growable: false),
      });
    }
    summaries.sort(
      (left, right) =>
          '${left['deviceId']}:${left['modelId']}:${left['profileId']}:'
                  '${left['pipelineId']}'
              .compareTo(
                '${right['deviceId']}:${right['modelId']}:'
                '${right['profileId']}:${right['pipelineId']}',
              ),
    );

    return {
      'schemaVersion': whisperQualityMetricsSchemaVersion,
      'corpusId': corpusId,
      'corpusEvidenceClass': evidenceClass,
      'corpusProvenance': {'sourceId': sourceId, 'licenseId': licenseId},
      'sampleCount': samples.length,
      'summaries': summaries,
      'pipelineComparisons': _pipelineComparisons(summaries),
    };
  }
}

Future<void> main(List<String> arguments) async {
  final options = _parseArguments(arguments);
  final inputFile = File(options.input);
  if (!await inputFile.exists()) {
    throw WhisperQualityMetricsException('输入文件不存在：${options.input}');
  }
  final decoded = jsonDecode(await inputFile.readAsString());
  if (decoded is! Map<String, Object?>) {
    throw const WhisperQualityMetricsException('输入 JSON 顶层必须是对象');
  }
  final report = const WhisperQualityMetrics().evaluate(decoded);
  final outputJson = File(options.outputJson);
  await outputJson.parent.create(recursive: true);
  await outputJson.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
    flush: true,
  );
  final outputCsv = File(options.outputCsv);
  await outputCsv.parent.create(recursive: true);
  await outputCsv.writeAsString(_toCsv(report), flush: true);
}

final class _Options {
  const _Options({
    required this.input,
    required this.outputJson,
    required this.outputCsv,
  });

  final String input;
  final String outputJson;
  final String outputCsv;
}

_Options _parseArguments(List<String> arguments) {
  String? valueOf(String name) {
    final index = arguments.indexOf(name);
    if (index < 0 || index + 1 >= arguments.length) {
      return null;
    }
    return arguments[index + 1];
  }

  final input = valueOf('--input');
  final outputJson = valueOf('--output-json');
  final outputCsv = valueOf('--output-csv');
  if (input == null || outputJson == null || outputCsv == null) {
    throw const WhisperQualityMetricsException(
      '用法：--input <json> --output-json <json> --output-csv <csv>',
    );
  }
  return _Options(input: input, outputJson: outputJson, outputCsv: outputCsv);
}

Map<String, _Sample> _samples(Object? value) {
  if (value is! List<Object?>) {
    throw const WhisperQualityMetricsException('corpus.samples 必须是数组');
  }
  final result = <String, _Sample>{};
  for (var index = 0; index < value.length; index++) {
    final item = _map(value[index], 'corpus.samples[$index]');
    final sample = _Sample(
      id: _requiredText(item['id'], 'corpus.samples[$index].id'),
      durationMs: _positiveNumber(
        item['durationMs'],
        'corpus.samples[$index].durationMs',
      ),
      tags: _textList(item['tags'], 'corpus.samples[$index].tags').toSet(),
      expectedKeyFacts: _textList(
        item['expectedKeyFacts'] ?? const <Object?>[],
        'corpus.samples[$index].expectedKeyFacts',
      ),
    );
    if (result.containsKey(sample.id)) {
      throw WhisperQualityMetricsException('重复 corpus sample ID：${sample.id}');
    }
    result[sample.id] = sample;
  }
  return result;
}

List<_Observation> _observations(Object? value, Map<String, _Sample> samples) {
  if (value is! List<Object?>) {
    throw const WhisperQualityMetricsException('observations 必须是数组');
  }
  return [
    for (var index = 0; index < value.length; index++)
      _observation(_map(value[index], 'observations[$index]'), samples, index),
  ];
}

_Observation _observation(
  Map<String, Object?> item,
  Map<String, _Sample> samples,
  int index,
) {
  final sampleId = _requiredText(
    item['sampleId'],
    'observations[$index].sampleId',
  );
  final sample = samples[sampleId];
  if (sample == null) {
    throw WhisperQualityMetricsException(
      'observations[$index] 引用了未知 sampleId：$sampleId',
    );
  }
  final transcriptRef = _requiredText(
    item['transcriptRef'],
    'observations[$index].transcriptRef',
  );
  if (_looksLikeAudioPath(transcriptRef)) {
    throw WhisperQualityMetricsException(
      'observations[$index].transcriptRef 不得指向音频文件',
    );
  }
  _requireSafeRelativeRef(transcriptRef, 'observations[$index].transcriptRef');
  final energyWh = _optionalNonNegativeNumber(
    item['energyWh'],
    'observations[$index].energyWh',
  );
  final energyEvidenceRef = _optionalEvidenceRef(
    item['energyEvidenceRef'],
    'observations[$index].energyEvidenceRef',
  );
  if ((energyWh == null) != (energyEvidenceRef == null)) {
    throw WhisperQualityMetricsException(
      'observations[$index] 的 energyWh 与 energyEvidenceRef 必须同时提供',
    );
  }
  final thermal = _optionalBoolean(
    item['sustainedSevereOrCriticalThermal'],
    'observations[$index].sustainedSevereOrCriticalThermal',
  );
  final thermalEvidenceRef = _optionalEvidenceRef(
    item['thermalEvidenceRef'],
    'observations[$index].thermalEvidenceRef',
  );
  if ((thermal == null) != (thermalEvidenceRef == null)) {
    throw WhisperQualityMetricsException(
      'observations[$index] 的温控结论与 thermalEvidenceRef 必须同时提供',
    );
  }
  return _Observation(
    sample: sample,
    deviceId: _requiredText(item['deviceId'], 'observations[$index].deviceId'),
    modelId: _requiredText(item['modelId'], 'observations[$index].modelId'),
    modelVersion: _requiredText(
      item['modelVersion'],
      'observations[$index].modelVersion',
    ),
    profileId: _requiredText(
      item['profileId'],
      'observations[$index].profileId',
    ),
    pipelineId: _pipelineId(
      item['pipelineId'],
      'observations[$index].pipelineId',
    ),
    inferenceDurationMs: _nonNegativeNumber(
      item['inferenceDurationMs'],
      'observations[$index].inferenceDurationMs',
    ),
    sentenceLatencyMs: _optionalNonNegativeNumber(
      item['sentenceLatencyMs'],
      'observations[$index].sentenceLatencyMs',
    ),
    emittedText: _requiredBoolean(
      item['emittedText'],
      'observations[$index].emittedText',
    ),
    recognizedKeyFacts: _textList(
      item['recognizedKeyFacts'] ?? const <Object?>[],
      'observations[$index].recognizedKeyFacts',
    ),
    peakRssBytes: _optionalNonNegativeInteger(
      item['peakRssBytes'],
      'observations[$index].peakRssBytes',
    ),
    energyWh: energyWh,
    energyEvidenceRef: energyEvidenceRef,
    sustainedSevereOrCriticalThermal: thermal,
    thermalEvidenceRef: thermalEvidenceRef,
    transcriptRef: transcriptRef,
  );
}

final class _Sample {
  const _Sample({
    required this.id,
    required this.durationMs,
    required this.tags,
    required this.expectedKeyFacts,
  });

  final String id;
  final double durationMs;
  final Set<String> tags;
  final List<String> expectedKeyFacts;
}

final class _Observation {
  const _Observation({
    required this.sample,
    required this.deviceId,
    required this.modelId,
    required this.modelVersion,
    required this.profileId,
    required this.pipelineId,
    required this.inferenceDurationMs,
    required this.sentenceLatencyMs,
    required this.emittedText,
    required this.recognizedKeyFacts,
    required this.peakRssBytes,
    required this.energyWh,
    required this.energyEvidenceRef,
    required this.sustainedSevereOrCriticalThermal,
    required this.thermalEvidenceRef,
    required this.transcriptRef,
  });

  final _Sample sample;
  final String deviceId;
  final String modelId;
  final String modelVersion;
  final String profileId;
  final String pipelineId;
  final double inferenceDurationMs;
  final double? sentenceLatencyMs;
  final bool emittedText;
  final List<String> recognizedKeyFacts;
  final int? peakRssBytes;
  final double? energyWh;
  final String? energyEvidenceRef;
  final bool? sustainedSevereOrCriticalThermal;
  final String? thermalEvidenceRef;
  final String? transcriptRef;

  String get groupKey =>
      '$deviceId\u0000$modelId\u0000$modelVersion\u0000$profileId'
      '\u0000$pipelineId';
}

List<Map<String, Object?>> _pipelineComparisons(
  List<Map<String, Object?>> summaries,
) {
  final comparisons = <Map<String, Object?>>[];
  for (final baseline in summaries.where(
    (summary) => summary['pipelineId'] == whisperFixedWindowPipelineId,
  )) {
    final candidates = summaries.where(
      (candidate) =>
          candidate['pipelineId'] == whisperVadSegmentedPipelineId &&
          candidate['deviceId'] == baseline['deviceId'] &&
          candidate['modelId'] == baseline['modelId'] &&
          candidate['modelVersion'] == baseline['modelVersion'] &&
          candidate['profileId'] == baseline['profileId'],
    );
    if (candidates.isEmpty) {
      continue;
    }
    final candidate = candidates.single;
    final baselineNoise = baseline['noiseHallucinationCount']! as int;
    final candidateNoise = candidate['noiseHallucinationCount']! as int;
    final baselineRecall = baseline['keyFactRecallRatio'] as double?;
    final candidateRecall = candidate['keyFactRecallRatio'] as double?;
    comparisons.add({
      'deviceId': baseline['deviceId'],
      'modelId': baseline['modelId'],
      'modelVersion': baseline['modelVersion'],
      'profileId': baseline['profileId'],
      'baselinePipelineId': whisperFixedWindowPipelineId,
      'candidatePipelineId': whisperVadSegmentedPipelineId,
      'noiseSampleCount': baseline['noiseSampleCount'],
      'baselineNoiseHallucinationCount': baselineNoise,
      'candidateNoiseHallucinationCount': candidateNoise,
      'noiseHallucinationReductionRatio': baselineNoise == 0
          ? null
          : (baselineNoise - candidateNoise) / baselineNoise,
      'baselineKeyFactRecallRatio': baselineRecall,
      'candidateKeyFactRecallRatio': candidateRecall,
      'keyFactRecallDelta': baselineRecall == null || candidateRecall == null
          ? null
          : candidateRecall - baselineRecall,
    });
  }
  return comparisons;
}

double? _percentile(List<double> values, double percentile) {
  if (values.isEmpty) {
    return null;
  }
  final sorted = values.toList()..sort();
  final rank = (percentile * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw WhisperQualityMetricsException('$name 必须是对象');
  }
  return value;
}

String _requiredText(Object? value, String name) {
  final text = _optionalText(value);
  if (text == null) {
    throw WhisperQualityMetricsException('$name 不能为空');
  }
  return text;
}

String _pipelineId(Object? value, String name) {
  final pipelineId = _requiredText(value, name);
  if (pipelineId != whisperFixedWindowPipelineId &&
      pipelineId != whisperVadSegmentedPipelineId) {
    throw WhisperQualityMetricsException(
      '$name 必须为 $whisperFixedWindowPipelineId 或 '
      '$whisperVadSegmentedPipelineId',
    );
  }
  return pipelineId;
}

String _evidenceClass(Object? value, String name) {
  final evidenceClass = _requiredText(value, name);
  if (!whisperQualityEvidenceClasses.contains(evidenceClass)) {
    throw WhisperQualityMetricsException(
      '$name 必须为 ${whisperQualityEvidenceClasses.join('、')}',
    );
  }
  return evidenceClass;
}

String? _optionalText(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

List<String> _textList(Object? value, String name) {
  if (value is! List<Object?> ||
      value.any((item) => item is! String || item.trim().isEmpty)) {
    throw WhisperQualityMetricsException('$name 必须是非空字符串数组');
  }
  return value
      .cast<String>()
      .map((item) => item.trim())
      .toList(growable: false);
}

double _positiveNumber(Object? value, String name) {
  final number = _nonNegativeNumber(value, name);
  if (number == 0) {
    throw WhisperQualityMetricsException('$name 必须大于 0');
  }
  return number;
}

double _nonNegativeNumber(Object? value, String name) {
  if (value is! num || !value.isFinite || value < 0) {
    throw WhisperQualityMetricsException('$name 必须是非负有限数值');
  }
  return value.toDouble();
}

double? _optionalNonNegativeNumber(Object? value, String name) {
  if (value == null) {
    return null;
  }
  return _nonNegativeNumber(value, name);
}

int? _optionalNonNegativeInteger(Object? value, String name) {
  if (value == null) {
    return null;
  }
  if (value is! int || value < 0) {
    throw WhisperQualityMetricsException('$name 必须是非负整数');
  }
  return value;
}

bool? _optionalBoolean(Object? value, String name) {
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    throw WhisperQualityMetricsException('$name 必须是布尔值或 null');
  }
  return value;
}

bool _requiredBoolean(Object? value, String name) {
  final result = _optionalBoolean(value, name);
  if (result == null) {
    throw WhisperQualityMetricsException('$name 必须是布尔值');
  }
  return result;
}

String? _optionalEvidenceRef(Object? value, String name) {
  final text = _optionalText(value);
  if (value != null && text == null) {
    throw WhisperQualityMetricsException('$name 必须是非空字符串或 null');
  }
  if (text != null && _looksLikeAudioPath(text)) {
    throw WhisperQualityMetricsException('$name 不得指向音频文件');
  }
  if (text != null) {
    _requireSafeRelativeRef(text, name);
  }
  return text;
}

void _requireSafeRelativeRef(String value, String name) {
  final normalized = value.replaceAll('\\', '/');
  final uri = Uri.tryParse(normalized);
  if (normalized.startsWith('/') ||
      RegExp(r'^[a-zA-Z]:/').hasMatch(normalized) ||
      uri == null ||
      uri.hasScheme ||
      normalized.split('/').contains('..')) {
    throw WhisperQualityMetricsException('$name 必须是输出目录内的安全相对引用');
  }
}

bool _looksLikeAudioPath(String value) => RegExp(
  r'\.(wav|pcm|m4a|aac|mp3|ogg|flac)(?:$|[?#])',
  caseSensitive: false,
).hasMatch(value);

String _toCsv(Map<String, Object?> report) {
  final summaries = report['summaries']! as List<Map<String, Object?>>;
  final rows = <String>[
    'deviceId,modelId,modelVersion,profileId,pipelineId,sampleCount,'
        'rtfP50,rtfP95,'
        'sentenceLatencySampleCount,sentenceLatencyP50Ms,'
        'sentenceLatencyP95Ms,keyFactRecallRatio,'
        'silenceFalsePositiveCount,noiseHallucinationCount,peakRssBytes,'
        'peakRssSampleCount,energyWh,energySampleCount,'
        'sustainedSevereOrCriticalThermal,thermalSampleCount',
    for (final summary in summaries)
      [
        summary['deviceId'],
        summary['modelId'],
        summary['modelVersion'],
        summary['profileId'],
        summary['pipelineId'],
        summary['sampleCount'],
        summary['rtfP50'],
        summary['rtfP95'],
        summary['sentenceLatencySampleCount'],
        summary['sentenceLatencyP50Ms'],
        summary['sentenceLatencyP95Ms'],
        summary['keyFactRecallRatio'],
        summary['silenceFalsePositiveCount'],
        summary['noiseHallucinationCount'],
        summary['peakRssBytes'],
        summary['peakRssSampleCount'],
        summary['energyWh'],
        summary['energySampleCount'],
        summary['sustainedSevereOrCriticalThermal'],
        summary['thermalSampleCount'],
      ].map(_csvCell).join(','),
  ];
  return '${rows.join('\n')}\n';
}

String _csvCell(Object? value) {
  if (value == null) {
    return '';
  }
  final text = value.toString();
  if (!text.contains(RegExp('[,\\n"]'))) {
    return text;
  }
  return '"${text.replaceAll('"', '""')}"';
}
