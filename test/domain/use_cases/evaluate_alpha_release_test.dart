import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/use_cases/evaluate_alpha_release.dart';

void main() {
  group('EvaluateAlphaReleaseUseCase', () {
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

    test('静音、噪声、chunk 一致性或 16 KB 任一失败时 No-Go', () {
      final failingInputs = [
        _passingInput().copyWith(silenceFalsePositiveCount: 1),
        _passingInput().copyWith(vadNoiseHallucinationCount: 3),
        _passingInput().copyWith(vadChunkBoundaryConsistent: false),
        _passingInput().copyWith(vadFailureRecordingContinues: false),
        _passingInput().copyWith(android16KbPassed: false),
      ];

      for (final input in failingInputs) {
        final report = const EvaluateAlphaReleaseUseCase().execute(input);
        expect(report.decision, AlphaReleaseDecision.noGo);
      }
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
      expect(gate.status, ReleaseGateStatus.missing);
      expect(report.decision, AlphaReleaseDecision.blocked);
    });

    test('缺少真机、语料、许可或验收证据时阻塞发布而非伪造失败值', () {
      const input = AlphaReleaseEvaluationInput();

      final report = const EvaluateAlphaReleaseUseCase().execute(input);

      expect(report.decision, AlphaReleaseDecision.blocked);
      expect(
        report.gates.every((gate) => gate.status == ReleaseGateStatus.missing),
        isTrue,
      );
      expect(
        report.gates
            .singleWhere((gate) => gate.id == 'license.whisperCpp')
            .value,
        isNull,
      );
    });

    test('公开或合成证据不能关闭产品会议质量门槛', () {
      for (final evidenceClass in ['public-regression', 'synthetic-smoke']) {
        final report = const EvaluateAlphaReleaseUseCase().execute(
          _passingInput().copyWith(corpusEvidenceClass: evidenceClass),
        );
        final gate = report.gates.singleWhere(
          (candidate) => candidate.id == 'corpus.evidenceClass',
        );

        expect(gate.status, ReleaseGateStatus.failed);
        expect(report.decision, AlphaReleaseDecision.noGo);
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

    test('Base、Small 或语音首尾关键事实回退时 No-Go', () {
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
        expect(report.decision, AlphaReleaseDecision.noGo);
      }
    });

    test('Preview 延迟必须有 20 个样本且 P95 不超过 3 秒', () {
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
        ReleaseGateStatus.missing,
      );
      expect(missing.decision, AlphaReleaseDecision.blocked);
      expect(
        failed.gates
            .singleWhere((gate) => gate.id == 'quality.previewLatencyP95Ms')
            .status,
        ReleaseGateStatus.failed,
      );
      expect(failed.decision, AlphaReleaseDecision.noGo);
    });

    test('语料 manifest 必须绑定有效 SHA-256 和来源授权', () {
      final invalid = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(corpusManifestSha256: 'not-a-sha256'),
      );
      final gate = invalid.gates.singleWhere(
        (candidate) => candidate.id == 'corpus.manifestSha256',
      );

      expect(gate.status, ReleaseGateStatus.failed);
      expect(invalid.decision, AlphaReleaseDecision.noGo);
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
      expect(report.decision, AlphaReleaseDecision.noGo);
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
      expect(input.deviceId, 'low-end-arm64-01');
      expect(json['schemaVersion'], 2);
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
  schemaVersion: 4,
  corpusId: 'corpus-deidentified-v1',
  corpusEvidenceClass: 'product-meeting',
  corpusManifestSha256:
      '0123456789abcdef0123456789abcdef'
      '0123456789abcdef0123456789abcdef',
  corpusSourceId: 'meettrace:deidentified-meeting-corpus-v1',
  corpusLicenseId: 'internal-consent-v1',
  deviceId: 'low-end-arm64-01',
  rawMetricsRef: 'metrics/at16.json',
  corpusSampleCount: 20,
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
  iosBuildAuditPassed: true,
  iosBuildEvidenceRef: 'evidence/ios-build.json',
  whisperCppLicenseConfirmed: true,
);
