import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/use_cases/evaluate_alpha_release.dart';

void main() {
  group('EvaluateAlphaReleaseUseCase', () {
    test('阶段 0 到 4 范围不混入后续真机、iOS 和 Release 门槛', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(
          evaluationScope: AlphaReleaseEvaluationScope.phase0To4,
        ),
      );
      final gateIds = report.gates.map((gate) => gate.id).toSet();
      final fullGateIds = const EvaluateAlphaReleaseUseCase()
          .execute(_passingInput())
          .gates
          .map((gate) => gate.id)
          .toSet();

      expect(report.scope, AlphaReleaseEvaluationScope.phase0To4);
      expect(report.decision, AlphaReleaseDecision.go);
      expect(gateIds, contains('quality.previewLatencyP95Ms'));
      expect(gateIds, contains('phase04.summaryFinalSnapshotOnly'));
      expect(gateIds, isNot(contains('environment.lowEndArm64')));
      expect(
        gateIds,
        isNot(contains('environment.adaptiveNavigationAccessibility')),
      );
      expect(gateIds, isNot(contains('evidence.iosBuild')));
      expect(gateIds, isNot(contains('standard.finalTranscriptionDurationMs')));
      expect(gateIds, isNot(contains('standard.thermal')));
      expect(gateIds, isNot(contains('standard.relativeEnergy')));
      expect(gateIds, isNot(contains('acceptance.AT01-AT24')));
      expect(gateIds, isNot(contains('release.android16Kb')));
      expect(gateIds, isNot(contains('release.iosBuildAudit')));
      expect(fullGateIds.difference(gateIds), {
        'environment.sameCorpus',
        'environment.sameDevice',
        'environment.lowEndArm64',
        'environment.adaptiveNavigationAccessibility',
        'evidence.rawMetrics',
        'evidence.rawMetricsSha256',
        'evidence.iosBuild',
        'standard.rtfP95',
        'standard.sentenceLatencyP95Ms',
        'standard.finalTranscriptionDurationMs',
        'standard.recordingCompletenessRatio',
        'standard.thermal',
        'standard.relativeEnergy',
        'advanced.rtfSampleCount',
        'advanced.sentenceLatencySampleCount',
        'advanced.finalTranscriptionDurationMs',
        'acceptance.AT01-AT24',
        'release.android16Kb',
        'release.iosBuildAudit',
      });
    });

    test('缺少范围的旧输入仍按完整 Alpha 发布评估', () {
      final json = _passingInput().toJson()..remove('evaluationScope');
      final input = AlphaReleaseEvaluationInput.fromJson(json);
      final report = const EvaluateAlphaReleaseUseCase().execute(input);

      expect(input.evaluationScope, AlphaReleaseEvaluationScope.alphaRelease);
      expect(report.scope, AlphaReleaseEvaluationScope.alphaRelease);
      expect(
        report.gates.map((gate) => gate.id),
        contains('release.iosBuildAudit'),
      );
    });

    test('全部证据达到 PRD 门槛时给出 Go', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput(),
      );

      expect(report.decision, AlphaReleaseDecision.go);
      expect(
        report.gates.every((gate) => gate.status == ReleaseGateStatus.passed),
        isTrue,
      );
      expect(
        report.gates.singleWhere((gate) => gate.id == 'standard.rtfP95').value,
        0.49,
      );
    });

    test('P95 使用最近秩算法且等于 0.5 不通过严格小于门槛', () {
      final input = _passingInput().copyWith(
        standardRtfSamples: [
          for (var index = 1; index <= 18; index++) index / 100,
          0.5,
          0.8,
        ],
      );

      final report = const EvaluateAlphaReleaseUseCase().execute(input);
      final gate = report.gates.singleWhere(
        (candidate) => candidate.id == 'standard.rtfP95',
      );

      expect(gate.value, 0.5);
      expect(gate.status, ReleaseGateStatus.failed);
      expect(report.decision, AlphaReleaseDecision.noGo);
    });

    test('少于 20 个样本不能用单点指标冒充 P95', () {
      final input = _passingInput().copyWith(standardRtfSamples: [0.1]);

      final report = const EvaluateAlphaReleaseUseCase().execute(input);
      final gate = report.gates.singleWhere(
        (candidate) => candidate.id == 'standard.rtfP95',
      );

      expect(gate.value, isNull);
      expect(gate.status, ReleaseGateStatus.missing);
      expect(report.decision, AlphaReleaseDecision.blocked);
    });

    test('少于 60 段会如实失败但不阻断工程或 Alpha 决策', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(corpusSampleCount: 59),
      );
      final gate = report.gates.singleWhere(
        (candidate) => candidate.id == 'corpus.sampleCount',
      );

      expect(gate.value, 59);
      expect(gate.status, ReleaseGateStatus.failed);
      expect(gate.blocking, isFalse);
      expect(report.decision, AlphaReleaseDecision.go);
    });

    test('产品会议复核证明缺失标记 not_tested，无效值仍如实失败但不阻断', () {
      final missingJson = _passingInput().toJson();
      final missingProvenance =
          (missingJson['corpus']! as Map<String, Object?>)['provenance']!
              as Map<String, Object?>;
      missingProvenance
        ..remove('reviewAttestationSha256')
        ..remove('reviewedAtUtc');
      final missing = const EvaluateAlphaReleaseUseCase().execute(
        AlphaReleaseEvaluationInput.fromJson(missingJson),
      );

      expect(
        missing.gates
            .where((gate) => gate.id.startsWith('corpus.provenance.review'))
            .every(
              (gate) =>
                  gate.status == ReleaseGateStatus.notTested && !gate.blocking,
            ),
        isTrue,
      );
      expect(missing.decision, AlphaReleaseDecision.go);

      final invalid = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(corpusReviewedAtUtc: '2026-07-31T10:30:00'),
      );
      expect(
        invalid.gates
            .singleWhere((gate) => gate.id == 'corpus.provenance.reviewedAtUtc')
            .status,
        ReleaseGateStatus.failed,
      );
      expect(invalid.decision, AlphaReleaseDecision.go);
    });

    test('当前范围不执行 iOS 真机时真机字段不参与发布判定', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(
          iosArm64DeviceTested: false,
          iosBackgroundRecordingPassed: false,
          iosInterruptionRecoveryPassed: false,
        ),
      );

      expect(
        report.gates
            .where((gate) => gate.id.startsWith('environment.ios'))
            .isEmpty,
        isTrue,
      );
      expect(report.decision, AlphaReleaseDecision.go);
    });

    test('静音、chunk 一致性或 16 KB 任一工程硬门槛失败时 No-Go', () {
      final failingInputs = [
        _passingInput().copyWith(silenceFalsePositiveCount: 1),
        _passingInput().copyWith(vadChunkBoundaryConsistent: false),
        _passingInput().copyWith(vadFailureRecordingContinues: false),
        _passingInput().copyWith(android16KbPassed: false),
      ];

      for (final input in failingInputs) {
        final report = const EvaluateAlphaReleaseUseCase().execute(input);
        expect(report.decision, AlphaReleaseDecision.noGo);
      }
    });

    test('噪声幻觉失败作为非阻断观察结果保留', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(vadNoiseHallucinationCount: 3),
      );
      final gate = report.gates.singleWhere(
        (candidate) => candidate.id == 'vad.noiseReductionRatio',
      );

      expect(gate.status, ReleaseGateStatus.failed);
      expect(gate.blocking, isFalse);
      expect(report.decision, AlphaReleaseDecision.go);
    });

    test('噪声幻觉相对固定窗口下降至少 80%', () {
      final passing = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(
          baselineNoiseHallucinationCount: 10,
          vadNoiseHallucinationCount: 2,
        ),
      );
      final failing = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(
          baselineNoiseHallucinationCount: 10,
          vadNoiseHallucinationCount: 3,
        ),
      );

      expect(
        passing.gates
            .singleWhere((gate) => gate.id == 'vad.noiseReductionRatio')
            .status,
        ReleaseGateStatus.passed,
      );
      expect(
        failing.gates
            .singleWhere((gate) => gate.id == 'vad.noiseReductionRatio')
            .status,
        ReleaseGateStatus.failed,
      );
    });

    test('固定窗口没有基线噪声幻觉时不能声称下降 80%', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(
          baselineNoiseHallucinationCount: 0,
          vadNoiseHallucinationCount: 0,
        ),
      );
      final gate = report.gates.singleWhere(
        (candidate) => candidate.id == 'vad.noiseReductionRatio',
      );

      expect(gate.value, isNull);
      expect(gate.status, ReleaseGateStatus.notTested);
      expect(gate.blocking, isFalse);
      expect(report.decision, AlphaReleaseDecision.go);
    });

    test('缺少真机、语料、许可或验收证据时阻塞发布而非伪造失败值', () {
      const input = AlphaReleaseEvaluationInput();

      final report = const EvaluateAlphaReleaseUseCase().execute(input);

      expect(report.decision, AlphaReleaseDecision.blocked);
      expect(
        report.gates
            .where((gate) => gate.blocking)
            .every((gate) => gate.status == ReleaseGateStatus.missing),
        isTrue,
      );
      expect(
        report.gates
            .where((gate) => !gate.blocking)
            .every((gate) => gate.status == ReleaseGateStatus.notTested),
        isTrue,
      );
      expect(
        report.gates
            .singleWhere((gate) => gate.id == 'license.whisperCpp')
            .value,
        isNull,
      );
    });

    test('旧 Paraformer 授权字段不能关闭 Whisper C++ 许可门槛', () {
      final json = _passingInput().toJson();
      final release = json['release']! as Map<String, Object?>;
      release
        ..remove('whisperCppLicenseConfirmed')
        ..['paraformerRedistributionConfirmed'] = true;

      final input = AlphaReleaseEvaluationInput.fromJson(json);
      final report = const EvaluateAlphaReleaseUseCase().execute(input);
      final gate = report.gates.singleWhere(
        (candidate) => candidate.id == 'license.whisperCpp',
      );

      expect(input.whisperCppLicenseConfirmed, isNull);
      expect(gate.status, ReleaseGateStatus.missing);
      expect(report.decision, AlphaReleaseDecision.blocked);
    });

    test('公开或合成证据不能冒充产品会议结果，但不再阻断交付', () {
      for (final evidenceClass in ['public-regression', 'synthetic-smoke']) {
        final report = const EvaluateAlphaReleaseUseCase().execute(
          _passingInput().copyWith(corpusEvidenceClass: evidenceClass),
        );
        final gate = report.gates.singleWhere(
          (candidate) => candidate.id == 'corpus.evidenceClass',
        );

        expect(gate.status, ReleaseGateStatus.failed);
        expect(gate.blocking, isFalse);
        expect(report.decision, AlphaReleaseDecision.go);
      }
    });

    test('旧 schema 缺少阶段 0 到 4 字段时保持 blocked', () {
      final json = _passingInput().toJson()
        ..['schemaVersion'] = 3
        ..remove('quality')
        ..remove('phase04');
      final report = const EvaluateAlphaReleaseUseCase().execute(
        AlphaReleaseEvaluationInput.fromJson(json),
      );

      expect(
        report.gates
            .singleWhere((gate) => gate.id == 'input.schemaVersion')
            .status,
        ReleaseGateStatus.missing,
      );
      expect(report.decision, AlphaReleaseDecision.blocked);
    });

    test('Base、Small 或语音首尾关键事实回退如实失败但不阻断', () {
      final regressions = <(AlphaReleaseEvaluationInput, String)>[
        (
          _passingInput().copyWith(
            standardFixedWindowKeyFactRecallRatio: 0.9,
            standardVadKeyFactRecallRatio: 0.89,
          ),
          'quality.standardVadRecallNoRegression',
        ),
        (
          _passingInput().copyWith(
            standardVadKeyFactRecallRatio: 0.9,
            advancedVadKeyFactRecallRatio: 0.89,
          ),
          'quality.advancedVadRecallNoRegression',
        ),
        (
          _passingInput().copyWith(speechBoundaryKeyFactRecallRatio: 0.99),
          'quality.speechBoundaryRecall',
        ),
      ];

      for (final regression in regressions) {
        final report = const EvaluateAlphaReleaseUseCase().execute(
          regression.$1,
        );

        expect(
          report.gates.singleWhere((gate) => gate.id == regression.$2).status,
          ReleaseGateStatus.failed,
          reason: regression.$2,
        );
        expect(
          report.gates.singleWhere((gate) => gate.id == regression.$2).blocking,
          isFalse,
        );
        expect(report.decision, AlphaReleaseDecision.go);
      }
    });

    test('Preview 延迟缺失为 not_tested，超标如实失败但不阻断', () {
      final missing = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(previewSentenceLatencyMs: [100]),
      );
      final failed = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(
          previewSentenceLatencyMs: [
            for (var index = 0; index < 18; index++) 1000,
            3100,
            4000,
          ],
        ),
      );

      expect(
        missing.gates
            .singleWhere((gate) => gate.id == 'quality.previewLatencyP95Ms')
            .status,
        ReleaseGateStatus.notTested,
      );
      expect(missing.decision, AlphaReleaseDecision.go);
      expect(
        failed.gates
            .singleWhere((gate) => gate.id == 'quality.previewLatencyP95Ms')
            .status,
        ReleaseGateStatus.failed,
      );
      expect(failed.decision, AlphaReleaseDecision.go);
    });

    test('语料 manifest 必须绑定有效 SHA-256 和来源授权', () {
      final invalid = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(corpusManifestSha256: 'not-a-sha256'),
      );
      final gate = invalid.gates.singleWhere(
        (candidate) => candidate.id == 'corpus.manifestSha256',
      );

      expect(gate.status, ReleaseGateStatus.failed);
      expect(gate.blocking, isFalse);
      expect(invalid.decision, AlphaReleaseDecision.go);
    });

    test('非有限召回值判定失败且报告仍可 JSON 序列化', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(
          standardVadKeyFactRecallRatio: double.nan,
          speechBoundaryKeyFactRecallRatio: double.infinity,
        ),
      );

      expect(
        report.gates
            .singleWhere(
              (gate) => gate.id == 'quality.standardVadRecallNoRegression',
            )
            .status,
        ReleaseGateStatus.failed,
      );
      expect(
        report.gates
            .singleWhere((gate) => gate.id == 'quality.speechBoundaryRecall')
            .status,
        ReleaseGateStatus.failed,
      );
      expect(
        report.gates
            .where((gate) => gate.id.startsWith('quality.'))
            .every((gate) => !gate.blocking),
        isTrue,
      );
      expect(report.decision, AlphaReleaseDecision.go);
      expect(() => jsonEncode(report.toJson()), returnsNormally);
    });

    test('阶段 0 到 4 工程不变量失败时 No-Go，缺失时 blocked', () {
      final failed = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(asrContextLifecyclePassed: false),
      );
      expect(
        failed.gates
            .singleWhere((gate) => gate.id == 'phase04.asrContextLifecycle')
            .status,
        ReleaseGateStatus.failed,
      );
      expect(failed.decision, AlphaReleaseDecision.noGo);

      final json = _passingInput().toJson()..remove('phase04');
      final missing = const EvaluateAlphaReleaseUseCase().execute(
        AlphaReleaseEvaluationInput.fromJson(json),
      );
      expect(
        missing.gates
            .where((gate) => gate.id.startsWith('phase04.'))
            .every((gate) => gate.status == ReleaseGateStatus.missing),
        isTrue,
      );
      expect(missing.decision, AlphaReleaseDecision.blocked);
    });

    test('JSON 输入和报告输出保留可追溯标识且不包含原音频', () {
      final input = AlphaReleaseEvaluationInput.fromJson(
        _passingInput().toJson(),
      );
      final report = const EvaluateAlphaReleaseUseCase().execute(input);
      final json = report.toJson();

      expect(input.corpusId, 'corpus-deidentified-v1');
      expect(input.corpusReviewAttestationSha256, 'a' * 64);
      expect(input.corpusReviewedAtUtc, '2026-07-31T10:30:00Z');
      expect(input.deviceId, 'low-end-arm64-01');
      expect(json['schemaVersion'], 4);
      expect(json['decision'], 'go');
      expect(json['corpusEvidenceClass'], 'product-meeting');
      expect(json['corpusManifestSha256'], input.corpusManifestSha256);
      expect(json.toString(), isNot(contains('.wav')));
      expect(json.toString(), isNot(contains('.pcm')));

      final unsafeReport = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(rawMetricsRef: 'audio/sample.wav'),
      );
      expect(
        unsafeReport.gates
            .singleWhere((gate) => gate.id == 'evidence.rawMetrics')
            .status,
        ReleaseGateStatus.failed,
      );
      expect(unsafeReport.decision, AlphaReleaseDecision.noGo);
    });
  });
}

