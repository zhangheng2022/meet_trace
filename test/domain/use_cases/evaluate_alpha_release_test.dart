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

    test('JSON 输入和报告输出保留可追溯标识且不包含原音频', () {
      final input = AlphaReleaseEvaluationInput.fromJson(
        _passingInput().toJson(),
      );
      final report = const EvaluateAlphaReleaseUseCase().execute(input);
      final json = report.toJson();

      expect(input.corpusId, 'corpus-deidentified-v1');
      expect(input.deviceId, 'low-end-arm64-01');
      expect(json['decision'], 'go');
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
  corpusId: 'corpus-deidentified-v1',
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
  silenceSampleCount: 20,
  silenceFalsePositiveCount: 0,
  noiseSampleCount: 20,
  baselineNoiseHallucinationCount: 10,
  vadNoiseHallucinationCount: 2,
  vadChunkBoundaryConsistent: true,
  vadFailureRecordingContinues: true,
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
