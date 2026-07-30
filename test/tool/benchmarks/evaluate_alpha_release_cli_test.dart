import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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
    final withRoot = parseEvaluateAlphaReleaseArguments([
      '--input',
      'input.json',
      '--repository-root',
      'repo',
      '--output',
      'output.json',
    ]);

    expect(named?.input, 'input.json');
    expect(named?.output, 'output.json');
    expect(positional?.input, 'input.json');
    expect(positional?.output, 'output.json');
    expect(withRoot?.repositoryRoot, 'repo');
    expect(parseEvaluateAlphaReleaseArguments(const []), isNull);
    expect(parseEvaluateAlphaReleaseArguments(const ['--input']), isNull);
    expect(
      parseEvaluateAlphaReleaseArguments(const [
        '--input',
        'a.json',
        '--unknown',
        'value',
      ]),
      isNull,
    );
  });

  test('发布评估校验 Android 证据状态、仓库边界和实际 SHA-256', () async {
    final root = await Directory.systemTemp.createTemp(
      'meettrace-release-evidence-',
    );
    try {
      final evidence = File('${root.path}/evidence/android.json');
      await evidence.parent.create(recursive: true);
      await evidence.writeAsString('{"status":"passed"}');
      final digest = sha256.convert(await evidence.readAsBytes()).toString();
      AlphaReleaseEvaluationInput inputFor(String reference, String hash) {
        final input = const AlphaReleaseEvaluationInput().copyWith(
          androidEvidenceSha256: hash,
        );
        return AlphaReleaseEvaluationInput.fromJson({
          ...input.toJson(),
          'evidence': {
            ...(input.toJson()['evidence']! as Map<String, Object?>),
            'android': reference,
            'androidSha256': hash,
          },
        });
      }

      final withReference = inputFor('evidence/android.json', digest);

      await verifyAlphaReleaseEvidence(
        input: withReference,
        repositoryRoot: root,
      );

      await evidence.writeAsString('{"status":"failed"}');
      final failedDigest = sha256
          .convert(await evidence.readAsBytes())
          .toString();
      await expectLater(
        verifyAlphaReleaseEvidence(
          input: inputFor('evidence/android.json', failedDigest),
          repositoryRoot: root,
        ),
        throwsFormatException,
      );
      await expectLater(
        verifyAlphaReleaseEvidence(
          input: inputFor('../outside.json', failedDigest),
          repositoryRoot: root,
        ),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
    }
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
