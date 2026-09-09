import 'package:flutter_test/flutter_test.dart';

import '../../../tool/benchmarks/evaluate_asr.dart';

void main() {
  test('按参考长度聚合 CER/WER，保留缺失时延且实测指标不补零', () {
    final report = evaluateAsrSamples([
      {
        'id': 'zh',
        'reference': '今天讨论项目',
        'hypothesis': '今天讨论项木',
        'keyFacts': ['项目'],
        'firstTextLatencyMs': 2000,
        'stableLatencyMs': 1000,
        'inputAudioMs': 5000,
        'inferenceMs': 2500,
      },
      {
        'id': 'en',
        'reference': 'Hello world again',
        'hypothesis': 'hello world',
        'metric': 'wer',
        'firstTextLatencyMs': 3000,
      },
    ]);
    expect(report['cer'], closeTo(1 / 6, 0.00001));
    expect(report['wer'], closeTo(1 / 3, 0.00001));
    expect(report['keyFactRecall'], 0);
    expect(report['firstTextLatencyMs'], {
      'count': 2,
      'p50': 2000.0,
      'p95': 3000.0,
    });
    expect(report['stableLatencyMs'], {
      'count': 1,
      'p50': 1000.0,
      'p95': 1000.0,
    });
    expect(report['inferenceToNewAudioRatio'], 0.5);
    expect(report['pairedInferenceCases'], 1);
  });

  test('静音误出字和没有测得的指标分别报告', () {
    final report = evaluateAsrSamples([
      {'id': 'silence', 'reference': '', 'hypothesis': '你好'},
    ]);
    expect(report['cer'], isNull);
    expect(report['characterErrors'], 2);
    expect(report['silenceWithTextCases'], 1);
    expect(report['firstTextLatencyMs'], {
      'count': 0,
      'p50': null,
      'p95': null,
    });
    expect(report['inferenceToNewAudioRatio'], isNull);
  });

  test('评分输入拒绝重复ID、虚构关键事实和负时延', () {
    final sample = {'id': 'one', 'reference': '会议', 'hypothesis': '会议'};
    expect(() => evaluateAsrSamples([sample, sample]), throwsFormatException);
    expect(
      () => evaluateAsrSamples([
        {
          ...sample,
          'keyFacts': ['不存在'],
        },
      ]),
      throwsFormatException,
    );
    expect(
      () => evaluateAsrSamples([
        {...sample, 'stableLatencyMs': -1},
      ]),
      throwsFormatException,
    );
  });
}
