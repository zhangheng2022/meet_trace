import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/models/http_model_file_downloader.dart';
import 'package:meettrace/data/services/models/model_download_types.dart';
import 'package:meettrace/data/services/models/model_temp_recovery_service.dart';
import 'package:meettrace/data/services/models/runtime_artifact_install_transaction.dart';
import 'package:meettrace/data/services/models/runtime_artifact_temp_state.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/storage/startup_recovery_service.dart';
import 'package:meettrace/domain/models/model_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late Directory root;
  late AppFileLayout layout;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-model-recovery-');
    layout = AppFileLayout(rootPath: root.path);
    await layout.createBaseDirectories();
  });

  tearDown(() => root.delete(recursive: true));

  test('固定资源清单覆盖 ASR、VAD 和分离的实际下载布局', () async {
    final specifications = await loadCurrentRuntimeArtifactTempManifests();
    expect(specifications, hasLength(3));
    expect(
      specifications.where((entry) => entry.downloadSubdirectory.isEmpty),
      hasLength(2),
    );
    final speaker = specifications.singleWhere(
      (entry) => entry.downloadSubdirectory == 'download',
    );
    expect(
      speaker.files.keys,
      everyElement(startsWith('download/.downloads/')),
    );
  });

  test('保留匹配当前 Manifest 的部分文件及已校验完整文件', () async {
    final manifest = _manifest({
      'model.bin': 'hello',
      'nested/tokens': 'tokens',
    });
    final specification = RuntimeArtifactTempManifest(manifest: manifest);
    final tempPath = await _seed(layout, specification, {
      'model.bin': 'he',
      'nested/tokens': 'tokens',
    });
    final recovery = _recovery([specification]);

    expect(await recovery.recover(layout: layout), 0);
    expect(await File(p.join(tempPath, 'model.bin')).readAsString(), 'he');
    expect(
      await File(p.join(tempPath, 'nested/tokens')).readAsString(),
      'tokens',
    );
    expect(await recovery.recover(layout: layout), 0);
  });

  test('清理未知和过期版本，当前下载与最终安装保持独立', () async {
    final specification = RuntimeArtifactTempManifest(
      manifest: _manifest({'model.bin': 'hello'}),
    );
    final tempPath = await _seed(layout, specification, {'model.bin': 'he'});
    for (final path in [
      layout.modelTempDirectory('obsolete', '1'),
      layout.modelTempDirectory('model', 'old'),
    ]) {
      await Directory(path).create(recursive: true);
      await File(p.join(path, 'stale')).writeAsString('stale');
    }
    final finalFile = File(
      p.join(layout.modelVersionDirectory('model', 'v1'), 'keep'),
    );
    await finalFile.parent.create(recursive: true);
    await finalFile.writeAsString('installed');
    final recovery = _recovery([specification]);

    expect(await recovery.recover(layout: layout), 2);
    expect(await File(p.join(tempPath, 'model.bin')).readAsString(), 'he');
    expect(await finalFile.readAsString(), 'installed');
    expect(await recovery.recover(layout: layout), 0);
  });

  test('坏完整文件、超长文件、空文件及白名单外内容被清理', () async {
    final specification = RuntimeArtifactTempManifest(
      manifest: _manifest({
        'good': 'hello',
        'corrupt': 'hello',
        'oversize': 'hello',
        'empty': 'hello',
        'directory': 'hello',
      }),
    );
    final tempPath = await _seed(layout, specification, {
      'good': 'he',
      'corrupt': 'WRONG',
      'oversize': 'toolong',
      'empty': '',
      'unknown/debris': 'unknown',
    });
    await Directory(p.join(tempPath, 'directory')).create();

    expect(await _recovery([specification]).recover(layout: layout), 0);
    expect(await File(p.join(tempPath, 'good')).readAsString(), 'he');
    final remaining = await Directory(tempPath)
        .list()
        .map((file) => p.basename(file.path))
        .toList();
    expect(
      remaining,
      unorderedEquals(['good', RuntimeArtifactTempState.markerName]),
    );
  });

  test('没有指纹的旧片段不能续传，完整文件可通过当前 SHA 重新接纳', () async {
    final specification = RuntimeArtifactTempManifest(
      manifest: _manifest({'partial': 'hello', 'complete': 'world'}),
    );
    final tempPath = await _seed(layout, specification, {
      'partial': 'he',
      'complete': 'world',
    });
    await const RuntimeArtifactTempState().removeMarker(tempPath);

    expect(await _recovery([specification]).recover(layout: layout), 0);
    expect(await File(p.join(tempPath, 'partial')).exists(), isFalse);
    expect(await File(p.join(tempPath, 'complete')).readAsString(), 'world');
  });

  for (final changedSource in [false, true]) {
    test('同版本${changedSource ? '来源' : '内容'}变化时不复用旧片段', () async {
      final old = RuntimeArtifactTempManifest(
        manifest: _manifest({'model.bin': 'hello'}),
      );
      final tempPath = await _seed(layout, old, {'model.bin': 'he'});
      final current = RuntimeArtifactTempManifest(
        manifest: _manifest({
          'model.bin': changedSource ? 'hello' : 'world',
        }, url: changedSource ? 'https://example.invalid/new' : null),
      );

      expect(await _recovery([current]).recover(layout: layout), 1);
      expect(await Directory(tempPath).exists(), isFalse);
    });
  }

  test('损坏的指纹无法证明下载归属，清理且不会解析异常', () async {
    final specification = RuntimeArtifactTempManifest(
      manifest: _manifest({'model.bin': 'hello'}),
    );
    final tempPath = await _seed(layout, specification, {'model.bin': 'he'});
    await File(p.join(tempPath, RuntimeArtifactTempState.markerName))
        .writeAsBytes(List.filled(64, 255));

    expect(await _recovery([specification]).recover(layout: layout), 1);
    expect(await Directory(tempPath).exists(), isFalse);
  });

  test('分离下载在重启后保留，转换中的 install 目录安全丢弃', () async {
    final specification = RuntimeArtifactTempManifest(
      manifest: _manifest({
        '.downloads/archive': 'archive',
        '.downloads/embedding': 'embedding',
      }),
      downloadSubdirectory: 'download',
    );
    final tempPath = await _seed(layout, specification, {
      'download/.downloads/archive': 'arch',
      'download/.downloads/embedding': 'embedding',
      'install/segmentation/model': 'incomplete',
    });

    expect(await _recovery([specification]).recover(layout: layout), 0);
    expect(
      await File(p.join(tempPath, 'download/.downloads/archive'))
          .readAsString(),
      'arch',
    );
    expect(await Directory(p.join(tempPath, 'install')).exists(), isFalse);
  });

  test('部分文件无法提前验 SHA，但续传后必须完整校验才能安装', () async {
    final manifest = _manifest({'model.bin': 'hello'});
    final specification = RuntimeArtifactTempManifest(manifest: manifest);
    final tempPath = await _seed(layout, specification, {'model.bin': 'xx'});
    final finalPath = layout.modelVersionDirectory(
      manifest.modelId,
      manifest.version,
    );
    expect(await _recovery([specification]).recover(layout: layout), 0);

    await expectLater(
      const RuntimeArtifactInstallTransaction().install(
        manifest: manifest,
        tempPath: tempPath,
        finalPath: finalPath,
        tempRoot: layout.modelTempRoot,
        finalRoot: layout.modelsRoot,
        throwIfCanceled: () {},
        download:
            ({
              required file,
              required destinationPath,
              required resumeFrom,
              required onProgress,
            }) async {
              expect(resumeFrom, 2);
              await File(destinationPath)
                  .writeAsString('llo', mode: FileMode.append);
              return const RuntimeArtifactDownloadOutcome(
                finalBytes: 5,
                resumed: true,
              );
            },
      ),
      throwsA(
        isA<RuntimeArtifactInstallException>().having(
          (error) => error.failure,
          'failure',
          RuntimeArtifactInstallFailure.integrity,
        ),
      ),
    );
    expect(await Directory(tempPath).exists(), isFalse);
    expect(await Directory(finalPath).exists(), isFalse);
  });

  test('清单加载失败时保留暂存并由启动恢复报告', () async {
    final specification = RuntimeArtifactTempManifest(
      manifest: _manifest({'model.bin': 'hello'}),
    );
    final tempPath = await _seed(layout, specification, {'model.bin': 'he'});
    final database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: layout.databasePath,
    );
    addTearDown(database.close);
    final errors = <String>[];
    final recovery = StartupRecoveryService(
      database: database,
      layout: layout,
      modelTempRecovery: ModelTempRecoveryService(
        loadManifests: () async =>
            throw const FormatException('manifest unavailable'),
      ),
      reportError: (step, error, stackTrace) => errors.add(step),
    );

    final report = await recovery.recover(now: DateTime.utc(2026));
    expect(report.removedModelTempDirectories, 0);
    expect(errors, contains('removeIncompleteModelDirectories'));
    expect(await File(p.join(tempPath, 'model.bin')).readAsString(), 'he');
  });

  test('链接位于模型、版本、文件或父目录时只删链接且不触碰外部内容', () async {
    final outside = await Directory.systemTemp.createTemp(
      'meettrace-model-outside-',
    );
    addTearDown(() => outside.delete(recursive: true));
    final keep = File(p.join(outside.path, 'keep'));
    await keep.writeAsString('external');
    final specification = RuntimeArtifactTempManifest(
      manifest: _manifest({
        'good': 'hello',
        'link': 'hello',
        'nested/keep': 'hello',
      }),
    );
    final tempPath = await _seed(layout, specification, {'good': 'he'});
    await Link(p.join(tempPath, 'link')).create(keep.path);
    await Link(p.join(tempPath, 'nested')).create(outside.path);
    await Link(p.join(layout.modelTempRoot, 'linked-model'))
        .create(outside.path);
    await Link(layout.modelTempDirectory('model', 'linked-version'))
        .create(outside.path);
    final recovery = _recovery([specification]);

    expect(await recovery.recover(layout: layout), 2);
    expect(await keep.readAsString(), 'external');
    expect(await Link(p.join(tempPath, 'link')).exists(), isFalse);
    expect(await Link(p.join(tempPath, 'nested')).exists(), isFalse);
    expect(await File(p.join(tempPath, 'good')).readAsString(), 'he');
  }, skip: Platform.isWindows ? 'Windows 测试环境不保证符号链接权限' : false);

  test('指纹为符号链接时不读取或改写外部标记', () async {
    final specification = RuntimeArtifactTempManifest(
      manifest: _manifest({'model.bin': 'hello'}),
    );
    final tempPath = await _seed(layout, specification, {'model.bin': 'he'});
    final outside = await Directory.systemTemp.createTemp(
      'meettrace-marker-outside-',
    );
    addTearDown(() => outside.delete(recursive: true));
    final keep = File(p.join(outside.path, 'marker'));
    await keep.writeAsString(specification.fingerprint);
    final marker = p.join(tempPath, RuntimeArtifactTempState.markerName);
    await File(marker).delete();
    await Link(marker).create(keep.path);

    expect(await _recovery([specification]).recover(layout: layout), 1);
    expect(await Directory(tempPath).exists(), isFalse);
    expect(await keep.readAsString(), specification.fingerprint);
  }, skip: Platform.isWindows ? 'Windows 测试环境不保证符号链接权限' : false);

  test('临时根目录本身为链接时不遍历外部目录', () async {
    final outside = await Directory.systemTemp.createTemp(
      'meettrace-root-outside-',
    );
    addTearDown(() => outside.delete(recursive: true));
    final keep = File(p.join(outside.path, 'keep'));
    await keep.writeAsString('external');
    await Directory(layout.modelTempRoot).delete();
    await Link(layout.modelTempRoot).create(outside.path);

    expect(await _recovery([]).recover(layout: layout), 1);
    expect(await keep.readAsString(), 'external');
    expect(await Link(layout.modelTempRoot).exists(), isFalse);
  }, skip: Platform.isWindows ? 'Windows 测试环境不保证符号链接权限' : false);

  test('暂停后经过真实启动恢复，HTTP 从保留长度发送 Range 并完成校验', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final manifest = _manifest({
      'model.bin': 'hello',
    }, url: 'http://${server.address.address}:${server.port}/model.bin');
    final tempPath = layout.modelTempDirectory(
      manifest.modelId,
      manifest.version,
    );
    final finalPath = layout.modelVersionDirectory(
      manifest.modelId,
      manifest.version,
    );
    Future<RuntimeArtifactInstallResult> install(
      RuntimeArtifactDownload download,
    ) => const RuntimeArtifactInstallTransaction().install(
      manifest: manifest,
      tempPath: tempPath,
      finalPath: finalPath,
      tempRoot: layout.modelTempRoot,
      finalRoot: layout.modelsRoot,
      throwIfCanceled: () {},
      download: download,
    );
    await expectLater(
      install(({
        required file,
        required destinationPath,
        required resumeFrom,
        required onProgress,
      }) async {
        expect(resumeFrom, 0);
        await File(destinationPath).writeAsString('he', flush: true);
        throw const ModelDownloadCanceledException();
      }),
      throwsA(isA<ModelDownloadCanceledException>()),
    );
    final database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: layout.databasePath,
    );
    addTearDown(database.close);
    final errors = <Object>[];
    final recovery = StartupRecoveryService(
      database: database,
      layout: layout,
      modelTempRecovery: _recovery([
        RuntimeArtifactTempManifest(manifest: manifest),
      ]),
      reportError: (step, error, stackTrace) => errors.add(error),
    );
    final report = await recovery.recover(now: DateTime.utc(2026));
    expect(report.removedModelTempDirectories, 0);
    expect(errors, isEmpty);
    expect(await File(p.join(tempPath, 'model.bin')).length(), 2);

    final handled = server.first.then((request) async {
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=2-');
      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 2-4/5')
        ..contentLength = 3
        ..add(utf8.encode('llo'));
      await request.response.close();
    });
    final downloader = HttpModelFileDownloader(
      requireHttps: false,
      clientFactory: () => _RealHttpOverrides().createHttpClient(null),
    );
    final result = await install(({
      required file,
      required destinationPath,
      required resumeFrom,
      required onProgress,
    }) async {
      final outcome = await downloader.download(
        source: Uri.parse(file.url),
        destinationPath: destinationPath,
        resumeFrom: resumeFrom,
        expectedBytes: file.bytes,
        cancellation: ModelDownloadCancellationToken(),
        onProgress: onProgress,
      );
      return RuntimeArtifactDownloadOutcome(
        finalBytes: outcome.finalBytes,
        resumed: outcome.resumed,
      );
    });
    await handled;

    expect(result.resumed, isTrue);
    expect(result.verifiedBytes, 5);
    expect(await File(p.join(finalPath, 'model.bin')).readAsString(), 'hello');
    expect(await Directory(tempPath).exists(), isFalse);
    expect(
      await File(p.join(finalPath, RuntimeArtifactTempState.markerName))
          .exists(),
      isFalse,
    );
  });
}

