import 'dart:convert';
import 'dart:io';

import 'package:meettrace/domain/use_cases/evaluate_alpha_release.dart';

Future<void> main(List<String> arguments) async {
  final options = parseEvaluateAlphaReleaseArguments(arguments);
  if (options == null) {
    stderr.writeln(
      '用法：dart run tool/benchmarks/evaluate_alpha_release.dart '
      '--input <评测输入.json> [--output <报告输出.json>]\n'
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
  const EvaluateAlphaReleaseCliOptions({required this.input, this.output});

  final String input;
  final String? output;
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

  String? valueOf(String name) {
    final index = arguments.indexOf(name);
    if (index < 0 || index + 1 >= arguments.length) {
      return null;
    }
    return arguments[index + 1];
  }

  final input = valueOf('--input');
  final output = valueOf('--output');
  final expectedLength = output == null ? 2 : 4;
  if (input == null || arguments.length != expectedLength) {
    return null;
  }
  return EvaluateAlphaReleaseCliOptions(input: input, output: output);
}