AlphaReleaseEvaluationInput _passingInput() => AlphaReleaseEvaluationInput(
  schemaVersion: alphaReleaseInputSchemaVersion,
  corpusId: 'corpus-deidentified-v1',
  corpusEvidenceClass: 'product-meeting',
  corpusManifestSha256:
      '0123456789abcdef0123456789abcdef'
      '0123456789abcdef0123456789abcdef',
  corpusSourceId: 'meettrace:deidentified-meeting-corpus-v1',
  corpusLicenseId: 'internal-consent-v1',
  corpusReviewAttestationSha256: 'a' * 64,
  corpusReviewedAtUtc: '2026-07-31T10:30:00Z',
  deviceId: 'low-end-arm64-01',
  rawMetricsRef: 'metrics/at16.json',
  rawMetricsSha256:
      'abcdef0123456789abcdef0123456789'
      'abcdef0123456789abcdef0123456789',
  corpusSampleCount: 60,
  corpusDeidentified: true,
  sameCorpusForBothModels: true,
  sameDeviceForBothModels: true,
  lowEndArm64DeviceTested: true,
  iosArm64DeviceTested: true,
  iosBackgroundRecordingPassed: true,
  iosInterruptionRecoveryPassed: true,
  adaptiveNavigationAccessibilityPassed: true,
  standardModelResourceBytes: 99 * 1024 * 1024,
  standardRtfSamples: [
    for (var index = 1; index <= 18; index++) index / 100,
    0.49,
    0.8,
  ],
  standardSentenceLatencyMs: [
    for (var index = 1; index <= 20; index++) index * 100,
  ],
  finalTranscriptionDurationMs: 299000,
  recordingCompletenessRatio: 1,
  sustainedSevereOrCriticalThermal: false,
  standardEnergyWh: 0.7,
  advancedEnergyWh: 1,
  advancedRtfSamples: [for (var index = 1; index <= 20; index++) index / 10],
  advancedSentenceLatencyMs: [
    for (var index = 1; index <= 20; index++) index * 500,
  ],
  advancedFinalTranscriptionDurationMs: 600000,
  keyFactRecallRatio: 0.85,
  fixedWindowBothModelsCompleted: true,
  qualityMatrixCompleted: true,
  previewSentenceLatencyMs: [
    for (var index = 1; index <= 20; index++) index * 100,
  ],
  standardFixedWindowKeyFactRecallRatio: 0.85,
  standardVadKeyFactRecallRatio: 0.9,
  advancedVadKeyFactRecallRatio: 0.92,
  speechBoundaryKeyFactRecallRatio: 1,
  silenceSampleCount: 20,
  silenceFalsePositiveCount: 0,
  noiseSampleCount: 20,
  baselineNoiseHallucinationCount: 10,
  vadNoiseHallucinationCount: 2,
  vadChunkBoundaryConsistent: true,
  vadFailureRecordingContinues: true,
  productBoundaryApproved: true,
  meetingModelLocked: true,
  factPcmSoleSourcePassed: true,
  emulatorLifecyclePassed: true,
  asrFailureRecordingContinues: true,
  startFailureDiagnosticsPassed: true,
  asrContextLifecyclePassed: true,
  vadContextLifecyclePassed: true,
  finalChunkBoundaryConsistent: true,
  previewDropFinalInvariant: true,
  finalTimestampsValid: true,
  snapshotAtomicityPassed: true,
  summaryFinalSnapshotOnly: true,
  acceptanceEvidence: {
    for (var index = 1; index <= 24; index++)
      'AT-${index.toString().padLeft(2, '0')}': 'evidence/AT-$index.json',
  },
  apkAuditPassed: true,
  android16KbPassed: true,
  androidEvidenceRef: 'evidence/android.json',
  androidEvidenceSha256: 'a' * 64,
  iosBuildAuditPassed: true,
  iosBuildEvidenceRef: 'evidence/ios-build.json',
  whisperCppLicenseConfirmed: true,
);
