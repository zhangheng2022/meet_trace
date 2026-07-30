import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/use_cases/evaluate_alpha_release.dart';

import '../../../tool/benchmarks/evaluate_alpha_release.dart';

void main() {
  test('发布评估 CLI 支持命名参数和兼容位置参数', () {
    final named = parseEvaluateAlphaReleaseArguments([
      '--input',
      'input.json',
      '--output',
      'output.json',
    ]);
    final positional = parseEvaluateAlphaReleaseArguments([
      'input.json',
      'output.json',
    ]);

    expect(named?.input, 'input.json');
    expect(named?.output, 'output.json');
    expect(positional?.input, 'input.json');
    expect(positional?.output, 'output.json');
    expect(parseEvaluateAlphaReleaseArguments(const []), isNull);
    expect(parseEvaluateAlphaReleaseArguments(const ['--input']), isNull);
  });

  test('示例输入使用当前 schema 且缺失证据保持 blocked', () async {
    final decoded =
        jsonDecode(
              await File(
                'tool/benchmarks/alpha_release_input.example.json',
              ).readAsString(),
            )
            as Map<String, Object?>;
    final input = AlphaReleaseEvaluationInput.fromJson(decoded);
    final report = const EvaluateAlphaReleaseUseCase().execute(input);

    expect(input.schemaVersion, alphaReleaseInputSchemaVersion);
    expect(report.decision, AlphaReleaseDecision.blocked);
    expect(
      report.gates.where((gate) => gate.status == ReleaseGateStatus.failed),
      isEmpty,
    );
  });

  test('提交的阶段 0 到 4 blocked 报告与当前评估器一致', () async {
    final inputJson =
        jsonDecode(
              await File(
                'docs/quality/evidence/android-emulator/'
                'phase-0-4-release-input.json',
              ).readAsString(),
            )
            as Map<String, Object?>;
    final committedReport =
        jsonDecode(
              await File(
                'docs/quality/evidence/android-emulator/'
                'phase-0-4-release-report.json',
              ).readAsString(),
            )
            as Map<String, Object?>;
    final report = const EvaluateAlphaReleaseUseCase().execute(
      AlphaReleaseEvaluationInput.fromJson(inputJson),
    );

    expect(report.toJson(), committedReport);
    expect(report.decision, AlphaReleaseDecision.blocked);
    expect(
      report.gates.where((gate) => gate.status == ReleaseGateStatus.failed),
      isEmpty,
    );
  });
}
