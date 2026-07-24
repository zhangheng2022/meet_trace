import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/repositories/repository_contracts.dart';
import 'package:meetily_ai/data/services/models/bundled_model_preparation_service.dart';
import 'package:meetily_ai/data/services/models/model_file_verifier.dart';
import 'package:meetily_ai/data/services/storage/app_file_layout.dart';
import 'package:meetily_ai/domain/models/asr_model.dart';
import 'package:meetily_ai/domain/models/model_installation.dart';
import 'package:meetily_ai/domain/models/model_manifest.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late AppFileLayout layout;
  late _MemoryInstallationRepository repository;
  late _FakeAssetSource assets;
  late BundledModelPreparationService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meetily-bundled-model-');
    layout = AppFileLayout(rootPath: root.path);
    repository = _MemoryInstallationRepository();
    assets = _FakeAssetSource({
      'asset://assets/models/model.onnx': utf8.encode('hello'),
    });
    service = BundledModelPreparationService(
      fileLayout: layout,
      installations: repository,
      assetSource: assets,
      verifier: const ModelFileVerifier(),
      now: () => DateTime.utc(2026, 7, 24, 12),
    );
  });

  tearDown(() => root.delete(recursive: true));

  test('复制、校验、原子切换后才保存 installed', () async {
    final progress = <BundledModelPreparationPhase>[];

    final result = await service.prepare(
      descriptor: _descriptor,
      manifest: _manifest,
      onProgress: (value) => progress.add(value.phase),
    );

    final finalFile = File(
      p.join(
        layout.modelVersionDirectory(_descriptor.modelId, _descriptor.version),
        'model.onnx',
      ),
    );
    final installation = await repository.get(
      modelId: _descriptor.modelId,
      version: _descriptor.version,
    );

    expect(await finalFile.readAsString(), 'hello');
    expect(result.alreadyReady, isFalse);
    expect(installation?.state, ModelInstallationState.installed);
    expect(installation?.bytes, 5);
    expect(
      progress,
      containsAllInOrder([
        BundledModelPreparationPhase.checking,
        BundledModelPreparationPhase.copying,
        BundledModelPreparationPhase.verifying,
        BundledModelPreparationPhase.committing,
        BundledModelPreparationPhase.ready,
      ]),
    );
  });

  test('已正确安装时不重复读取 assets', () async {
    await service.prepare(descriptor: _descriptor, manifest: _manifest);
    assets.failOnLoad = true;

    final result = await service.prepare(
      descriptor: _descriptor,
      manifest: _manifest,
    );

    expect(result.alreadyReady, isTrue);
    expect(assets.loadCount, 1);
  });

  test('哈希不符不会形成 installed 或最终目录', () async {
    assets.bytesByUrl['asset://assets/models/model.onnx'] = utf8.encode(
      'world',
    );

    await expectLater(
      service.prepare(descriptor: _descriptor, manifest: _manifest),
      throwsA(isA<BundledModelPreparationException>()),
    );

    final installation = await repository.get(
      modelId: _descriptor.modelId,
      version: _descriptor.version,
    );
    expect(installation?.state, ModelInstallationState.failed);
    expect(
      await Directory(
        layout.modelVersionDirectory(_descriptor.modelId, _descriptor.version),
      ).exists(),
      isFalse,
    );
  });

  test('数据库提交失败留下的已校验目录可在重试时收养', () async {
    repository.failNextInstalledSave = true;

    await expectLater(
      service.prepare(descriptor: _descriptor, manifest: _manifest),
      throwsA(isA<BundledModelPreparationException>()),
    );
    expect(
      await Directory(
        layout.modelVersionDirectory(_descriptor.modelId, _descriptor.version),
      ).exists(),
      isTrue,
    );

    assets.failOnLoad = true;
    final recovered = await service.prepare(
      descriptor: _descriptor,
      manifest: _manifest,
    );

    expect(recovered.recoveredExistingFiles, isTrue);
    expect(assets.loadCount, 1);
    expect(repository.current?.state, ModelInstallationState.installed);
  });

  test('重试会清理目标版本的残留临时目录', () async {
    final tempDirectory = Directory(
      layout.modelTempDirectory(_descriptor.modelId, _descriptor.version),
    );
    await tempDirectory.create(recursive: true);
    await File(p.join(tempDirectory.path, 'stale.bin')).writeAsString('stale');

    await service.prepare(descriptor: _descriptor, manifest: _manifest);

    expect(await tempDirectory.exists(), isFalse);
    expect(
      await File(
        p.join(
          layout.modelVersionDirectory(
            _descriptor.modelId,
            _descriptor.version,
          ),
          'stale.bin',
        ),
      ).exists(),
      isFalse,
    );
  });
}

final _descriptor = AsrModelDescriptor(
  modelId: 'bundled-model',
  displayName: '测试内置模型',
  tier: AsrModelTier.standard,
  version: '1.0.0',
  supportedLanguages: const ['zh'],
  installationType: AsrInstallationType.bundled,
  requiredBytes: 5,
  capabilities: const {'offline'},
);

final _manifest = ModelManifestEntry(
  modelId: _descriptor.modelId,
  version: _descriptor.version,
  tier: _descriptor.tier.name,
  installationType: _descriptor.installationType.name,
  requiredBytes: 5,
  files: const [
    ModelManifestFile(
      path: 'model.onnx',
      bytes: 5,
      sha256:
          '2cf24dba5fb0a30e26e83b2ac5b9e29e'
          '1b161e5c1fa7425e73043362938b9824',
      url: 'asset://assets/models/model.onnx',
    ),
  ],
  license: const ModelLicense(
    name: 'test-only',
    noticePath: 'licenses/test.txt',
  ),
);

final class _FakeAssetSource implements ModelAssetSource {
  _FakeAssetSource(Map<String, List<int>> bytesByUrl)
    : bytesByUrl = Map.of(bytesByUrl);

  final Map<String, List<int>> bytesByUrl;
  var loadCount = 0;
  var failOnLoad = false;

  @override
  Future<Uint8List> load(String assetUrl) async {
    loadCount++;
    if (failOnLoad) {
      throw StateError('不应重复读取 asset');
    }
    final bytes = bytesByUrl[assetUrl];
    if (bytes == null) {
      throw StateError('缺少测试 asset：$assetUrl');
    }
    return Uint8List.fromList(bytes);
  }
}

final class _MemoryInstallationRepository
    implements ModelInstallationRepository {
  ModelInstallation? current;
  bool failNextInstalledSave = false;

  @override
  Future<ModelInstallation?> get({
    required String modelId,
    required String version,
  }) async {
    final value = current;
    if (value?.modelId == modelId && value?.version == version) {
      return value;
    }
    return null;
  }

  @override
  Future<void> save(ModelInstallation installation) async {
    if (failNextInstalledSave &&
        installation.state == ModelInstallationState.installed) {
      failNextInstalledSave = false;
      throw StateError('模拟数据库提交失败');
    }
    current = installation;
  }

  @override
  Stream<List<ModelInstallation>> watchAll() {
    final value = current;
    return Stream.value(value == null ? const [] : [value]);
  }
}
