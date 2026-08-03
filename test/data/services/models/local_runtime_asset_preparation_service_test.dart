import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/models/downloadable_model_service.dart';
import 'package:meettrace/data/services/models/local_runtime_asset_preparation_service.dart';
import 'package:meettrace/data/services/models/model_manifest_parser.dart';
import 'package:meettrace/data/services/models/runtime_asset_installers.dart';
import 'package:meettrace/data/services/vad/downloadable_silero_vad_model.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/model_manifest.dart';
import 'package:meettrace/domain/models/runtime_initialization.dart';
import 'package:meettrace/domain/ports/runtime_asset_preparation.dart';
import 'package:path/path.dart' as p;

void main() {
  late _ModelInstaller models;
  late _VadInstaller vad;
  late _Capacity capacity;
  late _Network network;
  late _Consents consents;
  late LocalRuntimeAssetPreparationService service;

  setUp(() {
    models = _ModelInstaller();
    vad = _VadInstaller();
    capacity = _Capacity(minimumRuntimeInitializationFreeBytes);
    network = _Network(DownloadNetworkKind.unmetered);
    consents = _Consents();
    final root = Directory.current.path;
    final modelManifest =
        ModelManifestParser(
          registry: AsrModelRegistry.alpha,
          currentAppVersion: '1.0.0',
        ).parse(
          File(
            p.join(root, 'assets', 'models', 'manifest.json'),
          ).readAsStringSync(),
        );
    final vadManifest = const SileroVadManifestParser().parse(
      File(
        p.join(root, 'assets', 'models', 'silero-vad-manifest.json'),
      ).readAsStringSync(),
    );
    service = LocalRuntimeAssetPreparationService(
      registry: AsrModelRegistry.alpha,
      modelManifest: modelManifest,
      vadManifest: vadManifest,
      modelDownloads: models,
      vadDownloads: vad,
      capacity: capacity,
      network: network,
      consents: consents,
    );
  });

  test('本地资源完整时完全离线快速放行且不重新校验哈希', () async {
    models.ready = true;
    vad.ready = true;
    network.kind = DownloadNetworkKind.offline;
    final progress = <RuntimeInitializationProgress>[];

    await service.prepare(onProgress: progress.add);

    expect(progress.last.phase, RuntimeInitializationPhase.ready);
    expect(models.downloadCalls, 0);
    expect(vad.prepareCalls, 0);
    expect(capacity.calls, 0);
  });

  test('移动网络首次要求确认，同一资源版本授权后完成并可续传', () async {
    network.kind = DownloadNetworkKind.metered;

    await expectLater(
      service.prepare(onProgress: (_) {}),
      throwsA(
        isA<RuntimeInitializationException>()
            .having(
              (error) => error.code,
              'code',
              'runtime.network.mobileConsentRequired',
            )
            .having(
              (error) => error.message,
              'message',
              allOf(contains('239.8 MB'), contains('流量费用'), contains('续传')),
            ),
      ),
    );
    expect(models.downloadCalls, 0);

    await service.grantMobileConsent();
    await service.prepare(onProgress: (_) {});

    expect(await consents.hasConsent(service.resourceSetId), isTrue);
    expect(models.downloadCalls, 1);
    expect(vad.prepareCalls, 1);
  });

  test('移动网络同意标识包含每个固定文件的大小与哈希', () {
    expect(service.resourceSetId, contains('model.int8.onnx:239233841:c45ba1'));
    expect(service.resourceSetId, contains('tokens.txt:315894:f449eb'));
    expect(
      service.resourceSetId,
      contains('silero_vad.int8.onnx:212860:c36d49'),
    );
  });

  test('空间不足返回距离 768 MiB 的准确字节缺口', () async {
    capacity.freeBytes = minimumRuntimeInitializationFreeBytes - 123;

    await expectLater(
      service.prepare(onProgress: (_) {}),
      throwsA(
        isA<RuntimeInitializationException>()
            .having(
              (error) => error.code,
              'code',
              'runtime.storage.insufficient',
            )
            .having((error) => error.shortageBytes, 'shortageBytes', 123),
      ),
    );
  });

  test('Engine 失败进入强制修复时不被本地快速检查直接放行', () async {
    models.ready = true;
    vad.ready = true;

    await service.prepare(onProgress: (_) {}, forceRepair: true);

    expect(models.downloadCalls, 1);
    expect(models.forceDownloadCalls, 1);
    expect(vad.prepareCalls, 0);
  });
}

final class _ModelInstaller implements RuntimeAsrModelInstaller {
  bool ready = false;
  int downloadCalls = 0;
  int forceDownloadCalls = 0;

  @override
  Future<bool> isReadyFast({
    required AsrModelDescriptor descriptor,
    required ModelManifestEntry manifest,
  }) async => ready;

  @override
  Future<DownloadableModelResult> download({
    required AsrModelDescriptor descriptor,
    required ModelManifestEntry manifest,
    bool allowMeteredNetwork = false,
    ModelDownloadCancellationToken? cancellation,
    DownloadableModelProgressCallback? onProgress,
    bool skipPreflight = false,
    bool forceDownload = false,
  }) async {
    downloadCalls++;
    if (forceDownload) {
      forceDownloadCalls++;
    }
    onProgress?.call(
      DownloadableModelProgress(
        phase: DownloadableModelPhase.downloading,
        completedBytes: manifest.requiredBytes,
        totalBytes: manifest.requiredBytes,
      ),
    );
    return const DownloadableModelResult(
      installedPath: '/models/sense',
      alreadyInstalled: false,
      resumed: true,
    );
  }
}

final class _VadInstaller implements RuntimeVadInstaller {
  bool ready = false;
  int prepareCalls = 0;

  @override
  Future<bool> isReadyFast(SileroVadManifest manifest) async => ready;

  @override
  Future<String> prepare({
    required SileroVadManifest manifest,
    required ModelDownloadCancellationToken cancellation,
    void Function(int completedBytes, int totalBytes)? onProgress,
  }) async {
    prepareCalls++;
    onProgress?.call(manifest.requiredBytes, manifest.requiredBytes);
    return '/models/vad/${manifest.version}';
  }
}

final class _Capacity implements ModelStorageCapacityProvider {
  _Capacity(this.freeBytes);
  int freeBytes;
  int calls = 0;

  @override
  Future<int> getFreeBytes() async {
    calls++;
    return freeBytes;
  }
}

final class _Network implements DownloadNetworkStatusProvider {
  _Network(this.kind);
  DownloadNetworkKind kind;

  @override
  Future<DownloadNetworkKind> getCurrentKind() async => kind;
}

final class _Consents implements RuntimeDownloadConsentRepository {
  final Set<String> granted = {};

  @override
  Future<void> grant(String resourceSetId) async => granted.add(resourceSetId);

  @override
  Future<bool> hasConsent(String resourceSetId) async =>
      granted.contains(resourceSetId);
}
