import 'package:flutter_test/flutter_test.dart';

import '../../../tool/benchmarks/phase_0_4_quality_input_builder.dart';
import '../../../tool/benchmarks/whisper_quality_protocol.dart';

void main() {
  group('Phase04QualityInputBuilder', () {
    test('从完整产品会议矩阵推导全部质量门禁字段', () {
      final input = const Phase04QualityInputBuilder().build(
        template: _template(),
        qualityReport: _report(),
        rawMetricsRef:
            'docs/quality/evidence/product-meeting/quality-report.json',
        rawMetricsSha256: 'a' * 64,
      );
      final corpus = input['corpus']! as Map<String, Object?>;
      final provenance = corpus['provenance']! as Map<String, Object?>;
      final environment = input['environment']! as Map<String, Object?>;
      final standard = input['standardModel']! as Map<String, Object?>;
      final advanced = input['advancedModel']! as Map<String, Object?>;
      final vad = input['vad']! as Map<String, Object?>;
      final quality = input['quality']! as Map<String, Object?>;

      expect(input['schemaVersion'], 8);
      expect(corpus['sampleCount'], 60);
      expect(provenance['reviewAttestationSha256'], 'a' * 64);
      expect(provenance['reviewedAtUtc'], '2026-07-31T10:30:00Z');
      expect(environment['sameCorpusForBothModels'], isTrue);
      expect(environment['sameDeviceForBothModels'], isTrue);
      expect((standard['rtfSamples']! as List<Object?>), hasLength(60));
      expect((advanced['sentenceLatencyMs']! as List<Object?>), hasLength(60));
      expect(vad['silenceSampleCount'], 20);
      expect(vad['noiseSampleCount'], 20);
      expect(vad['baselineNoiseHallucinationCount'], 10);
      expect(vad['vadNoiseHallucinationCount'], 2);
      expect(quality['fixedWindowBothModelsCompleted'], isTrue);
      expect(quality['profilePipelineMatrixCompleted'], isTrue);
      expect(quality['standardFixedWindowKeyFactRecallRatio'], 0.85);
      expect(quality['standardVadKeyFactRecallRatio'], 0.9);
      expect(quality['advancedVadKeyFactRecallRatio'], 0.92);
      expect(quality['speechBoundaryKeyFactRecallRatio'], 1);
    });

    test('不完整矩阵显式生成失败或缺失字段而不伪造通过', () {
      final report = _report();
      final summaries = report['summaries']! as List<Object?>;
      summaries.removeWhere(
        (item) =>
            (item! as Map<String, Object?>)['modelId'] ==
            whisperSmallQualityModelId,
      );

      final input = const Phase04QualityInputBuilder().build(
        template: _template(),
        qualityReport: report,
        rawMetricsRef: 'metrics/quality-report.json',
        rawMetricsSha256: 'b' * 64,
      );
      final quality = input['quality']! as Map<String, Object?>;
      final advanced = input['advancedModel']! as Map<String, Object?>;

      expect(quality['fixedWindowBothModelsCompleted'], isFalse);
      expect(quality['profilePipelineMatrixCompleted'], isFalse);
      expect(quality['advancedVadKeyFactRecallRatio'], isNull);
      expect(advanced['rtfSamples'], isNull);
    });

    test('拒绝代理语料、不完整管线声明和不安全引用', () {
      final publicReport = _report()
        ..['corpusEvidenceClass'] = 'public-regression';
      expect(
        () => const Phase04QualityInputBuilder().build(
          template: _template(),
          qualityReport: publicReport,
          rawMetricsRef: 'metrics/report.json',
          rawMetricsSha256: 'c' * 64,
        ),
        throwsFormatException,
      );

      final unreviewedReport = _report();
      final provenance =
          unreviewedReport['corpusProvenance']! as Map<String, Object?>;
      provenance.remove('reviewAttestationSha256');
      expect(
        () => const Phase04QualityInputBuilder().build(
          template: _template(),
          qualityReport: unreviewedReport,
          rawMetricsRef: 'metrics/report.json',
          rawMetricsSha256: 'c' * 64,
        ),
        throwsFormatException,
      );

      final incompletePipelines = _report();
      final execution =
          incompletePipelines['execution']! as Map<String, Object?>;
      execution['pipelineIds'] = <String>[whisperFixedWindowPipelineId];
      expect(
        () => const Phase04QualityInputBuilder().build(
          template: _template(),
          qualityReport: incompletePipelines,
          rawMetricsRef: '../report.json',
          rawMetricsSha256: 'c' * 64,
        ),
        throwsFormatException,
      );

      final leakingReport = _report()..['sourcePath'] = r'C:\private\a.pcm';
      expect(
        () => const Phase04QualityInputBuilder().build(
          template: _template(),
          qualityReport: leakingReport,
          rawMetricsRef: 'metrics/report.json',
          rawMetricsSha256: 'c' * 64,
        ),
        throwsFormatException,
      );
    });

    test('推广证据只保留发布门禁需要的聚合白名单字段', () {
      final privateReport = _report()
        ..['operatorEmail'] = 'private@example.com';
      final firstSummary =
          (privateReport['summaries']! as List<Object?>).first!
              as Map<String, Object?>;
      firstSummary
        ..['transcriptRefs'] = const ['transcripts/private.json']
        ..['thermalEvidenceRefs'] = const ['private/thermal.json'];

      final promoted = const Phase04QualityInputBuilder().promotableEvidence(
        privateReport,
      );
      final promotedSummary =
          (promoted['summaries']! as List<Object?>).first!
              as Map<String, Object?>;

      expect(promoted, isNot(contains('operatorEmail')));
      expect(promoted, isNot(contains('pipelineComparisons')));
      expect(promotedSummary, isNot(contains('transcriptRefs')));
      expect(promotedSummary, isNot(contains('thermalEvidenceRefs')));
      expect(
        () => const Phase04QualityInputBuilder().build(
          template: _template(),
          qualityReport: privateReport,
          rawMetricsRef: 'metrics/report.json',
          rawMetricsSha256: 'e' * 64,
        ),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _template() => {
  'evaluationScope': 'phase-0-4',
  'schemaVersion': 8,
  'rawMetricsRef': null,
  'rawMetricsSha256': null,
  'corpus': <String, Object?>{'provenance': <String, Object?>{}},
  'environment': <String, Object?>{},
  'standardModel': <String, Object?>{'resourceBytes': 60592723},
  'advancedModel': <String, Object?>{},
  'vad': <String, Object?>{
    'chunkBoundaryConsistent': true,
    'failureRecordingContinues': true,
  },
  'quality': <String, Object?>{},
};

Map<String, Object?> _report() => {
  'schemaVersion': 4,
  'status': 'passed',
  'capturedAtUtc': '2026-07-31T00:00:00Z',
  'corpusId': 'product-meeting-v1',
  'corpusDeidentified': true,
  'corpusEvidenceClass': 'product-meeting',
  'corpusManifestSha256': 'd' * 64,
  'corpusProvenance': {
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
