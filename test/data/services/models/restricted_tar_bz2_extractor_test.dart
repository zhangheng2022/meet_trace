import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/models/runtime/speaker_diarization_manifest.dart';
import 'package:meettrace/data/services/models/restricted_tar_bz2_extractor.dart';
import 'package:meettrace/data/services/models/runtime_artifact_install_transaction.dart';
import 'package:meettrace/domain/models/model_manifest.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('meettrace-archive-test-');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('只提取白名单中的固定安装文件并忽略已知附带文件', () async {
    final fixture = await _fixture(temp, [
      ArchiveFile.bytes('bundle/model.int8.onnx', [1, 2, 3]),
      ArchiveFile.bytes('bundle/LICENSE', [4, 5]),
      ArchiveFile.bytes('bundle/model.onnx', [6]),
      ArchiveFile.bytes('bundle/run.sh', [7]),
    ]);

    await const RestrictedTarBz2Extractor().extract(
      archivePath: fixture.archivePath,
      installationPath: fixture.installationPath,
      allowedEntries: fixture.allowedEntries,
      installFiles: fixture.installFiles,
      throwIfCanceled: () {},
    );

    expect(
      File(p.join(fixture.installationPath, 'segmentation', 'model.int8.onnx'))
          .readAsBytesSync(),
      [1, 2, 3],
    );
    expect(
      File(p.join(fixture.installationPath, 'segmentation', 'LICENSE'))
          .readAsBytesSync(),
      [4, 5],
    );
    expect(
      File(p.join(fixture.installationPath, 'bundle', 'model.onnx'))
          .existsSync(),
      isFalse,
    );
  });

  for (final unsafePath in ['../escape', '/absolute', r'C:\escape']) {
    test('拒绝不安全归档路径 $unsafePath', () async {
      final fixture = await _fixture(temp, [
        ArchiveFile.bytes('bundle/model.int8.onnx', [1, 2, 3]),
        ArchiveFile.bytes('bundle/LICENSE', [4, 5]),
        ArchiveFile.bytes(unsafePath, [9]),
      ]);

      await expectLater(
        _extract(fixture),
        throwsA(
          isA<RuntimeArtifactInstallException>().having(
            (error) => error.failure,
            'failure',
            RuntimeArtifactInstallFailure.invalidPath,
          ),
        ),
      );
    });
  }

  test('拒绝符号链接', () async {
    final fixture = await _fixture(temp, [
      ArchiveFile.bytes('bundle/model.int8.onnx', [1, 2, 3]),
      ArchiveFile.bytes('bundle/LICENSE', [4, 5]),
      ArchiveFile.symlink('bundle/run.sh', '../escape'),
    ]);

    await expectLater(
      _extract(fixture),
      throwsA(
        isA<RuntimeArtifactInstallException>().having(
          (error) => error.failure,
          'failure',
          RuntimeArtifactInstallFailure.preparation,
        ),
      ),
    );
  });

  test('拒绝白名单外文件', () async {
    final fixture = await _fixture(temp, [
      ArchiveFile.bytes('bundle/model.int8.onnx', [1, 2, 3]),
      ArchiveFile.bytes('bundle/LICENSE', [4, 5]),
      ArchiveFile.bytes('bundle/unknown.bin', [9]),
    ]);

    await expectLater(
      _extract(fixture),
      throwsA(isA<RuntimeArtifactInstallException>()),
    );
  });
}

Future<void> _extract(_Fixture fixture) =>
    const RestrictedTarBz2Extractor().extract(
      archivePath: fixture.archivePath,
      installationPath: fixture.installationPath,
      allowedEntries: fixture.allowedEntries,
      installFiles: fixture.installFiles,
      throwIfCanceled: _neverCanceled,
    );

void _neverCanceled() {}

Future<_Fixture> _fixture(Directory temp, List<ArchiveFile> files) async {
  final archive = Archive();
  for (final file in files) {
    archive.addFile(file);
  }
  final tar = TarEncoder().encodeBytes(archive);
  final bytes = BZip2Encoder().encodeBytes(tar);
  final archivePath = p.join(temp.path, 'fixture.tar.bz2');
  await File(archivePath).writeAsBytes(bytes, flush: true);
  final allowedEntries = {
    'bundle/model.int8.onnx',
    'bundle/LICENSE',
    'bundle/model.onnx',
    'bundle/run.sh',
  };
  return _Fixture(
    archivePath: archivePath,
    installationPath: p.join(temp.path, 'install'),
    allowedEntries: allowedEntries,
    installFiles: [
      _installFile('bundle/model.int8.onnx', 'segmentation/model.int8.onnx', [
        1,
        2,
        3,
      ]),
      _installFile('bundle/LICENSE', 'segmentation/LICENSE', [4, 5]),
    ],
  );
}

SpeakerDiarizationArchiveInstallFile _installFile(
  String archivePath,
  String path,
  List<int> bytes,
) => SpeakerDiarizationArchiveInstallFile(
  archivePath: archivePath,
  file: ModelManifestFile(
    path: path,
    bytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
    url: 'https://example.com/archive.tar.bz2',
  ),
);

final class _Fixture {
  const _Fixture({
    required this.archivePath,
    required this.installationPath,
    required this.allowedEntries,
    required this.installFiles,
  });

  final String archivePath;
  final String installationPath;
  final Set<String> allowedEntries;
  final List<SpeakerDiarizationArchiveInstallFile> installFiles;
}
