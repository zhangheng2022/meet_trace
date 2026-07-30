import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../tool/benchmarks/generate_synthetic_noise_corpus.dart' as noise;

void main() {
  test('生成 20 段确定性且互不相同的非语音噪声', () {
    final first = noise.generateSyntheticNoiseSamples(durationSeconds: 1);
    final second = noise.generateSyntheticNoiseSamples(durationSeconds: 1);

    expect(first, hasLength(noise.syntheticNoiseSampleCount));
    expect(first.map((sample) => sample.id).toSet(), hasLength(20));
    expect(first.map((sample) => sample.kind).toSet(), {
      'white-noise',
      'fan-noise',
      'electrical-hum',
      'impulsive-clicks',
    });
    expect(first.map((sample) => sample.pcm16le.length).toSet(), {32000});
    expect(
      first.map((sample) => sha256.convert(sample.pcm16le).toString()).toSet(),
      hasLength(20),
    );
    expect(
      [for (var index = 0; index < first.length; index++) first[index].pcm16le],
      [
        for (var index = 0; index < second.length; index++)
          second[index].pcm16le,
      ],
    );
  });

  test('所有噪声均非静音、保持在 PCM16 范围且峰值匹配标记电平', () {
    final generated = noise.generateSyntheticNoiseSamples(durationSeconds: 1);

    for (final sample in generated) {
      final values = _decode(sample.pcm16le);
      final peak = values.fold<int>(
        0,
        (value, next) => math.max(value, next.abs()),
      );
      final rms = math.sqrt(
        values.fold<double>(0, (total, value) => total + value * value) /
            values.length,
      );
      final peakDbfs = 20 * math.log(peak / 32767) / math.ln10;

      expect(peak, greaterThan(0), reason: sample.id);
      expect(peak, lessThanOrEqualTo(32767), reason: sample.id);
      expect(rms, greaterThan(0.1), reason: sample.id);
      expect(
        (peakDbfs - sample.levelDbfs).abs(),
        lessThan(3),
        reason: sample.id,
      );
    }
  });

  test('拒绝超出质量执行器上限的时长', () {
    expect(
      () => noise.generateSyntheticNoiseSamples(durationSeconds: 0),
      throwsA(isA<noise.SyntheticNoiseCorpusException>()),
    );
    expect(
      () => noise.generateSyntheticNoiseSamples(durationSeconds: 16),
      throwsA(isA<noise.SyntheticNoiseCorpusException>()),
    );
  });

  test('文件入口只写入 .spike 并生成完整的私有输入契约', () async {
    final repositoryRoot = await Directory.systemTemp.createTemp(
      'meettrace-synthetic-noise-',
    );
    addTearDown(() => repositoryRoot.delete(recursive: true));

    await noise.main([
      '--repository-root',
      repositoryRoot.path,
      '--output-directory',
      '.spike/corpus',
      '--duration-seconds',
      '1',
    ]);

    final outputRoot = p.join(repositoryRoot.path, '.spike', 'corpus');
    final manifest =
        jsonDecode(
              await File(
                p.join(outputRoot, 'manifest.private.json'),
              ).readAsString(),
            )
            as Map<String, Object?>;
    final environment =
        jsonDecode(
              await File(
                p.join(outputRoot, 'environment.private.json'),
              ).readAsString(),
            )
            as Map<String, Object?>;

    expect(manifest['evidenceClass'], 'synthetic-smoke');
    expect(manifest['deidentified'], isTrue);
    expect(
      manifest['samples'],
      isA<List<Object?>>().having(
        (samples) => samples.length,
        'length',
        noise.syntheticNoiseSampleCount,
      ),
    );
    expect(environment, hasLength(noise.syntheticNoiseSampleCount));
    expect(
      Directory(p.join(outputRoot, 'audio')).listSync().whereType<File>(),
      hasLength(noise.syntheticNoiseSampleCount),
    );

    await expectLater(
      noise.main([
        '--repository-root',
        repositoryRoot.path,
        '--output-directory',
        p.join(repositoryRoot.path, 'outside'),
      ]),
      throwsA(isA<noise.SyntheticNoiseCorpusException>()),
    );
  });
}

List<int> _decode(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return [
    for (var offset = 0; offset < bytes.length; offset += 2)
      data.getInt16(offset, Endian.little),
  ];
}
