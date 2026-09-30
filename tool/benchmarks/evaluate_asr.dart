import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _help = '''用法：dart run tool/benchmarks/evaluate_asr.dart <实测结果.jsonl>
每行一条人工标注语音段：
  id, reference, hypothesis（字符串）；metric 为 cer、wer 或 both，默认 cer。
可选：keyFacts（字符串数组）、firstTextLatencyMs、stableLatencyMs、
  inferenceMs、inputAudioMs（非负实测毫秒；inputAudioMs 必须大于零）。
大小写、标点和空白归一化；CER 按 Unicode 码点，WER 按空格切词。
每行最多 5000 个计分单元；长会议应按人工语音段分行。
缺失时延报告 null 和样本数，不补零；静音行单独报告误出字。
只评分已有 reference/hypothesis，不执行识别，不证明设备准确率达标。
''';

Future<void> main(List<String> arguments) async {
  if (arguments.length == 1 && arguments.single == '--help') {
    stdout.write(_help);
    return;
  }
  if (arguments.length != 1) {
    stderr.write(_help);
    exitCode = 64;
    return;
  }
  try {
    final samples = <Map<String, Object?>>[];
    await for (final line in File(
      arguments.single,
    ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('每行必须是 JSON 对象');
      }
      samples.add(decoded);
    }
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(evaluateAsrSamples(samples)),
    );
  } on FormatException catch (error) {
    stderr.writeln('结果格式无效：${error.message}');
    exitCode = 65;
  } on FileSystemException {
    stderr.writeln('无法读取指定结果文件');
    exitCode = 66;
  }
}

Map<String, Object?> evaluateAsrSamples(
  Iterable<Map<String, Object?>> samples,
) {
  final ids = <String>{};
  final firstLatencies = <double>[];
  final stableLatencies = <double>[];
  var characters = 0;
  var characterErrors = 0;
  var words = 0;
  var wordErrors = 0;
  var facts = 0;
  var recognizedFacts = 0;
  var silentCases = 0;
  var silenceInsertions = 0;
  var pairedInferenceMs = 0.0;
  var pairedInputMs = 0.0;
  var pairedInferenceCases = 0;
  for (final sample in samples) {
    final id = sample['id'];
    final reference = sample['reference'];
    final hypothesis = sample['hypothesis'];
    final metric = sample['metric'] ?? 'cer';
    if (id is! String ||
        id.trim().isEmpty ||
        !ids.add(id) ||
        reference is! String ||
        hypothesis is! String ||
        !const ['cer', 'wer', 'both'].contains(metric)) {
      throw const FormatException('id 必须唯一且非空；reference/hypothesis/metric 无效');
    }
    final normalizedReference = _normalize(reference);
    final normalizedHypothesis = _normalize(hypothesis);
    if (normalizedReference.isEmpty) {
      silentCases++;
      if (normalizedHypothesis.isNotEmpty) silenceInsertions++;
    }
    if (metric != 'wer') {
      final expected = normalizedReference.replaceAll(' ', '').runes.toList();
      final actual = normalizedHypothesis.replaceAll(' ', '').runes.toList();
      characters += expected.length;
      characterErrors += _editDistance(expected, actual);
    }
    if (metric != 'cer') {
      final expected = _words(normalizedReference);
      final actual = _words(normalizedHypothesis);
      words += expected.length;
      wordErrors += _editDistance(expected, actual);
    }
    final keyFacts = sample['keyFacts'];
    if (keyFacts != null) {
      if (keyFacts is! List<Object?> ||
          keyFacts.any((fact) => fact is! String)) {
        throw const FormatException('keyFacts 必须是字符串数组');
      }
      for (final value in keyFacts) {
        final fact = _normalize(value! as String);
        if (fact.isEmpty || !normalizedReference.contains(fact)) {
          throw const FormatException('keyFacts 必须非空且出现在参考文本中');
        }
        facts++;
        if (normalizedHypothesis.contains(fact)) recognizedFacts++;
      }
    }
    final first = _milliseconds(sample, 'firstTextLatencyMs');
    final stable = _milliseconds(sample, 'stableLatencyMs');
    if (first != null) firstLatencies.add(first);
    if (stable != null) stableLatencies.add(stable);
    final inference = _milliseconds(sample, 'inferenceMs');
    final input = _milliseconds(sample, 'inputAudioMs');
    if (input != null && input <= 0) {
      throw const FormatException('inputAudioMs 必须大于零');
    }
    if (input != null && inference != null) {
      pairedInputMs += input;
      pairedInferenceMs += inference;
      pairedInferenceCases++;
    }
  }
  if (ids.isEmpty) throw const FormatException('结果文件没有可评分样本');
  return {
    'sampleCount': ids.length,
    'normalization': 'lowercase; remove punctuation; collapse whitespace; Unicode code points',
    'cer': characters == 0 ? null : characterErrors / characters,
    'characterErrors': characterErrors,
    'referenceCharacters': characters,
    'wer': words == 0 ? null : wordErrors / words,
    'wordErrors': wordErrors,
    'referenceWords': words,
    'keyFactRecall': facts == 0 ? null : recognizedFacts / facts,
    'keyFactCount': facts,
    'silentCases': silentCases,
    'silenceWithTextCases': silenceInsertions,
    'firstTextLatencyMs': _percentiles(firstLatencies),
    'stableLatencyMs': _percentiles(stableLatencies),
    'inferenceToNewAudioRatio': pairedInputMs == 0
        ? null
        : pairedInferenceMs / pairedInputMs,
    'pairedInferenceCases': pairedInferenceCases,
  };
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<String> _words(String value) =>
    value.isEmpty ? const [] : value.split(' ');

double? _milliseconds(Map<String, Object?> sample, String key) {
  final value = sample[key];
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('$key 必须是非负有限毫秒值');
  }
  return value.toDouble();
}

Map<String, Object?> _percentiles(List<double> values) {
  values.sort();
  return {
    'count': values.length,
    'p50': values.isEmpty ? null : values[(values.length * 0.50).ceil() - 1],
    'p95': values.isEmpty ? null : values[(values.length * 0.95).ceil() - 1],
  };
}

int _editDistance<T>(List<T> expected, List<T> actual) {
  if (expected.length > 5000 || actual.length > 5000) {
    throw const FormatException('单段超过 5000 个计分单元，请按语音段拆分');
  }
  // ponytail: O(n*m) 时间、O(m) 内存；超过语音段规模时改用成熟批量评分工具。
  var previous = List<int>.generate(actual.length + 1, (index) => index);
  for (var row = 1; row <= expected.length; row++) {
    final current = List<int>.filled(actual.length + 1, 0)..[0] = row;
    for (var column = 1; column <= actual.length; column++) {
      final substitution =
          previous[column - 1] +
          (expected[row - 1] == actual[column - 1] ? 0 : 1);
      final insertion = current[column - 1] + 1;
      final deletion = previous[column] + 1;
      current[column] = math.min(substitution, math.min(insertion, deletion));
    }
    previous = current;
  }
  return previous.last;
}
