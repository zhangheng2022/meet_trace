import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/models/runtime/silero_vad_manifest.dart';
import 'package:meettrace/data/services/models/downloadable_model_service.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/vad/downloadable_silero_vad_model.dart';
import 'package:meettrace/domain/models/model_manifest.dart';

void main() {
  test('VAD 通过 HTTPS 下载、严格校验并从最终目录快速恢复', () async {
    final root = await Directory.systemTemp.createTemp('meettrace-vad-');
    addTearDown(() => root.delete(recursive: true));
    final layout = AppFileLayout(rootPath: root.path);
    await layout.createBaseDirectories();
    final service = DownloadableSileroVadModelService(
      fileLayout: layout,
      downloader: const _HelloDownloader(),
    );
    final manifest = SileroVadManifest(
      schemaVersion: 1,
      modelId: sileroVadModelId,
      version: sileroVadModelVersion,
      sampleRate: 16000,
      windowSize: 512,
      requiredBytes: 5,
      files: const [
        ModelManifestFile(
          path: sileroVadModelFileName,
          bytes: 5,
          sha256:
              '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
          url: 'https://example.test/silero_vad.int8.onnx',
        ),
      ],
      license: const ModelLicense(name: 'MIT', noticePath: 'NOTICE.txt'),
      licensePath: 'LICENSE.txt',
    );

    final path = await service.prepare(
      manifest: manifest,
      cancellation: ModelDownloadCancellationToken(),
    );

    expect(File(path).readAsStringSync(), 'hello');
    expect(await service.isReadyFast(manifest), isTrue);
  });

  test('VAD 暂停保留分片且下次从已有字节续传', () async {
    final root = await Directory.systemTemp.createTemp('meettrace-vad-resume-');
    addTearDown(() => root.delete(recursive: true));
    final layout = AppFileLayout(rootPath: root.path);
    await layout.createBaseDirectories();
    final downloader = _ResumingDownloader();
    final service = DownloadableSileroVadModelService(
      fileLayout: layout,
      downloader: downloader,
    );
    final manifest = _manifest();

    await expectLater(
      service.prepare(
        manifest: manifest,
        cancellation: ModelDownloadCancellationToken(),
      ),
      throwsA(
        isA<DownloadableModelException>().having(
          (error) => error.code,
          'code',
          'model.download.canceled',
        ),
      ),
    );
    final tempFile = File(
      '${layout.modelTempDirectory(manifest.modelId, manifest.version)}${Platform.pathSeparator}$sileroVadModelFileName',
    );
    expect(await tempFile.readAsString(), 'he');

    final path = await service.prepare(
      manifest: manifest,
      cancellation: ModelDownloadCancellationToken(),
    );

    expect(downloader.resumeOffsets, [0, 2]);
    expect(await File(path).readAsString(), 'hello');
  });
}

SileroVadManifest _manifest() => SileroVadManifest(
  schemaVersion: 1,
  modelId: sileroVadModelId,
  version: sileroVadModelVersion,
  sampleRate: 16000,
  windowSize: 512,
  requiredBytes: 5,
  files: const [
    ModelManifestFile(
      path: sileroVadModelFileName,
      bytes: 5,
      sha256:
          '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
      url: 'https://example.test/silero_vad.int8.onnx',
    ),
  ],
  license: const ModelLicense(name: 'MIT', noticePath: 'NOTICE.txt'),
  licensePath: 'LICENSE.txt',
);

final class _HelloDownloader implements ModelFileDownloader {
  const _HelloDownloader();

  @override
  Future<ModelFileDownloadResult> download({
    required Uri source,
    required String destinationPath,
    required int resumeFrom,
    required int expectedBytes,
    required ModelDownloadCancellationToken cancellation,
    required void Function(int absoluteFileBytes) onProgress,
  }) async {
    cancellation.throwIfCanceled();
    final file = File(destinationPath);
    await file.writeAsString('hello', mode: FileMode.write, flush: true);
    onProgress(5);
    return const ModelFileDownloadResult(finalBytes: 5, resumed: false);
  }
}

final class _ResumingDownloader implements ModelFileDownloader {
  final List<int> resumeOffsets = [];

  @override
  Future<ModelFileDownloadResult> download({
    required Uri source,
    required String destinationPath,
    required int resumeFrom,
    required int expectedBytes,
    required ModelDownloadCancellationToken cancellation,
    required void Function(int absoluteFileBytes) onProgress,
  }) async {
    resumeOffsets.add(resumeFrom);
    final file = File(destinationPath);
    if (resumeOffsets.length == 1) {
      await file.writeAsString('he', mode: FileMode.write, flush: true);
      throw const ModelDownloadCanceledException();
    }
    await file.writeAsString('llo', mode: FileMode.append, flush: true);
    onProgress(5);
    return const ModelFileDownloadResult(finalBytes: 5, resumed: true);
  }
}
