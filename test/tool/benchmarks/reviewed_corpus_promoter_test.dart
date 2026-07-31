import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../tool/benchmarks/reviewed_corpus_promoter.dart';
import '../../../tool/benchmarks/whisper_quality_protocol.dart';

void main() {
  group('ReviewedCorpusPromoter', () {
    late _Fixture fixture;

    setUp(() async {
      fixture = await _Fixture.create();
    });

    tearDown(() async {
      await fixture.repository.delete(recursive: true);
    });

    test('只把完整人工复核结果晋升为绑定证明哈希的正式语料', () async {
      final result = await fixture.promote();
      final output =
          jsonDecode(await File(result.outputPath).readAsString())
              as Map<String, Object?>;
      final provenance = output['provenance']! as Map<String, Object?>;
      final samples = output['samples']! as List<Object?>;
      final firstSpeech = samples[40] as Map<String, Object?>;

      expect(result.corpusId, 'product-meeting-reviewed-v1');
      expect(result.sampleCount, 60);
      expect(output['deidentified'], isTrue);
      expect(output['evidenceClass'], whisperProductMeetingEvidenceClass);
      expect(
        provenance['reviewAttestationSha256'],
        result.reviewAttestationSha256,
      );
      expect(provenance['reviewedAtUtc'], '2026-07-31T10:30:00Z');
      expect(provenance, isNot(contains('reviewedByRole')));
      expect(firstSpeech['tags'], [
        whisperSpeechTag,
        whisperSpeechBoundaryStartTag,
      ]);
      expect(firstSpeech['expectedKeyFacts'], ['关键事实 01']);
      expect(
        samples.cast<Map<String, Object?>>().expand(
          (sample) => sample['tags']! as List<Object?>,
        ),
        isNot(contains('private-candidate')),
      );

      final corpus = await WhisperQualityCorpus.load(
        manifestPath: result.outputPath,
        repositoryRoot: fixture.repository.path,
        environment: fixture.environment,
        requiredEvidenceClass: whisperProductMeetingEvidenceClass,
      );
      expect(corpus.samples, hasLength(60));
      expect(
        corpus.provenance.reviewAttestationSha256,
        result.reviewAttestationSha256,
      );
      expect(corpus.provenance.reviewedAtUtc, '2026-07-31T10:30:00Z');
    });

    test('生成默认全部未批准且绑定候选哈希的人工复核模板', () async {
      final templatePath = p.join(
        fixture.repository.path,
        '.spike',
        'review',
        'attestation-template.private.json',
      );
      final result = await const ReviewedCorpusPromoter().writeReviewTemplate(
        candidateManifestPath: fixture.candidatePath,
        environmentPath: fixture.environmentPath,
        repositoryRoot: fixture.repository.path,
        outputPath: templatePath,
      );
      final template =
          jsonDecode(await File(templatePath).readAsString())
              as Map<String, Object?>;
      final samples = template['samples']! as List<Object?>;
      final first = samples.first! as Map<String, Object?>;

      expect(result.sampleCount, 60);
      expect(
        result.candidateManifestSha256,
        template['candidateManifestSha256'],
      );
      expect(template['deidentificationAttested'], isFalse);
      expect(template['reviewedByRole'], isEmpty);
      expect(first['candidateSuggestion'], whisperSilenceTag);
      expect(first['approved'], isFalse);
      expect(first['containsSensitiveData'], isNull);
      expect(first['reviewedClass'], isEmpty);
    });

    test('拒绝候选哈希不匹配以及缺少、多出或重复的样本', () async {
      await fixture.expectRejected(
        (review) =>
            review['candidateManifestSha256'] = List.filled(64, '0').join(),
        contains('SHA-256 不匹配'),
      );
      await fixture.expectRejected((review) {
        final samples = review['samples']! as List<Object?>;
        samples.removeLast();
      }, contains('完全一致'));
      await fixture.expectRejected((review) {
        final samples = review['samples']! as List<Object?>;
        samples.add({
          'id': 'extra',
          'approved': true,
          'containsSensitiveData': false,
          'reviewedClass': 'silence',
          'expectedKeyFacts': <String>[],
          'boundaryStart': false,
          'boundaryEnd': false,
        });
      }, contains('完全一致'));
      await fixture.expectRejected((review) {
        final samples = review['samples']! as List<Object?>;
        samples[1] = Map<String, Object?>.from(
          samples.first! as Map<String, Object?>,
        );
      }, contains('重复 sample id'));
    });

    test('从冗余候选中排除未批准或敏感样本后仍可达到正式门槛', () async {
      final surplus = await _Fixture.create(countPerClass: 21);
      try {
        final review = surplus._copyReview();
        final rejected = _reviewSample(review, 0)
          ..['approved'] = false
          ..['containsSensitiveData'] = true
          ..['reviewedClass'] = ''
          ..['expectedKeyFacts'] = <String>[]
          ..['boundaryStart'] = false
          ..['boundaryEnd'] = false;
        expect(rejected['approved'], isFalse);
        await surplus._writeReview(review);

        final result = await const ReviewedCorpusPromoter().promote(
          candidateManifestPath: surplus.candidatePath,
          reviewAttestationPath: surplus.reviewPath,
          environmentPath: surplus.environmentPath,
          repositoryRoot: surplus.repository.path,
          outputPath: surplus.outputPath,
        );

        expect(result.sampleCount, 62);
        final corpus = await WhisperQualityCorpus.load(
          manifestPath: result.outputPath,
          repositoryRoot: surplus.repository.path,
          environment: surplus.environment,
          requiredEvidenceClass: whisperProductMeetingEvidenceClass,
        );
        expect(corpus.samples, hasLength(62));
        expect(
          corpus.samples.where(
            (sample) => sample.tags.contains(whisperSilenceTag),
          ),
          hasLength(20),
        );
      } finally {
        await surplus.repository.delete(recursive: true);
      }
    });

    test('拒绝未完成确认、已批准敏感、无事实和不合法边界的人工结论', () async {
      await fixture.expectRejected((review) {
        _reviewSample(review, 0)['approved'] = null;
      }, contains('approved 必须是布尔值'));
      await fixture.expectRejected((review) {
        _reviewSample(review, 0)['containsSensitiveData'] = null;
      }, contains('containsSensitiveData 必须是布尔值'));
      await fixture.expectRejected((review) {
        _reviewSample(review, 0)['containsSensitiveData'] = true;
      }, contains('containsSensitiveData=false'));
      await fixture.expectRejected((review) {
        final sample = _reviewSample(review, 0)
          ..['approved'] = false
          ..['expectedKeyFacts'] = ['不应保留'];
        expect(sample['approved'], isFalse);
      }, contains('未批准时不得包含'));
      await fixture.expectRejected((review) {
        _reviewSample(review, 40)['expectedKeyFacts'] = <String>[];
      }, contains('至少包含一个关键事实'));
      await fixture.expectRejected((review) {
        _reviewSample(review, 0)['boundaryStart'] = true;
      }, contains('非 speech 标签不得'));
      await fixture.expectRejected((review) {
        _reviewSample(review, 40)['reviewedClass'] = 'maybe-speech';
      }, contains('reviewedClass 必须'));
      await fixture.expectRejected((review) {
        review['deidentificationAttested'] = false;
      }, contains('deidentificationAttested=true'));
    });

    test('最终协议继续拒绝不足 20 段事实语音或缺少首尾覆盖', () async {
      await fixture.expectProtocolRejected((review) {
        _reviewSample(review, 59)['reviewedClass'] = 'noise-only';
        _reviewSample(review, 59)['expectedKeyFacts'] = <String>[];
        _reviewSample(review, 59)['boundaryEnd'] = false;
      }, contains('至少包含 20 段'));
      await fixture.expectProtocolRejected((review) {
        for (var index = 40; index < 60; index++) {
          _reviewSample(review, index)['boundaryStart'] = false;
          _reviewSample(review, index)['boundaryEnd'] = false;
        }
      }, contains('语音起始和结束边界'));
    });

    test('拒绝覆盖既有输出以及仓库内非 .spike 输出', () async {
      final outsideSpike = p.join(fixture.repository.path, 'formal.json');
      await expectLater(
        fixture.promote(outputPath: outsideSpike),
        throwsA(
          isA<ReviewedCorpusPromotionException>().having(
            (error) => error.message,
            'message',
            contains('.spike'),
          ),
        ),
      );

      final output = fixture.outputPath;
      await File(output).writeAsString('{}');
      await expectLater(
        fixture.promote(),
        throwsA(
          isA<ReviewedCorpusPromotionException>().having(
            (error) => error.message,
            'message',
            contains('拒绝覆盖'),
          ),
        ),
      );
    });
  });
}

