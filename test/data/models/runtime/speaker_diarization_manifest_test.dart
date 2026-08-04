import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/models/runtime/speaker_diarization_manifest.dart';
import 'package:meettrace/domain/models/model_manifest.dart';
import 'package:path/path.dart' as p;

void main() {
  late Map<String, dynamic> source;

  setUp(() {
    source =
        jsonDecode(
              File(
                p.join(
                  Directory.current.path,
                  'assets',
                  'models',
                  'speaker-diarization-manifest.json',
                ),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  test('固定 Manifest 只安装 INT8 分割模型、许可和嵌入模型', () {
    final manifest = const SpeakerDiarizationManifestParser().parse(
      jsonEncode(source),
    );

    expect(manifest.requiredBytes, speakerDiarizationDownloadBytes);
    expect(manifest.downloadManifest.files.map((file) => file.path), [
      speakerSegmentationArchivePath,
      '.downloads/$speakerEmbeddingModelFileName',
    ]);
    expect(manifest.installationManifest.files.map((file) => file.path), [
      speakerSegmentationModelPath,
      'segmentation/LICENSE',
      speakerEmbeddingModelPath,
    ]);
    expect(
      manifest.installationManifest.files,
      isNot(
        contains(
          predicate<ModelManifestFile>(
            (file) => file.path.endsWith('/model.onnx'),
          ),
        ),
      ),
    );
    expect(manifest.inference.sampleRate, speakerDiarizationSampleRate);
    expect(manifest.inference.numThreads, speakerDiarizationNumThreads);
    expect(manifest.inference.provider, speakerDiarizationProvider);
    expect(manifest.inference.numClusters, speakerDiarizationNumClusters);
    expect(
      manifest.inference.clusteringThreshold,
      speakerDiarizationClusteringThreshold,
    );
  });

  test('拒绝改变固定自动聚类配置', () {
    final inference = source['inference'] as Map<String, dynamic>;
    inference['numClusters'] = 2;
    expect(() => _parse(source), throwsFormatException);

    inference['numClusters'] = speakerDiarizationNumClusters;
    inference['clusteringThreshold'] = 0.6;
    expect(() => _parse(source), throwsFormatException);
  });

  test('拒绝非 HTTPS 下载源', () {
    (source['embeddingModel'] as Map<String, dynamic>)['url'] =
        'http://example.com/model.onnx';

    expect(() => _parse(source), throwsFormatException);
  });

  test('拒绝变更归档白名单或增加安装文件', () {
    final archive = source['segmentationArchive'] as Map<String, dynamic>;
    (archive['allowedEntries'] as List<dynamic>).add('root/unexpected.bin');

    expect(() => _parse(source), throwsFormatException);
  });

  test('拒绝重复与越界路径', () {
    final archive = source['segmentationArchive'] as Map<String, dynamic>;
    final installFiles = archive['installFiles'] as List<dynamic>;
    (installFiles.last as Map<String, dynamic>)['path'] =
        (installFiles.first as Map<String, dynamic>)['path'];

    expect(() => _parse(source), throwsFormatException);

    (installFiles.last as Map<String, dynamic>)['path'] = '../LICENSE';
    expect(() => _parse(source), throwsFormatException);

    (installFiles.last as Map<String, dynamic>)['path'] = r'C:\LICENSE';
    expect(() => _parse(source), throwsFormatException);
  });

  test('拒绝下载字节总量不一致', () {
    source['requiredBytes'] = speakerDiarizationDownloadBytes - 1;

    expect(() => _parse(source), throwsFormatException);
  });
}

SpeakerDiarizationManifest _parse(Map<String, dynamic> source) =>
    const SpeakerDiarizationManifestParser().parse(jsonEncode(source));
