import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../tool/benchmarks/whisper_quality_protocol.dart';

void main() {
  group('WhisperQualityCorpus', () {
    late Directory repository;
    late Directory external;

    setUp(() async {
      repository = await Directory.systemTemp.createTemp(
        'meettrace-quality-repo-',
      );
      external = await Directory.systemTemp.createTemp(
        'meettrace-quality-corpus-',
      );
    });

    tearDown(() async {
      await repository.delete(recursive: true);
      await external.delete(recursive: true);
    });

    test('校验 20 段仓库外 PCM 的哈希、格式和时长', () async {
      final fixture = await _fixture(
        repository: repository,
        audioRoot: external,
      );

      final corpus = await WhisperQualityCorpus.load(
        manifestPath: fixture.manifestPath,
        repositoryRoot: repository.path,
        environment: fixture.environment,
      );

      expect(corpus.id, 'deidentified-v1');
      expect(corpus.samples, hasLength(20));
      expect(corpus.samples.first.durationMs, 100);
      expect(corpus.samples.first.sourcePath, fixture.firstAudioPath);
    });

    test('拒绝仓库内非 .spike 音频和不匹配的哈希', () async {
      final insideRoot = Directory(p.join(repository.path, 'private'));
      final inside = await _fixture(
        repository: repository,
        audioRoot: insideRoot,
      );
      expect(
        () => WhisperQualityCorpus.load(
          manifestPath: inside.manifestPath,
          repositoryRoot: repository.path,
          environment: inside.environment,
        ),
        throwsA(isA<WhisperQualityProtocolException>()),
      );

      final outside = await _fixture(
        repository: repository,
        audioRoot: external,
        corruptFirstHash: true,
      );
      expect(
        () => WhisperQualityCorpus.load(
          manifestPath: outside.manifestPath,
          repositoryRoot: repository.path,
          environment: outside.environment,
        ),
        throwsA(isA<WhisperQualityProtocolException>()),
      );
    });

    test('允许已忽略的 .spike 音频', () async {
      final spike = Directory(p.join(repository.path, '.spike', 'corpus'));
      final fixture = await _fixture(repository: repository, audioRoot: spike);

      final corpus = await WhisperQualityCorpus.load(
        manifestPath: fixture.manifestPath,
        repositoryRoot: repository.path,
        environment: fixture.environment,
      );

      expect(corpus.samples, hasLength(20));
    });
  });

  group('PCM 与关键事实', () {
    test('按固定窗口解码 PCM16LE 并保留尾窗', () {
      final data = ByteData(10);
      data
        ..setInt16(0, -32768, Endian.little)
        ..setInt16(2, -16384, Endian.little)
        ..setInt16(4, 0, Endian.little)
        ..setInt16(6, 16384, Endian.little)
        ..setInt16(8, 32767, Endian.little);

      final windows = decodePcm16LeWindows(
        data.buffer.asUint8List(),
        windowSamples: 3,
      ).toList();

      expect(windows, hasLength(2));
      expect(windows.first, orderedEquals(<double>[-1, -0.5, 0]));
      expect(windows.last[0], 0.5);
      expect(windows.last[1], closeTo(0.999969, 0.000001));
    });

    test('关键事实匹配忽略大小写、空格和常用标点', () {
      expect(
        recognizeExpectedKeyFacts(
          transcript: '项目 Alpha，将在 Friday 发布。',
          expectedKeyFacts: const ['项目Alpha', 'friday', '不存在', '。。。'],
        ),
        const ['项目Alpha', 'friday'],
      );
    });
  });
}

Future<
  ({
    String manifestPath,
    Map<String, String> environment,
    String firstAudioPath,
  })
>
_fixture({
  required Directory repository,
  required Directory audioRoot,
  bool corruptFirstHash = false,
}) async {
  await audioRoot.create(recursive: true);
  final samples = <Map<String, Object?>>[];
  final environment = <String, String>{};
  var firstAudioPath = '';
  for (var index = 0; index < 20; index++) {
    final bytes = Uint8List(3200);
    final path = p.join(audioRoot.path, 'sample-$index.pcm');
    await File(path).writeAsBytes(bytes);
    if (index == 0) {
      firstAudioPath = path;
    }
    final env = 'MEETTRACE_TEST_SAMPLE_$index';
    environment[env] = path;
    samples.add({
      'id': 'sample-$index',
      'pathEnv': env,
      'sha256': index == 0 && corruptFirstHash
          ? '0' * 64
          : sha256.convert(bytes).toString(),
      'durationMs': 100,
      'tags': const ['speech', 'zh'],
      'expectedKeyFacts': const <String>[],
    });
  }
  final manifestFile = File(p.join(repository.path, 'corpus.json'));
  await manifestFile.writeAsString(
    jsonEncode({
      'schemaVersion': 1,
      'id': 'deidentified-v1',
      'deidentified': true,
      'audioFormat': const {
        'encoding': 'pcm16le',
        'sampleRateHz': 16000,
        'channels': 1,
      },
      'samples': samples,
    }),
  );
  return (
    manifestPath: manifestFile.path,
    environment: environment,
    firstAudioPath: firstAudioPath,
  );
}
