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
            .singleWhere((gate) => gate.id == 'license.paraformer')
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
  acceptanceEvidence: {
    for (var index = 1; index <= 16; index++)
      'AT-${index.toString().padLeft(2, '0')}': 'evidence/AT-$index.json',
  },
  apkAuditPassed: true,
  paraformerRedistributionConfirmed: true,
);
