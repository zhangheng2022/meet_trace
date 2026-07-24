import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/repositories/repository_contracts.dart';
import 'package:meetily_ai/data/services/models/downloadable_model_service.dart';
import 'package:meetily_ai/data/services/models/model_file_verifier.dart';
import 'package:meetily_ai/data/services/storage/app_file_layout.dart';
import 'package:meetily_ai/domain/models/asr_model.dart';
import 'package:meetily_ai/domain/models/model_installation.dart';
import 'package:meetily_ai/domain/models/model_manifest.dart';
import 'package:meetily_ai/domain/models/model_usage_lease.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late AppFileLayout layout;
  late _MemoryInstallations installations;
  late _MemoryLeases leases;
  late _FakeDownloader downloader;
  late _FakeCapacity capacity;
  late _FakeNetwork network;
  late DownloadableModelService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meetily-model-download-');
    layout = AppFileLayout(rootPath: root.path);
    installations = _MemoryInstallations();
    leases = _MemoryLeases();
    downloader = _FakeDownloader(_sourceBytes);
    capacity = _FakeCapacity(3 * 1024 * 1024 * 1024);
    network = _FakeNetwork(DownloadNetworkKind.unmetered);
    service = DownloadableModelService(
      fileLayout: layout,
      installations: installations,
      leases: leases,
      capacity: capacity,
      network: network,
      downloader: downloader,
      verifier: const ModelFileVerifier(),
      now: () => DateTime.utc(2026, 7, 24, 12),
    );
  });

  tearDown(() => root.delete(recursive: true));

  test('可用空间不足 2 GiB 时在发起网络请求前失败', () async {
    capacity.freeBytes = 2 * 1024 * 1024 * 1024 - 1;

    await expectLater(
      service.download(descriptor: _descriptor, manifest: _manifest),
      throwsA(
        isA<DownloadableModelException>().having(
          (error) => error.code,
          'code',
          'model.storage.insufficient',
        ),
      ),
    );

    expect(downloader.calls, isEmpty);
    expect(installations.current?.state, ModelInstallationState.failed);
  });

  test('移动网络需要明确确认后才能下载', () async {
    network.kind = DownloadNetworkKind.metered;

    await expectLater(
      service.download(descriptor: _descriptor, manifest: _manifest),
      throwsA(
        isA<DownloadableModelException>().having(
          (error) => error.code,
          'code',
          'model.network.confirmationRequired',
        ),
      ),
    );

    final result = await service.download(
      descriptor: _descriptor,
      manifest: _manifest,
      allowMeteredNetwork: true,
    );

    expect(result.installedPath, endsWith(p.join('qwen', '2')));
    expect(downloader.calls, hasLength(2));
  });

  test('无网络时不发起下载且不产生 installed 状态', () async {
    network.kind = DownloadNetworkKind.offline;

    await expectLater(
      service.download(descriptor: _descriptor, manifest: _manifest),
      throwsA(
        isA<DownloadableModelException>().having(
          (error) => error.code,
          'code',
          'model.network.offline',
        ),
      ),
    );

    expect(downloader.calls, isEmpty);
    expect(installations.current?.state, ModelInstallationState.failed);
    expect(await installations.getActiveVersion(_descriptor.modelId), isNull);
  });

  test('下载完成后严格校验、原子安装并切换活动版本', () async {
    final progress = <DownloadableModelProgress>[];

    final result = await service.download(
      descriptor: _descriptor,
      manifest: _manifest,
      onProgress: progress.add,
    );

    expect(result.alreadyInstalled, isFalse);
    expect(
      await installations.getActiveVersion(_descriptor.modelId),
      _descriptor.version,
    );
    expect(installations.current?.state, ModelInstallationState.installed);
    expect(
      progress.last,
      isA<DownloadableModelProgress>()
          .having((value) => value.phase, 'phase', DownloadableModelPhase.ready)
          .having((value) => value.completedBytes, 'bytes', 10),
    );
    expect(
      File(p.join(result.installedPath, 'a.bin')).readAsStringSync(),
      'hello',
    );
  });

  test('取消下载保留临时文件和 paused 状态且不产生最终目录', () async {
    final cancellation = ModelDownloadCancellationToken();
    downloader.cancelAfterBytes = 2;
    downloader.cancellation = cancellation;

    await expectLater(
      service.download(
        descriptor: _descriptor,
        manifest: _manifest,
        cancellation: cancellation,
      ),
      throwsA(
        isA<DownloadableModelException>().having(
          (error) => error.code,
          'code',
          'model.download.canceled',
        ),
      ),
    );

    expect(installations.current?.state, ModelInstallationState.paused);
    expect(
      Directory(
        layout.modelVersionDirectory(_descriptor.modelId, _descriptor.version),
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        p.join(
          layout.modelTempDirectory(_descriptor.modelId, _descriptor.version),
          'a.bin',
        ),
      ).lengthSync(),
      2,
    );
  });

  test('取消后重试从临时文件长度续传并完成安装', () async {
    final cancellation = ModelDownloadCancellationToken();
    downloader.cancelAfterBytes = 2;
    downloader.cancellation = cancellation;
    await expectLater(
      service.download(
        descriptor: _descriptor,
        manifest: _manifest,
        cancellation: cancellation,
      ),
      throwsA(isA<DownloadableModelException>()),
    );

    downloader
      ..cancelAfterBytes = null
      ..cancellation = null;
    final result = await service.download(
      descriptor: _descriptor,
      manifest: _manifest,
    );

    expect(result.installedPath, isNotEmpty);
    expect(
      downloader.calls.any(
        (call) => call.path == 'a.bin' && call.resumeFrom == 2,
      ),
      isTrue,
    );
  });

  test('新版本校验失败时保留旧版本文件与活动指针', () async {
    const oldVersion = '1';
    final oldPath = layout.modelVersionDirectory(
      _descriptor.modelId,
      oldVersion,
    );
    await Directory(oldPath).create(recursive: true);
    await File(p.join(oldPath, 'old.bin')).writeAsString('old');
    await installations.saveInstalledAndActivate(
      ModelInstallation(
        modelId: _descriptor.modelId,
        version: oldVersion,
        installationType: AsrInstallationType.downloadable,
        state: ModelInstallationState.installed,
        installedPath: oldPath,
        verifiedAt: DateTime.utc(2026, 7, 23),
        bytes: 3,
      ),
    );
    downloader.bytesByUrl[_manifest.files.first.url] = utf8.encode('xxxxx');

    await expectLater(
      service.download(descriptor: _descriptor, manifest: _manifest),
      throwsA(
        isA<DownloadableModelException>().having(
          (error) => error.code,
          'code',
          'model.integrity',
        ),
      ),
    );

    expect(Directory(oldPath).existsSync(), isTrue);
    expect(
      await installations.getActiveVersion(_descriptor.modelId),
      oldVersion,
    );
  });

  test('活动租约存在时拒绝删除并返回占用者', () async {
    final installedPath = await _install(service);
    leases.active.add(
      ModelUsageLease(
        leaseId: 'lease-1',
        modelId: _descriptor.modelId,
        version: _descriptor.version,
        ownerId: 'meeting-1',
        acquiredAt: DateTime.utc(2026, 7, 24, 11),
        expiresAt: DateTime.utc(2026, 7, 24, 13),
      ),
    );

    await expectLater(
      service.delete(descriptor: _descriptor),
      throwsA(
        isA<DownloadableModelException>()
            .having((error) => error.code, 'code', 'model.inUse')
            .having((error) => error.message, 'message', contains('meeting-1')),
      ),
    );

    expect(Directory(installedPath).existsSync(), isTrue);
    expect(installations.current, isNotNull);
  });

  test('删除高级模型只移除版本目录、安装记录和活动指针', () async {
    final installedPath = await _install(service);
    final unrelated = File(p.join(root.path, 'meetings', 'history.json'));
    await unrelated.create(recursive: true);
    await unrelated.writeAsString('keep');

    final result = await service.delete(descriptor: _descriptor);

    expect(result.deleted, isTrue);
    expect(Directory(installedPath).existsSync(), isFalse);
    expect(installations.current, isNull);
    expect(await installations.getActiveVersion(_descriptor.modelId), isNull);
    expect(unrelated.readAsStringSync(), 'keep');
  });
}

