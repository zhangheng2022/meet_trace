import 'dart:convert';
import 'dart:io';

import 'src/alpha_release_evaluator.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      '用法：dart run tool/benchmarks/evaluate_alpha_release.dart '
      '<评测输入.json> [报告输出.json]',
    );
    exitCode = 64;
    return;
  }

  try {
    final inputFile = File(arguments.first);
    final decoded = jsonDecode(await inputFile.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('评测输入根节点必须是 JSON 对象');
    }

    final input = AlphaReleaseEvaluationInput.fromJson(decoded);
    final report = const EvaluateAlphaReleaseUseCase().execute(input);
    final output = const JsonEncoder.withIndent('  ').convert(report.toJson());
    if (arguments.length == 2) {
      final outputFile = File(arguments[1]);
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
