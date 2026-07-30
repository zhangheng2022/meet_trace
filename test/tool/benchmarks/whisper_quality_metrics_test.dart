import 'package:flutter_test/flutter_test.dart';

import '../../../tool/benchmarks/whisper_quality_metrics.dart';

void main() {
  group('WhisperQualityMetrics', () {
    test('按模型和 Profile 计算 RTF、延迟、事实召回和静音噪声指标', () {
      final report = const WhisperQualityMetrics().evaluate(
        _input(sampleCount: 20),
      );
      final summaries = report['summaries']! as List<Map<String, Object?>>;
      final summary = summaries.single;

      expect(report['corpusId'], 'deidentified-v1');
      expect(summary['sampleCount'], 20);
      expect(summary['rtfP50'], 0.1);
      expect(summary['rtfP95'], 0.1);
      expect(summary['sentenceLatencyP95Ms'], 1200);
      expect(summary['keyFactRecallRatio'], 1);
      expect(summary['silenceSampleCount'], 5);
      expect(summary['silenceFalsePositiveCount'], 0);
      expect(summary['noiseSampleCount'], 5);
      expect(summary['noiseHallucinationCount'], 0);
      expect(summary['peakRssBytes'], 120000000);
      expect(summary['energyWh'], closeTo(2, 0.00001));
    });

    test('少于 20 段、未知 sample 或音频路径引用会拒绝', () {
      expect(
        () => const WhisperQualityMetrics().evaluate(_input(sampleCount: 19)),
        throwsA(isA<WhisperQualityMetricsException>()),
      );

      final unknown = _input(sampleCount: 20);
      final observations = unknown['observations']! as List<Object?>;
      (observations.first! as Map<String, Object?>)['sampleId'] = 'missing';
      expect(
        () => const WhisperQualityMetrics().evaluate(unknown),
        throwsA(isA<WhisperQualityMetricsException>()),
      );

      final unsafe = _input(sampleCount: 20);
      final unsafeObservations = unsafe['observations']! as List<Object?>;
      (unsafeObservations.first! as Map<String, Object?>)['transcriptRef'] =
          'private/audio.pcm';
      expect(
        () => const WhisperQualityMetrics().evaluate(unsafe),
        throwsA(isA<WhisperQualityMetricsException>()),
      );
    });

    test('每个 Profile 必须完整且不重复地覆盖全部语料', () {
      final missing = _input(sampleCount: 20);
      final missingObservations = missing['observations']! as List<Object?>;
      missingObservations.removeLast();
      expect(
        () => const WhisperQualityMetrics().evaluate(missing),
        throwsA(isA<WhisperQualityMetricsException>()),
      );

      final duplicate = _input(sampleCount: 20);
      final duplicateObservations = duplicate['observations']! as List<Object?>;
      duplicateObservations.add(duplicateObservations.first);
      expect(
        () => const WhisperQualityMetrics().evaluate(duplicate),
        throwsA(isA<WhisperQualityMetricsException>()),
      );
    });
  });
}

Map<String, Object?> _input({required int sampleCount}) {
  final samples = <Map<String, Object?>>[
    for (var index = 0; index < sampleCount; index++)
      {
        'id': 'sample-$index',
        'durationMs': 10000,
        'tags': [
          if (index < 5) 'silence',
          if (index >= 5 && index < 10) 'noise',
          if (index >= 10) 'speech',
        ],
        'expectedKeyFacts': [if (index >= 10) 'fact-$index'],
      },
  ];
  return {
    'schemaVersion': 1,
    'corpus': {
      'id': 'deidentified-v1',
      'deidentified': true,
      'samples': samples,
    },
    'observations': [
      for (var index = 0; index < sampleCount; index++)
        {
          'sampleId': 'sample-$index',
          'modelId': 'whisper-base',
          'modelVersion': 'v1',
          'profileId': 'baseline',
          'inferenceDurationMs': 1000,
          'sentenceLatencyMs': 1200,
          'emittedText': index >= 10,
          'recognizedKeyFacts': [if (index >= 10) 'fact-$index'],
          'peakRssBytes': 120000000,
          'energyWh': 0.1,
          'sustainedSevereOrCriticalThermal': false,
          'transcriptRef': 'metrics/transcript-$index.json',
        },
    ],
  };
}
