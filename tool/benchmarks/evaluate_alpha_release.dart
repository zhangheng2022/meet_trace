import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meettrace/domain/use_cases/evaluate_alpha_release.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  final options = parseEvaluateAlphaReleaseArguments(arguments);
  if (options == null) {
    stderr.writeln(
      '用法：dart run tool/benchmarks/evaluate_alpha_release.dart '
      '--input <评测输入.json> [--output <报告输出.json>]\n'
      '[--repository-root <仓库根目录>]\n'
      '兼容用法：<评测输入.json> [报告输出.json]',
    );
    exitCode = 64;
    return;
  }

  try {
    final inputFile = File(options.input);
    final decoded = jsonDecode(await inputFile.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('评测输入根节点必须是 JSON 对象');
    }

    final input = AlphaReleaseEvaluationInput.fromJson(decoded);
    await verifyAlphaReleaseEvidence(
      input: input,
      repositoryRoot: Directory(
        options.repositoryRoot ?? Directory.current.path,
      ),
    );
    final report = const EvaluateAlphaReleaseUseCase().execute(input);
    final output = const JsonEncoder.withIndent('  ').convert(report.toJson());
    if (options.output != null) {
      final outputFile = File(options.output!);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString('$output\n');
      stdout.writeln('发布门禁报告：${outputFile.absolute.path}');
    } else {
      stdout.writeln(output);
    }

    switch (report.decision) {
      case AlphaReleaseDecision.go:
        exitCode = 0;
      case AlphaReleaseDecision.noGo:
        exitCode = 1;
      case AlphaReleaseDecision.blocked:
        exitCode = 2;
    }
  } on FormatException catch (error) {
    stderr.writeln('评测输入格式错误：${error.message}');
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln('无法读写评测文件：${error.message}');
    exitCode = 66;
  }
}

final class EvaluateAlphaReleaseCliOptions {
  const EvaluateAlphaReleaseCliOptions({
    required this.input,
    this.output,
    this.repositoryRoot,
  });

  final String input;
  final String? output;
  final String? repositoryRoot;
}

EvaluateAlphaReleaseCliOptions? parseEvaluateAlphaReleaseArguments(
  List<String> arguments,
) {
  if (arguments.length == 1 && !arguments.first.startsWith('-')) {
    return EvaluateAlphaReleaseCliOptions(input: arguments.first);
  }
  if (arguments.length == 2 &&
      arguments.every((argument) => !argument.startsWith('-'))) {
    return EvaluateAlphaReleaseCliOptions(
      input: arguments.first,
      output: arguments.last,
    );
  }

  if (arguments.length.isOdd) {
    return null;
  }
  const allowed = {'--input', '--output', '--repository-root'};
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

  final input = values['--input'];
  if (input == null) {
    return null;
  }
  return EvaluateAlphaReleaseCliOptions(
    input: input,
    output: values['--output'],
    repositoryRoot: values['--repository-root'],
  );
}

Future<void> verifyAlphaReleaseEvidence({
  required AlphaReleaseEvaluationInput input,
  required Directory repositoryRoot,
}) async {
  final reference = input.androidEvidenceRef?.trim();
  final expectedSha256 = input.androidEvidenceSha256?.trim().toLowerCase();
  if ((reference == null || reference.isEmpty) &&
      (expectedSha256 == null || expectedSha256.isEmpty)) {
    return;
  }
  if (reference == null ||
      reference.isEmpty ||
      expectedSha256 == null ||
      expectedSha256.isEmpty) {
    return;
  }
  if (p.isAbsolute(reference)) {
    throw const FormatException('Android 证据引用必须为仓库相对路径');
  }
  final lexicalRoot = p.normalize(p.absolute(repositoryRoot.path));
  final lexicalEvidencePath = p.normalize(
    p.absolute(p.join(lexicalRoot, reference)),
  );
  if (!p.isWithin(lexicalRoot, lexicalEvidencePath)) {
    throw const FormatException('Android 证据引用越过仓库根目录');
  }
  final canonicalRoot = p.normalize(
    await repositoryRoot.resolveSymbolicLinks(),
  );
  final evidenceFile = File(lexicalEvidencePath);
  final canonicalEvidencePath = p.normalize(
    await evidenceFile.resolveSymbolicLinks(),
  );
  if (!p.isWithin(canonicalRoot, canonicalEvidencePath)) {
    throw const FormatException('Android 证据符号链接越过仓库根目录');
  }
  final actualSha256 = await sha256.bind(evidenceFile.openRead()).first;
  if (actualSha256.toString() != expectedSha256) {
    throw const FormatException('Android 证据 SHA-256 与评估输入不一致');
  }
  final decoded = jsonDecode(await evidenceFile.readAsString());
  if (decoded is! Map<String, Object?> || decoded['status'] != 'passed') {
    throw const FormatException('Android 证据必须是 status=passed 的 JSON 对象');
  }
}