Map<String, Object?> _reviewSample(Map<String, Object?> review, int index) {
  return (review['samples']! as List<Object?>)[index]! as Map<String, Object?>;
}

final class _Fixture {
  _Fixture({
    required this.repository,
    required this.candidatePath,
    required this.reviewPath,
    required this.environmentPath,
    required this.outputPath,
    required this.environment,
    required this.validReview,
  });

  final Directory repository;
  final String candidatePath;
  final String reviewPath;
  final String environmentPath;
  final String outputPath;
  final Map<String, String> environment;
  final Map<String, Object?> validReview;

  static Future<_Fixture> create({int countPerClass = 20}) async {
    final repository = await Directory.systemTemp.createTemp(
      'meettrace-reviewed-corpus-',
    );
    final root = Directory(p.join(repository.path, '.spike', 'review'));
    final audioRoot = Directory(p.join(root.path, 'audio'));
    await audioRoot.create(recursive: true);
    final environment = <String, String>{};
    final candidateSamples = <Map<String, Object?>>[];
    final reviewSamples = <Map<String, Object?>>[];

    for (var index = 0; index < countPerClass * 3; index++) {
      final id = 'sample-${(index + 1).toString().padLeft(2, '0')}';
      final environmentName =
          'MEETTRACE_REVIEW_${(index + 1).toString().padLeft(2, '0')}';
      final pcm = Uint8List(3200);
      pcm[index % pcm.length] = index + 1;
      final audioPath = p.join(audioRoot.path, '$id.pcm');
      await File(audioPath).writeAsBytes(pcm);
      environment[environmentName] = audioPath;
      final classification = index < countPerClass
          ? whisperSilenceTag
          : index < countPerClass * 2
          ? whisperNoiseOnlyTag
          : whisperSpeechTag;
      candidateSamples.add({
        'id': id,
        'pathEnv': environmentName,
        'sha256': sha256.convert(pcm).toString(),
        'durationMs': 100,
        'tags': [classification, 'private-candidate'],
        'expectedKeyFacts': <String>[],
      });
      reviewSamples.add({
        'id': id,
        'approved': true,
        'containsSensitiveData': false,
        'reviewedClass': classification,
        'expectedKeyFacts': classification == whisperSpeechTag
            ? [
                '关键事实 '
                    '${(index - countPerClass * 2 + 1).toString().padLeft(2, '0')}',
              ]
            : <String>[],
        'boundaryStart': index == countPerClass * 2,
        'boundaryEnd': index == countPerClass * 3 - 1,
      });
    }

    final candidate = <String, Object?>{
      'schemaVersion': whisperQualityCorpusSchemaVersion,
      'id': 'private-candidate-v1',
      'deidentified': false,
      'evidenceClass': whisperSyntheticSmokeEvidenceClass,
      'provenance': {
        'sourceId': 'user-confirmed-private-source:test',
        'licenseId': 'user-confirmed-local-evaluation',
      },
      'audioFormat': {
        'encoding': whisperQualityEncoding,
        'sampleRateHz': whisperQualitySampleRateHz,
        'channels': whisperQualityChannelCount,
      },
      'samples': candidateSamples,
    };
    final candidatePath = p.join(root.path, 'candidate.private.json');
    final candidateJson =
        '${const JsonEncoder.withIndent('  ').convert(candidate)}\n';
    await File(candidatePath).writeAsString(candidateJson);
    final candidateHash = sha256.convert(utf8.encode(candidateJson)).toString();
    final validReview = <String, Object?>{
      'schemaVersion': reviewedCorpusAttestationSchemaVersion,
      'candidateManifestSha256': candidateHash,
      'corpusId': 'product-meeting-reviewed-v1',
      'reviewedAtUtc': '2026-07-31T10:30:00Z',
      'reviewedByRole': 'quality-owner',
      'deidentificationAttested': true,
      'samples': reviewSamples,
    };
    final reviewPath = p.join(root.path, 'review-attestation.private.json');
    final environmentPath = p.join(root.path, 'environment.private.json');
    await File(environmentPath).writeAsString(jsonEncode(environment));
    return _Fixture(
      repository: repository,
      candidatePath: candidatePath,
      reviewPath: reviewPath,
      environmentPath: environmentPath,
      outputPath: p.join(root.path, 'product-meeting.private.json'),
      environment: environment,
      validReview: validReview,
    );
  }

