import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/models/runtime/speaker_diarization_manifest.dart';
import 'package:meettrace/data/services/diarization/downloadable_speaker_diarization_model.dart';
import 'package:meettrace/data/services/models/downloadable_model_service.dart';
import 'package:meettrace/data/services/models/model_download_types.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/domain/models/model_manifest.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late AppFileLayout layout;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('meettrace-speaker-test-');
    layout = AppFileLayout(rootPath: p.join(temp.path, 'app'));
    await layout.createBaseDirectories();
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('校验下载后只激活固定安装文件并清理归档暂存', () async {
    final fixture = _fixture();
    final downloader = _MemoryDownloader(fixture.downloads);
    final service = DownloadableSpeakerDiarizationModelService(
      fileLayout: layout,
      downloader: downloader,
    );

    final paths = await service.prepare(
      manifest: fixture.manifest,
      cancellation: ModelDownloadCancellationToken(),
    );

    expect(await service.isReadyFast(fixture.manifest), isTrue);
    expect(File(paths.segmentationModelPath).readAsBytesSync(), [1, 2, 3]);
    expect(File(paths.embeddingModelPath).readAsBytesSync(), [8, 9, 10, 11]);
    final finalRoot = layout.modelVersionDirectory('speaker-test', 'v1');
    final files = await Directory(finalRoot)
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .map(
          (file) =>
              p.relative(file.path, from: finalRoot).replaceAll(r'\', '/'),
        )
        .toList();
    expect(files..sort(), [
      'embedding/model.onnx',
      'segmentation/LICENSE',
      'segmentation/model.int8.onnx',
    ]);
    expect(
      Directory(layout.modelTempDirectory('speaker-test', 'v1')).existsSync(),
      isFalse,
    );
    expect(downloader.requests, hasLength(2));
  });

  test('归档出现白名单外文件时拒绝激活并清理暂存', () async {
    final fixture = _fixture(unexpectedArchiveFile: true);
    final service = DownloadableSpeakerDiarizationModelService(
      fileLayout: layout,
      downloader: _MemoryDownloader(fixture.downloads),
    );

    await expectLater(
      service.prepare(
        manifest: fixture.manifest,
        cancellation: ModelDownloadCancellationToken(),
      ),
      throwsA(
        isA<DownloadableModelException>().having(
          (error) => error.code,
          'code',
          'speaker.archive.invalid',
        ),
      ),
    );

    expect(
      Directory(layout.modelVersionDirectory('speaker-test', 'v1'))
          .existsSync(),
      isFalse,
    );
    expect(
      Directory(layout.modelTempDirectory('speaker-test', 'v1')).existsSync(),
      isFalse,
    );
  });

  test('下载完成后暂停会保留已校验下载文件但不会保留半成品安装目录', () async {
    final fixture = _fixture();
    final cancellation = ModelDownloadCancellationToken();
    final downloader = _MemoryDownloader(
      fixture.downloads,
      cancelAfterRequests: 2,
      cancellation: cancellation,
    );
    final service = DownloadableSpeakerDiarizationModelService(
      fileLayout: layout,
      downloader: downloader,
    );

    await expectLater(
      service.prepare(manifest: fixture.manifest, cancellation: cancellation),
      throwsA(
        isA<DownloadableModelException>().having(
          (error) => error.code,
          'code',
          'model.download.canceled',
        ),
      ),
    );

    final tempRoot = layout.modelTempDirectory('speaker-test', 'v1');
    expect(Directory(p.join(tempRoot, 'download')).existsSync(), isTrue);
    expect(Directory(p.join(tempRoot, 'install')).existsSync(), isFalse);
    expect(
      Directory(layout.modelVersionDirectory('speaker-test', 'v1'))
          .existsSync(),
      isFalse,
    );
  });
}

