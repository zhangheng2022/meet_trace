import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'phase_0_4_quality_input_builder.dart';

Future<void> main(List<String> arguments) async {
  final options = _parseArguments(arguments);
  if (options == null) {
    stderr.writeln(
      '用法：dart run tool/benchmarks/build_phase_0_4_quality_input.dart '
      '--template <阶段输入.json> --quality-report <私有聚合报告.json> '
      '--quality-evidence-output <可提交报告.json> '
      '--quality-evidence-ref <仓库相对引用> --output <阶段输入.json>',
    );
    exitCode = 64;
    return;
  }

  try {
    final template = await _readObject(File(options.template));
    final privateQualityReport = await _readObject(File(options.qualityReport));
    final qualityReport = const Phase04QualityInputBuilder().promotableEvidence(
      privateQualityReport,
    );
    final qualityJson =
        '${const JsonEncoder.withIndent('  ').convert(qualityReport)}\n';
    final qualitySha256 = sha256.convert(utf8.encode(qualityJson)).toString();
    final input = const Phase04QualityInputBuilder().build(
      template: template,
      qualityReport: qualityReport,
      rawMetricsRef: options.qualityEvidenceRef.replaceAll(r'\', '/'),
      rawMetricsSha256: qualitySha256,
    );

    final qualityOutput = File(options.qualityEvidenceOutput);
    await qualityOutput.parent.create(recursive: true);
    await qualityOutput.writeAsString(qualityJson, flush: true);
    final inputOutput = File(options.output);
    await inputOutput.parent.create(recursive: true);
    await inputOutput.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(input)}\n',
      flush: true,
    );
    stdout
      ..writeln('阶段 0～4 质量证据：${qualityOutput.absolute.path}')
      ..writeln('阶段 0～4 评估输入：${inputOutput.absolute.path}');
  } on FormatException catch (error) {
    stderr.writeln('阶段 0～4 质量证据格式错误：${error.message}');
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln('无法读写阶段 0～4 质量证据：${error.message}');
    exitCode = 66;
  }
}

final class _Options {
  const _Options({
    required this.template,
    required this.qualityReport,
    required this.qualityEvidenceOutput,
    required this.qualityEvidenceRef,
    required this.output,
  });

  final String template;
  final String qualityReport;
  final String qualityEvidenceOutput;
  final String qualityEvidenceRef;
  final String output;
}

_Options? _parseArguments(List<String> arguments) {
  if (arguments.length.isOdd) {
    return null;
  }
  const allowed = {
    '--template',
    '--quality-report',
    '--quality-evidence-output',
    '--quality-evidence-ref',
    '--output',
  };
  final values = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final name = arguments[index];
    if (!allowed.contains(name) ||
        values.containsKey(name) ||
        index + 1 >= arguments.length ||
        arguments[index + 1].startsWith('--')) {
      return null;
    }
    values[name] = arguments[index + 1];
  }
  if (!allowed.every(values.containsKey)) {
    return null;
  }
  return _Options(
    template: values['--template']!,
    qualityReport: values['--quality-report']!,
    qualityEvidenceOutput: values['--quality-evidence-output']!,
    qualityEvidenceRef: values['--quality-evidence-ref']!,
    output: values['--output']!,
  );
}

Future<Map<String, Object?>> _readObject(File file) async {
  final value = jsonDecode(await file.readAsString());
  if (value is! Map<String, Object?>) {
    throw FormatException('${file.path} 根节点必须为 JSON 对象');
  }
  return value;
}
