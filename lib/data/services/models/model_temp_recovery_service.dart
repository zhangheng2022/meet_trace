import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../domain/models/asr_model_registry.dart';
import '../../models/runtime/silero_vad_manifest.dart';
import '../../models/runtime/speaker_diarization_manifest.dart';
import '../storage/app_file_layout.dart';
import 'model_manifest_parser.dart';
import 'runtime_artifact_temp_state.dart';

export 'runtime_artifact_temp_state.dart' show RuntimeArtifactTempManifest;

typedef RuntimeArtifactTempManifestLoader =
    Future<List<RuntimeArtifactTempManifest>> Function();

/// 保留当前固定 Manifest 的可续传下载，清理过期和不可信临时内容。
final class ModelTempRecoveryService {
  const ModelTempRecoveryService({
    this.loadManifests = loadCurrentRuntimeArtifactTempManifests,
  });

  final RuntimeArtifactTempManifestLoader loadManifests;

  Future<int> recover({required AppFileLayout layout}) async {
    final modelsType = await FileSystemEntity.type(
      layout.modelsRoot,
      followLinks: false,
    );
    if (modelsType == FileSystemEntityType.notFound) {
      return 0;
    }
    if (modelsType != FileSystemEntityType.directory) {
      throw FileSystemException('运行资源根目录不是普通目录', layout.modelsRoot);
    }
    final root = Directory(layout.modelTempRoot);
    final rootType = await FileSystemEntity.type(root.path, followLinks: false);
    if (rootType == FileSystemEntityType.notFound) {
      return 0;
    }
    if (rootType != FileSystemEntityType.directory) {
      await deleteRuntimeTempEntity(
        path: root.path,
        allowedRoot: layout.modelsRoot,
      );
      return 1;
    }
    if (await root.list(followLinks: false).isEmpty) {
      return 0;
    }
    // 先完整读取可信资源；读取失败时保留暂存，不能误判为所有版本过期。
    final specifications = await loadManifests();
    final current = <String, RuntimeArtifactTempManifest>{};
    for (final specification in specifications) {
      final entry = specification.manifest;
      final path = layout.modelTempDirectory(entry.modelId, entry.version);
      if (current.containsKey(path)) {
        throw const FormatException('运行资源临时清单包含重复版本');
      }
      specification.files;
      current[path] = specification;
    }
    var removed = 0;
    await for (final model in root.list(followLinks: false)) {
      if (model is! Directory) {
        await deleteRuntimeTempEntity(path: model.path, allowedRoot: root.path);
        removed++;
        continue;
      }
      await for (final version in model.list(followLinks: false)) {
        final specification = current[p.normalize(p.absolute(version.path))];
        final retain =
            version is Directory &&
            specification != null &&
            await const RuntimeArtifactTempState().recoverDirectory(
              tempPath: version.path,
              specification: specification,
            );
        if (!retain) {
          await deleteRuntimeTempEntity(
            path: version.path,
            allowedRoot: root.path,
          );
          removed++;
        }
      }
      if (await model.list(followLinks: false).isEmpty) {
        await model.delete();
      }
    }
    return removed;
  }
}

Future<List<RuntimeArtifactTempManifest>>
loadCurrentRuntimeArtifactTempManifests() async {
  final models =
      ModelManifestParser(
        registry: AsrModelRegistry.alpha,
        currentAppVersion: '1.0.0',
      ).parse(
        await rootBundle.loadString(
          'assets/models/manifest.json',
          cache: false,
        ),
      );
  final vad = const SileroVadManifestParser().parse(
    await rootBundle.loadString(sileroVadManifestAssetPath, cache: false),
  );
  final speaker = const SpeakerDiarizationManifestParser().parse(
    await rootBundle.loadString(
      speakerDiarizationManifestAssetPath,
      cache: false,
    ),
  );
  return [
    for (final manifest in models.models)
      RuntimeArtifactTempManifest(manifest: manifest),
    RuntimeArtifactTempManifest(manifest: vad.verificationEntry),
    RuntimeArtifactTempManifest(
      manifest: speaker.downloadManifest,
      downloadSubdirectory: 'download',
    ),
  ];
}
