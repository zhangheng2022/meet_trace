import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'whisper_quality_protocol.dart';

const syntheticNoiseCorpusVersion = 'deterministic-nonspeech-v1';
const syntheticNoiseSampleCount = 20;
const _defaultDurationSeconds = 3;
const _noiseLevelsDbfs = [-45.0, -35.0, -25.0, -18.0, -12.0];

final class SyntheticNoiseCorpusException implements Exception {
  const SyntheticNoiseCorpusException(this.message);

  final String message;

  @override
  String toString() => 'SyntheticNoiseCorpusException: $message';
}

final class SyntheticNoiseSample {
  const SyntheticNoiseSample({
    required this.id,
    required this.kind,
    required this.levelDbfs,
    required this.pcm16le,
  });

  final String id;
  final String kind;
  final double levelDbfs;
  final Uint8List pcm16le;
}

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final repositoryRoot = p.normalize(p.absolute(options.repositoryRoot));
  final outputRoot = p.normalize(
    p.isAbsolute(options.outputDirectory)
        ? options.outputDirectory
        : p.join(repositoryRoot, options.outputDirectory),
  );
  final allowedRoot = p.join(repositoryRoot, '.spike');
  if (!_isWithin(allowedRoot, outputRoot) || outputRoot == allowedRoot) {
    throw const SyntheticNoiseCorpusException('输出目录必须位于仓库 .spike 的子目录中');
  }

  final audioDirectory = Directory(p.join(outputRoot, 'audio'));
  await audioDirectory.create(recursive: true);
  final generated = generateSyntheticNoiseSamples(
    durationSeconds: options.durationSeconds,
  );
  final environment = <String, String>{};
  final samples = <Map<String, Object?>>[];
  for (final entry in generated.indexed) {
    final index = entry.$1;
    final sample = entry.$2;
    final fileName = 'sample-${index.toString().padLeft(2, '0')}.pcm';
    final audioPath = p.join(audioDirectory.path, fileName);
    await File(audioPath).writeAsBytes(sample.pcm16le, flush: true);
    final environmentName =
        'MEETTRACE_SYNTH_NOISE_${index.toString().padLeft(2, '0')}';
    environment[environmentName] = audioPath;
    samples.add({
      'id': sample.id,
      'pathEnv': environmentName,
      'sha256': sha256.convert(sample.pcm16le).toString(),
      'durationMs': options.durationSeconds * 1000,
      'tags': [
        'noise-only',
        'synthetic',
        sample.kind,
        'level-${sample.levelDbfs.abs().round()}dbfs',
      ],
      'expectedKeyFacts': const <String>[],
    });
  }

  final corpusId =
      'synthetic-$syntheticNoiseCorpusVersion-'
      '${options.durationSeconds}s';
  final manifest = {
    'schemaVersion': whisperQualityCorpusSchemaVersion,
    'id': corpusId,
    'deidentified': true,
    'evidenceClass': whisperSyntheticSmokeEvidenceClass,
    'provenance': {
      'sourceId': 'generated:$syntheticNoiseCorpusVersion',
      'licenseId': 'not-applicable',
    },
    'audioFormat': const {
      'encoding': whisperQualityEncoding,
      'sampleRateHz': whisperQualitySampleRateHz,
      'channels': whisperQualityChannelCount,
    },
    'samples': samples,
  };
  await _writeJson(File(p.join(outputRoot, 'manifest.private.json')), manifest);
  await _writeJson(
    File(p.join(outputRoot, 'environment.private.json')),
    environment,
  );
  stdout.writeln(
    'Synthetic noise corpus prepared: '
    '${generated.length} samples ($corpusId)',
  );
}

List<SyntheticNoiseSample> generateSyntheticNoiseSamples({
  int durationSeconds = _defaultDurationSeconds,
}) {
  if (durationSeconds < 1 || durationSeconds > 15) {
    throw const SyntheticNoiseCorpusException('durationSeconds 必须在 1 到 15 之间');
  }
  final generators = <(String, Float64List Function(int, double, int))>[
    ('white-noise', _whiteNoise),
    ('fan-noise', _fanNoise),
    ('electrical-hum', _electricalHum),
    ('impulsive-clicks', _impulsiveClicks),
  ];
  final sampleLength = durationSeconds * whisperQualitySampleRateHz;
  final result = <SyntheticNoiseSample>[];
  for (var kindIndex = 0; kindIndex < generators.length; kindIndex++) {
    final generator = generators[kindIndex];
    for (
      var levelIndex = 0;
      levelIndex < _noiseLevelsDbfs.length;
      levelIndex++
    ) {
      final levelDbfs = _noiseLevelsDbfs[levelIndex];
      final seed = 0x4d545243 + kindIndex * 101 + levelIndex * 7919;
      final samples = generator.$2(sampleLength, levelDbfs, seed);
      result.add(
        SyntheticNoiseSample(
          id:
              'synthetic-${generator.$1}-'
              '${levelDbfs.abs().round()}dbfs',
          kind: generator.$1,
          levelDbfs: levelDbfs,
          pcm16le: _encodePcm16Le(samples),
        ),
      );
    }
  }
  return List.unmodifiable(result);
}

