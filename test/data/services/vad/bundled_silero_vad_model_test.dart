import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/models/bundled_model_preparation_service.dart';
import 'package:meetily_ai/data/services/models/model_file_verifier.dart';
import 'package:meetily_ai/data/services/storage/app_file_layout.dart';
import 'package:meetily_ai/data/services/vad/bundled_silero_vad_model.dart';
import 'package:path/path.dart' as p;

void main() {
  late String projectRoot;
  late Uint8List manifestBytes;
  late Uint8List modelBytes;
  late Directory outputRoot;

  setUp(() async {
    projectRoot = Directory.current.path;
    manifestBytes = await File(
      p.joinAll([projectRoot, ...bundledSileroVadManifestAssetPath.split('/')]),
    ).readAsBytes();
    modelBytes = await File(
      p.joinAll([
        projectRoot,
        ...bundledSileroVadAssetDirectory.split('/'),
        bundledSileroVadModelFileName,
      ]),
    ).readAsBytes();
    outputRoot = await Directory.systemTemp.createTemp('meetily-bundled-vad-');
  });

  tearDown(() async {
    if (await outputRoot.exists()) {
      await outputRoot.delete(recursive: true);
    }
  });

  test('真实 Silero VAD 资产、Manifest 和许可记录完全一致', () async {
    final manifest = const SileroVadAssetManifestParser().parse(
      utf8.decode(manifestBytes),
    );
    final verification = await const ModelFileVerifier().verifyDirectory(
      directoryPath: p.joinAll([
        projectRoot,
        ...bundledSileroVadAssetDirectory.split('/'),
      ]),
      manifest: manifest.verificationEntry,
    );

    expect(manifest.modelId, bundledSileroVadModelId);
    expect(manifest.version, bundledSileroVadModelVersion);
    expect(manifest.requiredBytes, 212860);
    expect(
      manifest.files.single.sha256,
      'c36d490aff5ab924ca6c7aeec4d8f6bd'
      '3d22db6fa17611b9c5b17eae58ac3a20',
    );
    expect(manifest.releaseAssetId, 271935990);
    expect(verification.isValid, isTrue, reason: _issues(verification));
    expect(verification.verifiedBytes, manifest.requiredBytes);
    for (final path in [manifest.license.noticePath, manifest.licensePath]) {
      expect(
        File(p.joinAll([projectRoot, ...path.split('/')])).existsSync(),
        isTrue,
      );
    }
  });

  test('复制、严格校验和原子切换后返回官方 VAD 文件路径', () async {
    final assets = _MemoryAssetSource({
      bundledSileroVadManifestAssetUrl: manifestBytes,
      'asset://$bundledSileroVadAssetDirectory/'
              '$bundledSileroVadModelFileName':
          modelBytes,
    });
    final layout = AppFileLayout(rootPath: outputRoot.path);
    final service = BundledSileroVadModelService(
      fileLayout: layout,
      assetSource: assets,
    );

    final result = await service.prepare();

    expect(result.alreadyReady, isFalse);
    expect(await File(result.modelPath).length(), 212860);
    expect(
      p.isWithin(layout.modelsRoot, p.normalize(p.absolute(result.modelPath))),
      isTrue,
    );
    expect(
      await Directory(
        layout.modelTempDirectory(
          bundledSileroVadModelId,
          bundledSileroVadModelVersion,
        ),
      ).exists(),
      isFalse,
    );
  });

  test('已校验的私有模型可复用且不重复复制权重', () async {
    final modelAssetUrl =
        'asset://$bundledSileroVadAssetDirectory/'
        '$bundledSileroVadModelFileName';
    final assets = _MemoryAssetSource({
      bundledSileroVadManifestAssetUrl: manifestBytes,
      modelAssetUrl: modelBytes,
    });
    final service = BundledSileroVadModelService(
      fileLayout: AppFileLayout(rootPath: outputRoot.path),
      assetSource: assets,
    );

    await service.prepare();
    final reused = await service.prepare();

    expect(reused.alreadyReady, isTrue);
    expect(assets.loads[modelAssetUrl], 1);
    expect(assets.loads[bundledSileroVadManifestAssetUrl], 2);
  });

  test('权重损坏时拒绝形成最终目录并清理临时文件', () async {
    final assets = _MemoryAssetSource({
      bundledSileroVadManifestAssetUrl: manifestBytes,
      'asset://$bundledSileroVadAssetDirectory/'
          '$bundledSileroVadModelFileName': Uint8List(
        212860,
      ),
    });
    final layout = AppFileLayout(rootPath: outputRoot.path);
    final service = BundledSileroVadModelService(
      fileLayout: layout,
      assetSource: assets,
    );

    await expectLater(
      service.prepare(),
      throwsA(
        isA<BundledSileroVadPreparationException>().having(
          (error) => error.code,
          'code',
          'vad.model.integrity',
        ),
      ),
    );

    expect(
      await Directory(
        layout.modelVersionDirectory(
          bundledSileroVadModelId,
          bundledSileroVadModelVersion,
        ),
      ).exists(),
      isFalse,
    );
    expect(
      await Directory(
        layout.modelTempDirectory(
          bundledSileroVadModelId,
          bundledSileroVadModelVersion,
        ),
      ).exists(),
      isFalse,
    );
  });

  test('拒绝偏离固定采样率的 Manifest', () {
    final source = utf8
        .decode(manifestBytes)
        .replaceFirst('"sampleRate": 16000', '"sampleRate": 8000');

    expect(
      () => const SileroVadAssetManifestParser().parse(source),
      throwsFormatException,
    );
  });
}

String _issues(ModelFileVerificationResult result) {
  return result.issues
      .map((issue) => '${issue.path}: ${issue.message}')
      .join(', ');
}

final class _MemoryAssetSource implements ModelAssetSource {
  _MemoryAssetSource(Map<String, Uint8List> values) : values = Map.of(values);

  final Map<String, Uint8List> values;
  final Map<String, int> loads = {};

  @override
  Future<Uint8List> load(String assetUrl) async {
    loads.update(assetUrl, (value) => value + 1, ifAbsent: () => 1);
    final value = values[assetUrl];
    if (value == null) {
      throw StateError('缺少测试资产：$assetUrl');
    }
    return Uint8List.fromList(value);
  }
}
