import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/models/runtime_artifact_install_transaction.dart';
import 'package:meettrace/domain/models/model_manifest.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-install-swap-');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('新目录切换失败时恢复旧安装', () async {
    final tempRoot = p.join(root.path, '.tmp');
    final finalRoot = p.join(root.path, 'models');
    final tempPath = p.join(tempRoot, 'model', '1');
    final finalPath = p.join(finalRoot, 'model', '1');
    final newBytes = utf8.encode('new-model');
    await Directory(tempPath).create(recursive: true);
    await File(p.join(tempPath, 'model.bin')).writeAsBytes(newBytes);
    await Directory(finalPath).create(recursive: true);
    await File(p.join(finalPath, 'old.bin')).writeAsString('old-model');
    final manifest = ModelManifestEntry(
      modelId: 'model',
      version: '1',
      installationType: 'downloadable',
      requiredBytes: newBytes.length,
      files: [
        ModelManifestFile(
          path: 'model.bin',
          bytes: newBytes.length,
          sha256: sha256.convert(newBytes).toString(),
          url: 'https://example.invalid/model.bin',
        ),
      ],
      license: const ModelLicense(name: 'test', noticePath: 'NOTICE'),
    );

    await expectLater(
      const RuntimeArtifactInstallTransaction().install(
        manifest: manifest,
        tempPath: tempPath,
        finalPath: finalPath,
        tempRoot: tempRoot,
        finalRoot: finalRoot,
        throwIfCanceled: () {},
        download:
            ({
              required file,
              required destinationPath,
              required resumeFrom,
              required onProgress,
            }) async => RuntimeArtifactDownloadOutcome(
              finalBytes: file.bytes,
              resumed: resumeFrom > 0,
            ),
        onCommitting: (_) => Directory(tempPath).delete(recursive: true),
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(
      await File(p.join(finalPath, 'old.bin')).readAsString(),
      'old-model',
    );
    expect(await File(p.join(finalPath, 'model.bin')).exists(), isFalse);
  });
}