  Future<ReviewedCorpusPromotionResult> promote({String? outputPath}) async {
    await _writeReview(validReview);
    return const ReviewedCorpusPromoter().promote(
      candidateManifestPath: candidatePath,
      reviewAttestationPath: reviewPath,
      environmentPath: environmentPath,
      repositoryRoot: repository.path,
      outputPath: outputPath ?? this.outputPath,
    );
  }

  Future<void> expectRejected(
    void Function(Map<String, Object?> review) mutate,
    Matcher message,
  ) async {
    final review = _copyReview();
    mutate(review);
    await _writeReview(review);
    await expectLater(
      const ReviewedCorpusPromoter().promote(
        candidateManifestPath: candidatePath,
        reviewAttestationPath: reviewPath,
        environmentPath: environmentPath,
        repositoryRoot: repository.path,
        outputPath: outputPath,
      ),
      throwsA(
        isA<ReviewedCorpusPromotionException>().having(
          (error) => error.message,
          'message',
          message,
        ),
      ),
    );
  }

  Future<void> expectProtocolRejected(
    void Function(Map<String, Object?> review) mutate,
    Matcher message,
  ) async {
    final review = _copyReview();
    mutate(review);
    await _writeReview(review);
    await expectLater(
      const ReviewedCorpusPromoter().promote(
        candidateManifestPath: candidatePath,
        reviewAttestationPath: reviewPath,
        environmentPath: environmentPath,
        repositoryRoot: repository.path,
        outputPath: outputPath,
      ),
      throwsA(
        isA<WhisperQualityProtocolException>().having(
          (error) => error.message,
          'message',
          message,
        ),
      ),
    );
  }

  Map<String, Object?> _copyReview() {
    return jsonDecode(jsonEncode(validReview)) as Map<String, Object?>;
  }

  Future<void> _writeReview(Map<String, Object?> review) async {
    await File(
      reviewPath,
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(review)}\n');
  }
}
