import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

final class WhisperQualityMetricsException implements Exception {
  const WhisperQualityMetricsException(this.message);

  final String message;

  @override
  String toString() => 'WhisperQualityMetricsException: $message';
}

final class WhisperQualityMetrics {
  const WhisperQualityMetrics();

  Map<String, Object?> evaluate(Map<String, Object?> input) {
    final corpus = _map(input['corpus'], 'corpus');
    final corpusId = _requiredText(corpus['id'], 'corpus.id');
    if (corpus['deidentified'] != true) {
      throw const WhisperQualityMetricsException(
        'corpus.deidentified 必须为 true',
      );
    }
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
          .where((value) => value.sample.tags.contains('noise'))
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
        'modelId': first.modelId,
        'modelVersion': first.modelVersion,
        'profileId': first.profileId,
        'sampleCount': values.length,
        'rtfSamples': rtfSamples,
        'rtfP50': _percentile(rtfSamples, 0.5),
        'rtfP95': _percentile(rtfSamples, 0.95),
        'sentenceLatencyMs': latencySamples,
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
        'energyWh': values
            .map((value) => value.energyWh)
            .whereType<double>()
            .fold<double>(0, (total, value) => total + value),
        'sustainedSevereOrCriticalThermal': values.any(
          (value) => value.sustainedSevereOrCriticalThermal,
        ),
        'transcriptRefs': values
            .map((value) => value.transcriptRef)
            .whereType<String>()
            .toSet()
            .toList(growable: false),
      });
    }
    summaries.sort(
      (left, right) => '${left['modelId']}:${left['profileId']}'.compareTo(
        '${right['modelId']}:${right['profileId']}',
      ),
    );

    return {
      'schemaVersion': 1,
      'corpusId': corpusId,
      'sampleCount': samples.length,
      'summaries': summaries,
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
  final transcriptRef = _optionalText(item['transcriptRef']);
  if (transcriptRef != null && _looksLikeAudioPath(transcriptRef)) {
    throw WhisperQualityMetricsException(
      'observations[$index].transcriptRef 不得指向音频文件',
    );
  }
  return _Observation(
    sample: sample,
    modelId: _requiredText(item['modelId'], 'observations[$index].modelId'),
    modelVersion: _requiredText(
      item['modelVersion'],
      'observations[$index].modelVersion',
    ),
    profileId: _requiredText(
      item['profileId'],
      'observations[$index].profileId',
    ),
    inferenceDurationMs: _nonNegativeNumber(
      item['inferenceDurationMs'],
      'observations[$index].inferenceDurationMs',
    ),
    sentenceLatencyMs: _optionalNonNegativeNumber(
      item['sentenceLatencyMs'],
      'observations[$index].sentenceLatencyMs',
    ),
    emittedText: item['emittedText'] == true,
    recognizedKeyFacts: _textList(
      item['recognizedKeyFacts'] ?? const <Object?>[],
      'observations[$index].recognizedKeyFacts',
    ),
    peakRssBytes: _optionalNonNegativeInteger(
      item['peakRssBytes'],
      'observations[$index].peakRssBytes',
    ),
    energyWh: _optionalNonNegativeNumber(
      item['energyWh'],
      'observations[$index].energyWh',
    ),
    sustainedSevereOrCriticalThermal:
        item['sustainedSevereOrCriticalThermal'] == true,
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
    required this.modelId,
    required this.modelVersion,
    required this.profileId,
    required this.inferenceDurationMs,
    required this.sentenceLatencyMs,
    required this.emittedText,
    required this.recognizedKeyFacts,
    required this.peakRssBytes,
    required this.energyWh,
    required this.sustainedSevereOrCriticalThermal,
    required this.transcriptRef,
  });

  final _Sample sample;
  final String modelId;
  final String modelVersion;
  final String profileId;
  final double inferenceDurationMs;
  final double? sentenceLatencyMs;
  final bool emittedText;
  final List<String> recognizedKeyFacts;
  final int? peakRssBytes;
  final double? energyWh;
  final bool sustainedSevereOrCriticalThermal;
  final String? transcriptRef;

  String get groupKey => '$modelId\u0000$modelVersion\u0000$profileId';
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

bool _looksLikeAudioPath(String value) => RegExp(
  r'\.(wav|pcm|m4a|aac|mp3|ogg|flac)(?:$|[?#])',
  caseSensitive: false,
).hasMatch(value);

String _toCsv(Map<String, Object?> report) {
  final summaries = report['summaries']! as List<Map<String, Object?>>;
  final rows = <String>[
    'modelId,modelVersion,profileId,sampleCount,rtfP50,rtfP95,'
        'sentenceLatencyP50Ms,sentenceLatencyP95Ms,keyFactRecallRatio,'
        'silenceFalsePositiveCount,noiseHallucinationCount,peakRssBytes,'
        'energyWh,sustainedSevereOrCriticalThermal',
    for (final summary in summaries)
      [
        summary['modelId'],
        summary['modelVersion'],
        summary['profileId'],
        summary['sampleCount'],
        summary['rtfP50'],
        summary['rtfP95'],
        summary['sentenceLatencyP50Ms'],
        summary['sentenceLatencyP95Ms'],
        summary['keyFactRecallRatio'],
        summary['silenceFalsePositiveCount'],
        summary['noiseHallucinationCount'],
        summary['peakRssBytes'],
        summary['energyWh'],
        summary['sustainedSevereOrCriticalThermal'],
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
