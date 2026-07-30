import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'phase_0_4_release_input_builder.dart';

Future<void> main(List<String> arguments) async {
  final templatePath = _valueOf(arguments, '--template');
  final androidEvidencePath = _valueOf(arguments, '--android-evidence');
  final androidEvidenceRef = _valueOf(arguments, '--android-evidence-ref');
  final outputPath = _valueOf(arguments, '--output');
  if (templatePath == null ||
      androidEvidencePath == null ||
      androidEvidenceRef == null ||
      outputPath == null) {
    stderr.writeln(
      '用法：dart run tool/benchmarks/build_phase_0_4_release_input.dart '
      '--template <模板.json> --android-evidence <模拟器证据.json> '
      '--android-evidence-ref <仓库相对引用> --output <输入.json>',
    );
    exitCode = 64;
    return;
  }

  try {
    final template = await _readObject(File(templatePath));
    final evidenceFile = File(androidEvidencePath);
    final evidence = await _readObject(evidenceFile);
    final digest = await sha256.bind(evidenceFile.openRead()).first;
    final input = const Phase04ReleaseInputBuilder().build(
      template: template,
      androidEvidence: evidence,
      androidEvidenceRef: androidEvidenceRef.replaceAll(r'\', '/'),
      androidEvidenceSha256: digest.toString(),
    );
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(input)}\n',
      flush: true,
    );
    stdout.writeln('阶段 0～4 评估输入：${outputFile.absolute.path}');
  } on FormatException catch (error) {
    stderr.writeln('阶段 0～4 证据格式错误：${error.message}');
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln('无法读写阶段 0～4 证据：${error.message}');
    exitCode = 66;
  }
}

Future<Map<String, Object?>> _readObject(File file) async {
  final value = jsonDecode(await file.readAsString());
  if (value is! Map<String, Object?>) {
    throw FormatException('${file.path} 根节点必须为 JSON 对象');
  }
  return value;
}

String? _valueOf(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) {
    return null;
  }
  return arguments[index + 1];
}
