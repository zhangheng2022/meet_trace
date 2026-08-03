import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/models/model_file_verifier.dart';
import 'package:meettrace/domain/models/model_manifest.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late ModelManifestEntry entry;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-model-verify-');
    entry = _entry();
  });

  tearDown(() => root.delete(recursive: true));

  test('文件集、大小和 SHA-256 全部匹配时校验通过', () async {
    await File(p.join(root.path, 'model.onnx')).writeAsString('hello');

    final result = await const ModelFileVerifier().verifyDirectory(
      directoryPath: root.path,
      manifest: entry,
    );

    expect(result.isValid, isTrue);
    expect(result.verifiedBytes, 5);
    expect(result.issues, isEmpty);
  });

  test('缺文件、大小不符和哈希不符分别返回结构化问题', () async {
    final verifier = const ModelFileVerifier();
    final missing = await verifier.verifyDirectory(
      directoryPath: root.path,
      manifest: entry,
    );

    await File(p.join(root.path, 'model.onnx')).writeAsString('bad');
    final wrongSize = await verifier.verifyDirectory(
      directoryPath: root.path,
      manifest: entry,
    );

    await File(p.join(root.path, 'model.onnx')).writeAsString('world');
    final wrongHash = await verifier.verifyDirectory(
      directoryPath: root.path,
      manifest: entry,
    );

    expect(missing.issues.single.kind, ModelFileIssueKind.missing);
    expect(wrongSize.issues.single.kind, ModelFileIssueKind.sizeMismatch);
    expect(wrongHash.issues.single.kind, ModelFileIssueKind.hashMismatch);
  });

  test('严格文件集拒绝 Manifest 之外的文件', () async {
    await File(p.join(root.path, 'model.onnx')).writeAsString('hello');
    await File(p.join(root.path, 'extra.bin')).writeAsString('extra');

    final result = await const ModelFileVerifier().verifyDirectory(
      directoryPath: root.path,
      manifest: entry,
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any((issue) => issue.kind == ModelFileIssueKind.unexpected),
      isTrue,
    );
  });
}

ModelManifestEntry _entry() {
  return ModelManifestEntry(
    modelId: 'model',
    version: '1.0.0',
    installationType: 'bundled',
    requiredBytes: 5,
    files: const [
      ModelManifestFile(
        path: 'model.onnx',
        bytes: 5,
        sha256:
            '2cf24dba5fb0a30e26e83b2ac5b9e29e'
            '1b161e5c1fa7425e73043362938b9824',
        url: 'asset://models/model.onnx',
      ),
    ],
    license: const ModelLicense(
      name: 'Apache-2.0',
      noticePath: 'licenses/model-NOTICE.txt',
    ),
  );
}