_Fixture _fixture({bool unexpectedArchiveFile = false}) {
  const archiveModel = [1, 2, 3];
  const license = [4, 5];
  const embedding = [8, 9, 10, 11];
  final archive = Archive()
    ..addFile(ArchiveFile.bytes('bundle/model.int8.onnx', archiveModel))
    ..addFile(ArchiveFile.bytes('bundle/LICENSE', license))
    ..addFile(ArchiveFile.bytes('bundle/model.onnx', [6]));
  if (unexpectedArchiveFile) {
    archive.addFile(ArchiveFile.bytes('bundle/unexpected.bin', [7]));
  }
  final tar = TarEncoder().encodeBytes(archive);
  final archiveBytes = BZip2Encoder().encodeBytes(tar);
  const archiveUrl = 'https://example.com/speaker.tar.bz2';
  const embeddingUrl = 'https://example.com/embedding.onnx';
  final archiveDownload = ModelManifestFile(
    path: '.downloads/speaker.tar.bz2',
    bytes: archiveBytes.length,
    sha256: sha256.convert(archiveBytes).toString(),
    url: archiveUrl,
  );
  final embeddingDownload = ModelManifestFile(
    path: '.downloads/embedding.onnx',
    bytes: embedding.length,
    sha256: sha256.convert(embedding).toString(),
    url: embeddingUrl,
  );
  final manifest = SpeakerDiarizationManifest(
    schemaVersion: 1,
    modelId: 'speaker-test',
    version: 'v1',
    requiredBytes: archiveBytes.length + embedding.length,
    inference: const SpeakerDiarizationInferenceConfig(
      sampleRate: speakerDiarizationSampleRate,
      numThreads: speakerDiarizationNumThreads,
      provider: speakerDiarizationProvider,
      numClusters: speakerDiarizationNumClusters,
      clusteringThreshold: speakerDiarizationClusteringThreshold,
      minDurationOn: speakerDiarizationMinDurationOn,
      minDurationOff: speakerDiarizationMinDurationOff,
    ),
    segmentationArchive: SpeakerDiarizationArchive(
      download: archiveDownload,
      allowedEntries: {
        'bundle/model.int8.onnx',
        'bundle/LICENSE',
        'bundle/model.onnx',
      },
      installFiles: [
        _installFile(
          archivePath: 'bundle/model.int8.onnx',
          path: speakerSegmentationModelPath,
          bytes: archiveModel,
          url: archiveUrl,
        ),
        _installFile(
          archivePath: 'bundle/LICENSE',
          path: 'segmentation/LICENSE',
          bytes: license,
          url: archiveUrl,
        ),
      ],
    ),
    embeddingModel: SpeakerDiarizationEmbeddingModel(
      download: embeddingDownload,
      installation: ModelManifestFile(
        path: 'embedding/model.onnx',
        bytes: embedding.length,
        sha256: sha256.convert(embedding).toString(),
        url: embeddingUrl,
      ),
    ),
    segmentationLicense: const RuntimeAssetLicense(
      name: 'MIT',
      noticePath: 'assets/licenses/test-NOTICE.txt',
      licensePath: 'assets/licenses/test-LICENSE.txt',
    ),
    embeddingLicense: const RuntimeAssetLicense(
      name: 'Apache-2.0',
      noticePath: 'assets/licenses/test2-NOTICE.txt',
      licensePath: 'assets/licenses/test2-LICENSE.txt',
    ),
  );
  return _Fixture(
    manifest: manifest,
    downloads: {
      Uri.parse(archiveUrl): archiveBytes,
      Uri.parse(embeddingUrl): embedding,
    },
  );
}

SpeakerDiarizationArchiveInstallFile _installFile({
  required String archivePath,
  required String path,
  required List<int> bytes,
  required String url,
}) => SpeakerDiarizationArchiveInstallFile(
  archivePath: archivePath,
  file: ModelManifestFile(
    path: path,
    bytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
    url: url,
  ),
);

final class _MemoryDownloader implements ModelFileDownloader {
  _MemoryDownloader(this.files, {this.cancelAfterRequests, this.cancellation});

  final Map<Uri, List<int>> files;
  final int? cancelAfterRequests;
  final ModelDownloadCancellationToken? cancellation;
  final List<Uri> requests = [];

  @override
  Future<ModelFileDownloadResult> download({
    required Uri source,
    required String destinationPath,
    required int resumeFrom,
    required int expectedBytes,
    required ModelDownloadCancellationToken cancellation,
    required void Function(int absoluteFileBytes) onProgress,
  }) async {
    final bytes = files[source]!;
    requests.add(source);
    await File(destinationPath).writeAsBytes(
      bytes.skip(resumeFrom).toList(),
      mode: resumeFrom == 0 ? FileMode.write : FileMode.append,
      flush: true,
    );
    onProgress(bytes.length);
    if (requests.length == cancelAfterRequests) {
      this.cancellation?.cancel();
    }
    return ModelFileDownloadResult(
      finalBytes: bytes.length,
      resumed: resumeFrom > 0,
    );
  }
}

final class _Fixture {
  const _Fixture({required this.manifest, required this.downloads});

  final SpeakerDiarizationManifest manifest;
  final Map<Uri, List<int>> downloads;
}