Future<String> _install(DownloadableModelService service) async {
  final result = await service.download(
    descriptor: _descriptor,
    manifest: _manifest,
  );
  return result.installedPath;
}

final _sourceBytes = <String, List<int>>{
  'https://example.com/a.bin': utf8.encode('hello'),
  'https://example.com/b.bin': utf8.encode('world'),
};

final _descriptor = AsrModelDescriptor(
  modelId: 'qwen',
  displayName: '高级模型',
  tier: AsrModelTier.advanced,
  version: '2',
  supportedLanguages: const ['multilingual'],
  installationType: AsrInstallationType.downloadable,
  requiredBytes: 10,
  capabilities: const {'offline'},
);

final _manifest = ModelManifestEntry(
  modelId: 'qwen',
  version: '2',
  tier: 'advanced',
  installationType: 'downloadable',
  requiredBytes: 10,
  files: [
    ModelManifestFile(
      path: 'a.bin',
      bytes: 5,
      sha256: sha256.convert(utf8.encode('hello')).toString(),
      url: 'https://example.com/a.bin',
    ),
    ModelManifestFile(
      path: 'b.bin',
      bytes: 5,
      sha256: sha256.convert(utf8.encode('world')).toString(),
      url: 'https://example.com/b.bin',
    ),
  ],
  license: const ModelLicense(name: 'test', noticePath: 'licenses/test.txt'),
);

