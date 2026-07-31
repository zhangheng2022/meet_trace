import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/use_cases/evaluate_alpha_release.dart';

import '../../../tool/benchmarks/evaluate_alpha_release.dart';
import '../../../tool/benchmarks/phase_0_4_quality_input_builder.dart';
import '../../../tool/benchmarks/whisper_quality_protocol.dart';

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

  test('阶段 0 到 4 输入必须与哈希绑定的质量报告逐字段一致', () async {
    final root = await Directory.systemTemp.createTemp(
      'meettrace-quality-release-evidence-',
    );
    try {
      final report = _qualityReport();
      final reportFile = File('${root.path}/evidence/quality.json');
      await reportFile.parent.create(recursive: true);
      await reportFile.writeAsString(jsonEncode(report));
      final digest = sha256.convert(await reportFile.readAsBytes()).toString();
      final template = const AlphaReleaseEvaluationInput(
        evaluationScope: AlphaReleaseEvaluationScope.phase0To4,
        schemaVersion: alphaReleaseInputSchemaVersion,
      ).toJson();
      final derivedJson = const Phase04QualityInputBuilder().build(
        template: template,
        qualityReport: report,
        rawMetricsRef: 'evidence/quality.json',
        rawMetricsSha256: digest,
      );
      final derived = AlphaReleaseEvaluationInput.fromJson(derivedJson);

      await verifyAlphaReleaseEvidence(input: derived, repositoryRoot: root);

      final tamperedReview =
          jsonDecode(jsonEncode(derivedJson)) as Map<String, Object?>;
      final tamperedCorpus = tamperedReview['corpus']! as Map<String, Object?>;
      final tamperedProvenance =
          tamperedCorpus['provenance']! as Map<String, Object?>;
      tamperedProvenance['reviewAttestationSha256'] = 'b' * 64;
      await expectLater(
        verifyAlphaReleaseEvidence(
          input: AlphaReleaseEvaluationInput.fromJson(tamperedReview),
          repositoryRoot: root,
        ),
        throwsFormatException,
      );

      final standard = derivedJson['standardModel']! as Map<String, Object?>;
      standard['keyFactRecallRatio'] = 0.1;
      await expectLater(
        verifyAlphaReleaseEvidence(
          input: AlphaReleaseEvaluationInput.fromJson(derivedJson),
          repositoryRoot: root,
        ),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('提交的阶段 0 到 4 Go 报告与当前评估器一致', () async {
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
    expect(report.decision, AlphaReleaseDecision.go);
    expect(
      report.gates.where((gate) => gate.status == ReleaseGateStatus.failed),
      isEmpty,
    );
    expect(
      report.gates
          .where((gate) => gate.status == ReleaseGateStatus.notTested)
          .every((gate) => !gate.blocking),
      isTrue,
    );
  });
}

Map<String, Object?> _qualityReport() => {
  'schemaVersion': 4,
  'status': 'passed',
  'capturedAtUtc': '2026-07-31T00:00:00Z',
  'corpusId': 'product-meeting-v1',
  'corpusDeidentified': true,
  'corpusEvidenceClass': 'product-meeting',
  'corpusManifestSha256': 'd' * 64,
  'corpusProvenance': const {
    'sourceId': 'deidentified-internal-v1',
    'licenseId': 'internal-consented-v1',
    'reviewAttestationSha256':
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'reviewedAtUtc': '2026-07-31T10:30:00Z',
  },
  'sampleCount': 60,
  'execution': {
    'platform': 'android-emulator',
    'deviceId': 'android-emulator-x86_64-api-36',
    'pipelineIds': const [
      whisperFixedWindowPipelineId,
      whisperVadSegmentedPipelineId,
      whisperVadRecallCandidatePipelineId,
    ],
  },
  'summaries': <Object?>[
    for (final modelId in const [
      whisperBaseQualityModelId,
      whisperSmallQualityModelId,
    ])
      for (final profileId in const [
        whisperBaselineProfileId,
        whisperPreviewProfileId,
        whisperFinalProfileId,
      ])
        for (final pipelineId in const [
          whisperFixedWindowPipelineId,
          whisperVadSegmentedPipelineId,
          whisperVadRecallCandidatePipelineId,
        ])
          {
            'deviceId': 'android-emulator-x86_64-api-36',
            'modelId': modelId,
            'modelVersion': 'v1.9.1-q5_1',
            'profileId': profileId,
            'pipelineId': pipelineId,
            'sampleCount': 60,
            'rtfSamples': <double>[
              for (var index = 0; index < 60; index++) 0.1,
            ],
            'sentenceLatencyMs': <double>[
              for (var index = 0; index < 60; index++) 1200,
            ],
            'keyFactRecallRatio': modelId == whisperSmallQualityModelId
                ? 0.92
                : pipelineId == whisperFixedWindowPipelineId
                ? 0.85
                : 0.9,
            'keyFactSampleCount': 20,
            'expectedKeyFactCount': 20,
            'recalledKeyFactCount': 18,
            'speechBoundarySampleCount': 2,
            'speechBoundaryStartSampleCount': 1,
            'speechBoundaryEndSampleCount': 1,
            'expectedSpeechBoundaryKeyFactCount': 2,
            'recalledSpeechBoundaryKeyFactCount': 2,
            'speechBoundaryKeyFactRecallRatio': 1.0,
            'silenceSampleCount': 20,
            'silenceFalsePositiveCount': 0,
            'noiseSampleCount': 20,
            'noiseHallucinationCount':
                pipelineId == whisperFixedWindowPipelineId ? 10 : 2,
          },
  ],
};
