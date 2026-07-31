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

    test('校验正式语料的静音、噪声、事实和语音首尾覆盖', () async {
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
      expect(corpus.evidenceClass, 'product-meeting');
      expect(corpus.provenance.sourceId, 'private-deidentified-meetings');
      expect(corpus.samples, hasLength(60));
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

      expect(corpus.samples, hasLength(60));
    });

    test('正式质量入口拒绝公开回归或合成冒烟语料', () async {
      final fixture = await _fixture(
        repository: repository,
        audioRoot: external,
        evidenceClass: 'synthetic-smoke',
      );

      expect(
        () => WhisperQualityCorpus.load(
          manifestPath: fixture.manifestPath,
          repositoryRoot: repository.path,
          environment: fixture.environment,
          requiredEvidenceClass: 'product-meeting',
        ),
        throwsA(isA<WhisperQualityProtocolException>()),
      );
    });

    test('公开许可回归语料不伪装为已去敏产品会议', () async {
      final fixture = await _fixture(
        repository: repository,
        audioRoot: external,
        evidenceClass: 'public-regression',
        deidentified: false,
      );

      final corpus = await WhisperQualityCorpus.load(
        manifestPath: fixture.manifestPath,
        repositoryRoot: repository.path,
        environment: fixture.environment,
      );

      expect(corpus.deidentified, isFalse);
      expect(corpus.evidenceClass, 'public-regression');
    });

    test('产品会议语料必须明确声明已去敏', () async {
      final fixture = await _fixture(
        repository: repository,
        audioRoot: external,
        deidentified: false,
      );

      expect(
        () => WhisperQualityCorpus.load(
          manifestPath: fixture.manifestPath,
          repositoryRoot: repository.path,
          environment: fixture.environment,
        ),
        throwsA(isA<WhisperQualityProtocolException>()),
      );
    });

    test('产品会议语料拒绝不足的门禁覆盖和无效关键事实', () async {
      final incomplete = await _fixture(
        repository: repository,
        audioRoot: external,
        incompleteProductCoverage: true,
      );
      expect(
        () => WhisperQualityCorpus.load(
          manifestPath: incomplete.manifestPath,
          repositoryRoot: repository.path,
          environment: incomplete.environment,
        ),
        throwsA(isA<WhisperQualityProtocolException>()),
      );

      final invalidFact = await _fixture(
        repository: repository,
        audioRoot: external,
        invalidFirstSpeechFact: true,
      );
      expect(
        () => WhisperQualityCorpus.load(
          manifestPath: invalidFact.manifestPath,
          repositoryRoot: repository.path,
          environment: invalidFact.environment,
        ),
        throwsA(isA<WhisperQualityProtocolException>()),
      );
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

  group('Android 设备评测清单', () {
    test('旧清单默认使用完整 ASR 模式', () {
      final run = WhisperQualityDeviceRun.fromJson(
        _deviceRunJson(
          models: [_deviceModelJson()],
          pipelineIds: const [
            whisperFixedWindowPipelineId,
            whisperVadSegmentedPipelineId,
          ],
        ),
      );

      expect(run.mode, whisperAsrQualityRunMode);
      expect(run.isVadPreflight, isFalse);
      expect(run.evaluationRunCount, 2);
    });

    test('VAD 预检不加载 ASR 模型并按管线计算观测数', () {
      final run = WhisperQualityDeviceRun.fromJson(
        _deviceRunJson(
          mode: whisperVadPreflightRunMode,
          models: const [],
          pipelineIds: const [
            whisperVadSegmentedPipelineId,
            whisperVadRecallCandidatePipelineId,
          ],
        ),
      );

      expect(run.isVadPreflight, isTrue);
      expect(run.models, isEmpty);
      expect(run.evaluationRunCount, 2);
    });

    test('VAD 预检拒绝固定窗口或 ASR 模型', () {
      expect(
        () => WhisperQualityDeviceRun.fromJson(
          _deviceRunJson(
            mode: whisperVadPreflightRunMode,
            models: const [],
            pipelineIds: const [whisperFixedWindowPipelineId],
          ),
        ),
        throwsA(isA<WhisperQualityProtocolException>()),
      );
      expect(
        () => WhisperQualityDeviceRun.fromJson(
          _deviceRunJson(
            mode: whisperVadPreflightRunMode,
            models: [_deviceModelJson()],
            pipelineIds: const [whisperVadSegmentedPipelineId],
          ),
        ),
        throwsA(isA<WhisperQualityProtocolException>()),
      );
    });
  });
}

Map<String, Object?> _deviceRunJson({
  String? mode,
  required List<Map<String, Object?>> models,
  required List<String> pipelineIds,
}) {
  final bytes = Uint8List(3200);
  return {
    'schemaVersion': whisperQualityDeviceManifestSchemaVersion,
    'mode': ?mode,
    'corpusId': 'corpus-v1',
    'deviceId': 'android-emulator-x86_64-api-36',
    'threadCount': 2,
    'samples': [
      {
        'id': 'sample-1',
        'path': '/data/local/tmp/sample-1.pcm',
        'sha256': sha256.convert(bytes).toString(),
        'bytes': bytes.length,
        'durationMs': 100,
        'expectedKeyFacts': const <String>[],
      },
    ],
    'models': models,
    'pipelineIds': pipelineIds,
  };
}

Map<String, Object?> _deviceModelJson() => {
  'modelId': 'whisper-cpp-base-q5_1-v1.9.1',
  'modelVersion': 'v1.9.1-q5_1',
  'source': 'bundledBase',
  'path': null,
  'profileIds': const ['final-beam-quality-v1'],
};

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
  String evidenceClass = 'product-meeting',
  bool deidentified = true,
  bool incompleteProductCoverage = false,
  bool invalidFirstSpeechFact = false,
}) async {
  await audioRoot.create(recursive: true);
  final samples = <Map<String, Object?>>[];
  final environment = <String, String>{};
  var firstAudioPath = '';
  final sampleCount =
      evidenceClass == whisperProductMeetingEvidenceClass &&
          !incompleteProductCoverage
      ? 60
      : 20;
  for (var index = 0; index < sampleCount; index++) {
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
      'tags': [
        if (evidenceClass == whisperProductMeetingEvidenceClass &&
            !incompleteProductCoverage &&
            index < 20)
          whisperSilenceTag
        else if (evidenceClass == whisperProductMeetingEvidenceClass &&
            !incompleteProductCoverage &&
            index < 40)
          whisperNoiseOnlyTag
        else ...[
          whisperSpeechTag,
          if (index == 40) whisperSpeechBoundaryStartTag,
          if (index == sampleCount - 1) whisperSpeechBoundaryEndTag,
        ],
        'zh',
      ],
      'expectedKeyFacts': [
        if (evidenceClass == whisperProductMeetingEvidenceClass &&
            !incompleteProductCoverage &&
            index >= 40)
          if (invalidFirstSpeechFact && index == 40) '。。。' else '事实-$index',
      ],
    });
  }
  final manifestFile = File(p.join(repository.path, 'corpus.json'));
  await manifestFile.writeAsString(
    jsonEncode({
      'schemaVersion': 2,
      'id': 'deidentified-v1',
      'deidentified': deidentified,
      'evidenceClass': evidenceClass,
      'provenance': const {
        'sourceId': 'private-deidentified-meetings',
        'licenseId': 'internal-consented',
      },
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