final class _FakeCapacity implements ModelStorageCapacityProvider {
  _FakeCapacity(this.freeBytes);

  int freeBytes;

  @override
  Future<int> getFreeBytes() async => freeBytes;
}

final class _FakeNetwork implements DownloadNetworkStatusProvider {
  _FakeNetwork(this.kind);

  DownloadNetworkKind kind;

  @override
  Future<DownloadNetworkKind> getCurrentKind() async => kind;
}

final class _DownloadCall {
  const _DownloadCall({required this.path, required this.resumeFrom});

  final String path;
  final int resumeFrom;
}

final class _FakeDownloader implements ModelFileDownloader {
  _FakeDownloader(Map<String, List<int>> source)
    : bytesByUrl = Map<String, List<int>>.from(source);

  final Map<String, List<int>> bytesByUrl;
  final List<_DownloadCall> calls = [];
  int? cancelAfterBytes;
  ModelDownloadCancellationToken? cancellation;

  @override
  Future<ModelFileDownloadResult> download({
    required Uri source,
    required String destinationPath,
    required int resumeFrom,
    required int expectedBytes,
    required ModelDownloadCancellationToken cancellation,
    required void Function(int absoluteFileBytes) onProgress,
  }) async {
    final bytes = bytesByUrl[source.toString()]!;
    calls.add(
      _DownloadCall(path: p.basename(destinationPath), resumeFrom: resumeFrom),
    );
    final output = await File(
      destinationPath,
    ).open(mode: resumeFrom == 0 ? FileMode.write : FileMode.append);
    var written = resumeFrom;
    try {
      for (final byte in bytes.skip(resumeFrom)) {
        cancellation.throwIfCanceled();
        await output.writeByte(byte);
        written++;
        onProgress(written);
        if (cancelAfterBytes != null && written >= cancelAfterBytes!) {
          this.cancellation?.cancel();
          cancellation.throwIfCanceled();
        }
      }
      await output.flush();
    } finally {
      await output.close();
    }
    return ModelFileDownloadResult(
      finalBytes: written,
      resumed: resumeFrom > 0,
    );
  }
}

final class _MemoryInstallations implements ActiveModelInstallationRepository {
  ModelInstallation? current;
  final Map<String, String> activeVersions = {};

  @override
  Future<ModelInstallation?> get({
    required String modelId,
    required String version,
  }) async {
    final value = current;
    return value?.modelId == modelId && value?.version == version
        ? value
        : null;
  }

  @override
  Future<String?> getActiveVersion(String modelId) async {
    return activeVersions[modelId];
  }

  @override
  Future<void> save(ModelInstallation installation) async {
    current = installation;
  }

  @override
  Future<void> saveInstalledAndActivate(ModelInstallation installation) async {
    current = installation;
    activeVersions[installation.modelId] = installation.version;
  }

  @override
  Future<void> deleteAndDeactivate({
    required String modelId,
    required String version,
  }) async {
    if (current?.modelId == modelId && current?.version == version) {
      current = null;
    }
    if (activeVersions[modelId] == version) {
      activeVersions.remove(modelId);
    }
  }

  @override
  Stream<List<ModelInstallation>> watchAll() async* {
    yield [?current];
  }
}

final class _MemoryLeases implements ModelUsageLeaseRepository {
  final List<ModelUsageLease> active = [];

  @override
  Future<List<ModelUsageLease>> listActive({
    required String modelId,
    required String version,
    required DateTime now,
  }) async {
    return active
        .where(
          (lease) =>
              lease.modelId == modelId &&
              lease.version == version &&
              lease.expiresAt.isAfter(now),
        )
        .toList();
  }

  @override
  Future<void> release(String leaseId) async {
    active.removeWhere((lease) => lease.leaseId == leaseId);
  }

  @override
  Future<void> save(ModelUsageLease lease) async {
    active
      ..removeWhere((item) => item.leaseId == lease.leaseId)
      ..add(lease);
  }

  @override
  Future<int> deleteExpired(DateTime now) async {
    final before = active.length;
    active.removeWhere((lease) => !lease.expiresAt.isAfter(now));
    return before - active.length;
  }
}