Float64List _whiteNoise(int length, double levelDbfs, int seed) {
  final random = _DeterministicRandom(seed);
  final gain = _dbToLinear(levelDbfs);
  return Float64List.fromList([
    for (var index = 0; index < length; index++) random.nextSignedUnit() * gain,
  ]);
}

Float64List _fanNoise(int length, double levelDbfs, int seed) {
  final random = _DeterministicRandom(seed);
  final gain = _dbToLinear(levelDbfs);
  final output = Float64List(length);
  var lowPassed = 0.0;
  var slowModulation = 0.0;
  for (var index = 0; index < length; index++) {
    lowPassed = lowPassed * 0.93 + random.nextSignedUnit() * 0.07;
    slowModulation =
        0.8 +
        0.2 * math.sin(2 * math.pi * 0.7 * index / whisperQualitySampleRateHz);
    output[index] = lowPassed * slowModulation * gain * 2.4;
  }
  return output;
}

Float64List _electricalHum(int length, double levelDbfs, int seed) {
  final gain = _dbToLinear(levelDbfs);
  final frequency = seed.isEven ? 50.0 : 60.0;
  final phase = (seed % 360) * math.pi / 180;
  return Float64List.fromList([
    for (var index = 0; index < length; index++)
      gain *
          (math.sin(
                2 * math.pi * frequency * index / whisperQualitySampleRateHz +
                    phase,
              ) +
              0.35 *
                  math.sin(
                    2 *
                            math.pi *
                            frequency *
                            2 *
                            index /
                            whisperQualitySampleRateHz +
                        phase / 2,
                  )) /
          1.35,
  ]);
}

Float64List _impulsiveClicks(int length, double levelDbfs, int seed) {
  final random = _DeterministicRandom(seed);
  final gain = _dbToLinear(levelDbfs);
  final output = Float64List(length);
  final interval = whisperQualitySampleRateHz ~/ (3 + seed % 4);
  final clickLength = whisperQualitySampleRateHz ~/ 80;
  for (var index = 0; index < length; index++) {
    final withinClick = index % interval;
    final background = random.nextSignedUnit() * gain * 0.04;
    if (withinClick < clickLength) {
      final envelope = math.exp(-withinClick / (clickLength / 5));
      final click =
          math.sin(
            2 * math.pi * 1800 * withinClick / whisperQualitySampleRateHz,
          ) *
          envelope *
          gain;
      output[index] = background + click;
    } else {
      output[index] = background;
    }
  }
  return output;
}

Uint8List _encodePcm16Le(Float64List samples) {
  final bytes = Uint8List(samples.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < samples.length; index++) {
    final clamped = samples[index].clamp(-1.0, 1.0);
    data.setInt16(
      index * 2,
      (clamped * 32767).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  return bytes;
}

double _dbToLinear(double dbfs) => math.pow(10, dbfs / 20).toDouble();

final class _DeterministicRandom {
  _DeterministicRandom(this._state);

  int _state;

  double nextSignedUnit() {
    _state = (1664525 * _state + 1013904223) & 0xffffffff;
    return _state / 0xffffffff * 2 - 1;
  }
}

Future<void> _writeJson(File file, Object value) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(value),
    flush: true,
  );
}

bool _isWithin(String parent, String child) {
  final relative = p.relative(p.normalize(child), from: p.normalize(parent));
  return relative != '..' && !relative.startsWith('..${p.separator}');
}

final class _Options {
  const _Options({
    required this.repositoryRoot,
    required this.outputDirectory,
    required this.durationSeconds,
  });

  factory _Options.parse(List<String> arguments) {
    String? valueOf(String name) {
      final index = arguments.indexOf(name);
      if (index < 0 || index + 1 >= arguments.length) {
        return null;
      }
      return arguments[index + 1];
    }

    final durationSeconds = int.tryParse(
      valueOf('--duration-seconds') ?? '$_defaultDurationSeconds',
    );
    if (durationSeconds == null ||
        durationSeconds < 1 ||
        durationSeconds > 15) {
      throw const SyntheticNoiseCorpusException(
        '--duration-seconds 必须为 1 到 15 的整数',
      );
    }
    return _Options(
      repositoryRoot: valueOf('--repository-root') ?? Directory.current.path,
      outputDirectory:
          valueOf('--output-directory') ?? '.spike/corpora/synthetic-noise-v1',
      durationSeconds: durationSeconds,
    );
  }

  final String repositoryRoot;
  final String outputDirectory;
  final int durationSeconds;
}