ModelManifestEntry _manifest(Map<String, String> contents, {String? url}) =>
    ModelManifestEntry(
      modelId: 'model',
      version: 'v1',
      installationType: 'downloadable',
      requiredBytes: contents.values.fold(
        0,
        (sum, value) => sum + utf8.encode(value).length,
      ),
      files: [
        for (final entry in contents.entries)
          ModelManifestFile(
            path: entry.key,
            bytes: utf8.encode(entry.value).length,
            sha256: sha256.convert(utf8.encode(entry.value)).toString(),
            url: url ?? 'https://example.invalid/${entry.key}',
          ),
      ],
      license: const ModelLicense(name: 'test', noticePath: 'NOTICE'),
    );

ModelTempRecoveryService _recovery(
  List<RuntimeArtifactTempManifest> specifications,
) => ModelTempRecoveryService(loadManifests: () async => specifications);

Future<String> _seed(
  AppFileLayout layout,
  RuntimeArtifactTempManifest specification,
  Map<String, String> contents,
) async {
  final tempPath = layout.modelTempDirectory(
    specification.manifest.modelId,
    specification.manifest.version,
  );
  await const RuntimeArtifactTempState().prepare(
    tempPath: tempPath,
    tempRoot: layout.modelTempRoot,
    specification: specification,
  );
  for (final entry in contents.entries) {
    final file = File(p.join(tempPath, entry.key));
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
  }
  return tempPath;
}

final class _RealHttpOverrides extends HttpOverrides {}
