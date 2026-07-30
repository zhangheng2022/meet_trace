import 'dart:convert';
import 'dart:io';

import 'whisper_quality_protocol.dart';

Future<void> main(List<String> arguments) async {
  final manifest = _valueOf(arguments, '--manifest');
  final repositoryRoot = _valueOf(arguments, '--repository-root');
  final output = _valueOf(arguments, '--output');
  final requiredEvidenceClass = _valueOf(
    arguments,
    '--required-evidence-class',
  );
  if (manifest == null || repositoryRoot == null || output == null) {
    throw const WhisperQualityProtocolException(
      '用法：--manifest <json> --repository-root <path> --output <json>',
    );
  }
  final corpus = await WhisperQualityCorpus.load(
    manifestPath: manifest,
    repositoryRoot: repositoryRoot,
    requiredEvidenceClass: requiredEvidenceClass,
  );
  final outputFile = File(output);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(corpus.toPreparedJson()),
    flush: true,
  );
  stdout.writeln('已校验 ${corpus.samples.length} 段受控 PCM；未输出本地路径。');
}

String? _valueOf(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) {
    return null;
  }
  return arguments[index + 1];
}
