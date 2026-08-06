import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/use_cases/evaluate_alpha_release.dart';

void main() {
  group('EvaluateAlphaReleaseUseCase', () {
    test('SenseVoice 全部证据达到 PRD 门槛时给出 Go', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput(),
      );
      expect(report.decision, AlphaReleaseDecision.go);
      expect(
        report.gates.every((gate) => gate.status == ReleaseGateStatus.passed),
        isTrue,
      );
      expect(
        report.gates
            .singleWhere((gate) => gate.id == 'senseVoice.rtfP95')
            .value,
        0.49,
      );
    });

    test('RTF P95 等于 0.5 不通过严格小于门槛', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(
          rtfSamples: [for (var i = 1; i <= 18; i++) i / 100, 0.5, 0.8],
        ),
      );
      final gate = report.gates.singleWhere(
        (gate) => gate.id == 'senseVoice.rtfP95',
      );
      expect(gate.value, 0.5);
      expect(gate.status, ReleaseGateStatus.failed);
      expect(report.decision, AlphaReleaseDecision.noGo);
    });

    test('少于 20 个样本保持 blocked', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(rtfSamples: [0.1]),
      );
      expect(
        report.gates
            .singleWhere((gate) => gate.id == 'senseVoice.rtfP95')
            .status,
        ReleaseGateStatus.missing,
      );
      expect(report.decision, AlphaReleaseDecision.blocked);
    });

    test('iOS 后台录音未通过时为 No-Go', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(iosBackgroundRecordingPassed: false),
      );
      expect(report.decision, AlphaReleaseDecision.noGo);
    });

    test('说话人 DER 超过 25% 时为 No-Go', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(diarizationDer: 0.251),
      );
      expect(
        report.gates
            .singleWhere((gate) => gate.id == 'speakerDiarization.der')
            .status,
        ReleaseGateStatus.failed,
      );
      expect(report.decision, AlphaReleaseDecision.noGo);
    });

    test('说话人指标出现不可能的负值或零 RTF 时为 No-Go', () {
      final useCase = const EvaluateAlphaReleaseUseCase();
      final negativeDer = useCase.execute(
        _passingInput().copyWith(diarizationDer: -0.001),
      );
      final negativeSpeakerError = useCase.execute(
        _passingInput().copyWith(diarizationMaxSpeakerCountAbsoluteError: -1),
      );
      final zeroRtf = useCase.execute(
        _passingInput().copyWith(diarizationRtf: 0),
      );

      expect(negativeDer.decision, AlphaReleaseDecision.noGo);
      expect(negativeSpeakerError.decision, AlphaReleaseDecision.noGo);
      expect(zeroRtf.decision, AlphaReleaseDecision.noGo);
    });

    test('说话人语料缺少 4 人场景时为 No-Go', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(diarizationTestedSpeakerCounts: [2, 3]),
      );
      expect(
        report.gates
            .singleWhere(
              (gate) => gate.id == 'speakerDiarization.testedSpeakerCounts',
            )
            .status,
        ReleaseGateStatus.failed,
      );
      expect(report.decision, AlphaReleaseDecision.noGo);
    });

    test('仅有 AT-01 至 AT-15 证据时为 No-Go', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(
          acceptanceEvidence: {
            for (var i = 1; i <= 15; i++)
              'AT-${i.toString().padLeft(2, '0')}': 'evidence/AT-$i.json',
          },
        ),
      );
      expect(
        report.gates
            .singleWhere((gate) => gate.id == 'acceptance.AT01-AT18')
            .status,
        ReleaseGateStatus.failed,
      );
      expect(report.decision, AlphaReleaseDecision.noGo);
    });

    test('任一平台音频分享未通过时为 No-Go', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(androidAudioSharePassed: false),
      );
      expect(report.decision, AlphaReleaseDecision.noGo);
    });

    test('空输入全部缺失并阻塞发布', () {
      final report = const EvaluateAlphaReleaseUseCase().execute(
        const AlphaReleaseEvaluationInput(),
      );
      expect(report.decision, AlphaReleaseDecision.blocked);
      expect(
        report.gates.every((gate) => gate.status == ReleaseGateStatus.missing),
        isTrue,
      );
    });

    test('JSON 往返保留指标且拒绝原音频引用', () {
      final input = AlphaReleaseEvaluationInput.fromJson(
        _passingInput().toJson(),
      );
      expect(
        const EvaluateAlphaReleaseUseCase().execute(input).decision,
        AlphaReleaseDecision.go,
      );
      final unsafe = const EvaluateAlphaReleaseUseCase().execute(
        _passingInput().copyWith(rawMetricsRef: 'audio/sample.wav'),
      );
      expect(
        unsafe.gates
            .singleWhere((gate) => gate.id == 'evidence.rawMetrics')
            .status,
        ReleaseGateStatus.failed,
      );
    });
  });
}

AlphaReleaseEvaluationInput _passingInput() => AlphaReleaseEvaluationInput(
  corpusId: 'corpus-deidentified-v1',
  deviceId: 'target-arm64-01',
  rawMetricsRef: 'metrics/sense-voice.json',
  corpusSampleCount: 20,
  corpusDeidentified: true,
  androidArm64DeviceTested: true,
  iosArm64DeviceTested: true,
  androidBackgroundRecordingPassed: true,
  iosBackgroundRecordingPassed: true,
  androidInterruptionRecoveryPassed: true,
  iosInterruptionRecoveryPassed: true,
  adaptiveNavigationAccessibilityPassed: true,
  alphaUpgradeResetPassed: true,
  textSharePassed: true,
  androidAudioSharePassed: true,
  iosAudioSharePassed: true,
  runtimeDownloadBytes: 286314800,
  rtfSamples: [for (var i = 1; i <= 18; i++) i / 100, 0.49, 0.8],
  sentenceLatencyMs: [for (var i = 1; i <= 20; i++) i * 100],
  finalTranscriptionDurationMs: 299000,
  recordingCompletenessRatio: 1,
  sustainedSevereOrCriticalThermal: false,
  batteryDeltaPercent: 8,
  startTemperatureC: 30,
  peakTemperatureC: 42,
  peakRssBytes: 700000000,
  keyFactRecallRatio: 0.85,
  diarizationCorpusMinutes: 60,
  diarizationTestedSpeakerCounts: [2, 3, 4],
  diarizationDer: 0.25,
  diarizationMaxSpeakerCountAbsoluteError: 1,
  diarizationRtf: 0.5,
  diarizationRepeatedRunPeakRssBytes: 800000000,
  androidSpeakerDiarizationTested: true,
  iosSpeakerDiarizationTested: true,
  acceptanceEvidence: {
    for (var i = 1; i <= 18; i++)
      'AT-${i.toString().padLeft(2, '0')}': 'evidence/AT-$i.json',
  },
  apkAuditPassed: true,
  iosBuildAuditPassed: true,
  senseVoiceLicenseConfirmed: true,
);
