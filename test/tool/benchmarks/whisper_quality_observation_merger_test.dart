import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../tool/benchmarks/whisper_quality_observation_merger.dart';

void main() {
  group('WhisperQualityObservationMerger', () {
    late _Fixture fixture;

    setUp(() async {
      fixture = await _Fixture.create();
    });

    tearDown(() async {
      await fixture.repository.delete(recursive: true);
    });

    test('合并完整组合并重写 transcriptRef、绑定每批哈希', () async {
      final result = await fixture.merge();
      final merged =
          jsonDecode(await File(result.outputPath).readAsString())
              as Map<String, Object?>;
      final execution = merged['execution']! as Map<String, Object?>;
      final observations = merged['observations']! as List<Object?>;
      final evidence = execution['mergedBatchEvidence']! as List<Object?>;

      expect(result.batchCount, 2);
      expect(result.combinationCount, 2);
      expect(result.observationCount, 4);
      expect(result.pipelineIds, ['fixed-window-v1', 'vad-segmented-v1']);
      expect(execution['pipelineIds'], result.pipelineIds);
      expect(evidence, hasLength(2));
      expect(
        (evidence.first! as Map<String, Object?>)['sha256'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
      expect(
        (observations.first! as Map<String, Object?>)['transcriptRef'],
        'batches/base/transcripts/transcript-0.json',
      );
    });

    test('拒绝批次 corpus 证明或设备执行口径不一致', () async {
      await fixture.expectRejected((batches) {
        _execution(batches[1])['corpusManifestSha256'] = List.filled(
          64,
          '0',
        ).join();
      }, contains('corpus 证明'));
      await fixture.expectRejected((batches) {
        _execution(batches[1])['threadCount'] = 4;
      }, contains('threadCount'));
    });

    test('拒绝组合缺样本、重复观测和 pipeline 声明漂移', () async {
      await fixture.expectRejected((batches) {
        _observations(batches[0]).removeLast();
      }, contains('未完整覆盖'));
      await fixture.expectRejected((batches) {
        final duplicate = Map<String, Object?>.from(
          _observations(batches[0]).first,
        );
        _observations(batches[1]).add(duplicate);
      }, contains('重复观测'));
      await fixture.expectRejected((batches) {
        _execution(batches[0])['pipelineIds'] = ['vad-segmented-v1'];
      }, contains('pipeline 声明'));
    });

    test('拒绝不存在、绝对路径或越界 transcriptRef', () async {
      await fixture.expectRejected((batches) {
        _observations(batches[0]).first['transcriptRef'] = 'missing.json';
      }, contains('不存在或越过'));
      await fixture.expectRejected((batches) {
        _observations(batches[0]).first['transcriptRef'] = p.join(
          fixture.repository.path,
          'absolute.json',
        );
      }, contains('绝对路径'));
      await fixture.expectRejected((batches) {
        _observations(batches[0]).first['transcriptSha256'] = List.filled(
          64,
          '0',
        ).join();
      }, contains('SHA-256 不匹配'));
    });

    test('overwrite 只在新合并结果完成后替换旧输出', () async {
      await File(fixture.outputPath).writeAsString('旧的完整输出');

      final result = await const WhisperQualityObservationMerger().merge(
        corpusManifestPath: fixture.manifestPath,
        inputPaths: fixture.batchPaths,
        repositoryRoot: fixture.repository.path,
        outputPath: fixture.outputPath,
        overwrite: true,
      );
      final merged =
          jsonDecode(await File(result.outputPath).readAsString())
              as Map<String, Object?>;

      expect(merged['schemaVersion'], 4);
      expect(merged['observations'], hasLength(4));
      expect(
        fixture.repository
            .listSync(recursive: true)
            .whereType<Directory>()
            .where(
              (directory) => p
                  .basename(directory.path)
                  .startsWith('.meettrace-observation-merge-'),
            ),
        isEmpty,
      );
    });
  });
}

Map<String, Object?> _execution(Map<String, Object?> batch) {
  return batch['execution']! as Map<String, Object?>;
}

List<Map<String, Object?>> _observations(Map<String, Object?> batch) {
  return (batch['observations']! as List<Object?>).cast<Map<String, Object?>>();
}

final class _Fixture {
  _Fixture({
    required this.repository,
    required this.manifestPath,
    required this.outputPath,
    required this.batchPaths,
    required this.validBatches,
  });

  final Directory repository;
  final String manifestPath;
  final String outputPath;
  final List<String> batchPaths;
  final List<Map<String, Object?>> validBatches;

  static Future<_Fixture> create() async {
    final repository = await Directory.systemTemp.createTemp(
      'meettrace-observation-merge-',
    );
    final spike = Directory(p.join(repository.path, '.spike', 'matrix'));
    await spike.create(recursive: true);
    final manifest = <String, Object?>{
      'schemaVersion': 2,
      'id': 'corpus-v1',
      'deidentified': false,
      'evidenceClass': 'synthetic-smoke',
      'provenance': {'sourceId': 'test', 'licenseId': 'test'},
      'audioFormat': {
        'encoding': 'pcm16le',
        'sampleRateHz': 16000,
        'channels': 1,
      },
      'samples': [
        {'id': 'sample-a'},
        {'id': 'sample-b'},
      ],
    };
    final manifestPath = p.join(spike.path, 'manifest.private.json');
    final manifestJson =
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
    await File(manifestPath).writeAsString(manifestJson);
    final manifestHash = sha256.convert(utf8.encode(manifestJson)).toString();
    final batchPaths = <String>[];
    final batches = <Map<String, Object?>>[];
    for (var batchIndex = 0; batchIndex < 2; batchIndex++) {
      final batchRoot = Directory(
        p.join(spike.path, 'batches', batchIndex == 0 ? 'base' : 'small'),
      );
      final transcripts = Directory(p.join(batchRoot.path, 'transcripts'));
      await transcripts.create(recursive: true);
      final pipelineId = batchIndex == 0
          ? 'fixed-window-v1'
          : 'vad-segmented-v1';
      final modelId = batchIndex == 0 ? 'base' : 'small';
      final observations = <Map<String, Object?>>[];
      for (var sampleIndex = 0; sampleIndex < 2; sampleIndex++) {
        final transcriptPath = p.join(
          transcripts.path,
          'transcript-$sampleIndex.json',
        );
        const transcript = '{"text":"private"}';
        await File(transcriptPath).writeAsString(transcript);
        observations.add({
          'sampleId': sampleIndex == 0 ? 'sample-a' : 'sample-b',
          'modelId': modelId,
          'modelVersion': 'v1',
          'profileId': 'baseline',
          'pipelineId': pipelineId,
          'deviceId': 'android-emulator-x86_64-api-36',
          'transcriptRef': 'transcripts/transcript-$sampleIndex.json',
          'transcriptSha256': sha256
              .convert(utf8.encode(transcript))
              .toString(),
        });
      }
      final batch = <String, Object?>{
        'schemaVersion': 4,
        'execution': {
          'capturedAtUtc': '2026-07-31T00:00:00Z',
          'platform': 'android-emulator',
          'deviceId': 'android-emulator-x86_64-api-36',
          'abi': 'x86_64',
          'apiLevel': 36,
          'threadCount': 2,
          'windowDurationMs': 2000,
          'fixedWindowCaptureLatencyMs': 2000,
          'vadStabilityMarginMs': 1000,
          'pipelineIds': [pipelineId],
          'corpusId': 'corpus-v1',
          'corpusDeidentified': false,
          'corpusEvidenceClass': 'synthetic-smoke',
          'corpusManifestSha256': manifestHash,
          'energyStatus': 'not_collected',
          'thermalStatus': 'not_collected',
        },
        'observations': observations,
      };
      final batchPath = p.join(batchRoot.path, 'raw.private.json');
      await File(batchPath).writeAsString(jsonEncode(batch));
      batchPaths.add(batchPath);
      batches.add(batch);
    }
    return _Fixture(
      repository: repository,
      manifestPath: manifestPath,
      outputPath: p.join(spike.path, 'raw-observations.private.json'),
      batchPaths: batchPaths,
      validBatches: batches,
    );
  }

  Future<WhisperQualityObservationMergeResult> merge() {
    return const WhisperQualityObservationMerger().merge(
      corpusManifestPath: manifestPath,
      inputPaths: batchPaths,
      repositoryRoot: repository.path,
      outputPath: outputPath,
    );
  }

  Future<void> expectRejected(
    void Function(List<Map<String, Object?>> batches) mutate,
    Matcher message,
  ) async {
    final batches = (jsonDecode(jsonEncode(validBatches)) as List<Object?>)
        .cast<Map<String, Object?>>();
    mutate(batches);
    for (var index = 0; index < batches.length; index++) {
      await File(batchPaths[index]).writeAsString(jsonEncode(batches[index]));
    }
    await expectLater(
      const WhisperQualityObservationMerger().merge(
        corpusManifestPath: manifestPath,
        inputPaths: batchPaths,
        repositoryRoot: repository.path,
        outputPath: outputPath,
      ),
      throwsA(
        isA<WhisperQualityObservationMergeException>().having(
          (error) => error.message,
          'message',
          message,
        ),
      ),
    );
  }
}
