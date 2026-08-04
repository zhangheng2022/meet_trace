import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../../domain/models/model_manifest.dart';

const speakerDiarizationManifestAssetPath =
    'assets/models/speaker-diarization-manifest.json';
const speakerDiarizationModelId =
    'sherpa-onnx-speaker-diarization-pyannote-3-0-3dspeaker-eres2net-base';
const speakerDiarizationModelVersion = '2024-10-14';
const speakerDiarizationDownloadBytes = 46552205;
const speakerSegmentationArchivePath =
    '.downloads/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2';
const speakerSegmentationArchiveBytes = 6958444;
const speakerSegmentationArchiveSha256 =
    '24615ee884c897d9d2ba09bb4d30da6bb1b15e685065962db5b02e76e4996488';
const speakerSegmentationModelPath = 'segmentation/model.int8.onnx';
const speakerEmbeddingModelFileName =
    '3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx';
const speakerEmbeddingModelPath = 'embedding/$speakerEmbeddingModelFileName';
const speakerEmbeddingModelBytes = 39593761;
const speakerEmbeddingModelSha256 =
    '1a331345f04805badbb495c775a6ddffcdd1a732567d5ec8b3d5749e3c7a5e4b';
const speakerDiarizationSampleRate = 16000;
const speakerDiarizationNumThreads = 2;
const speakerDiarizationProvider = 'cpu';
const speakerDiarizationNumClusters = -1;
const speakerDiarizationClusteringThreshold = 0.5;
const speakerDiarizationMinDurationOn = 0.2;
const speakerDiarizationMinDurationOff = 0.5;

const _segmentationArchiveUrl =
    'https://mt.zhangheng.eu.org/models/SpeakerDiarization/'
    'sherpa-onnx-pyannote-segmentation-3-0.tar.bz2';
const _embeddingModelUrl =
    'https://mt.zhangheng.eu.org/models/SpeakerDiarization/'
    '$speakerEmbeddingModelFileName';
const _segmentationArchiveRoot = 'sherpa-onnx-pyannote-segmentation-3-0';
const _segmentationArchiveAllowedEntries = <String>{
  '$_segmentationArchiveRoot/model.int8.onnx',
  '$_segmentationArchiveRoot/LICENSE',
  '$_segmentationArchiveRoot/vad-onnx.py',
  '$_segmentationArchiveRoot/speaker-diarization-torch.py',
  '$_segmentationArchiveRoot/vad-torch.py',
  '$_segmentationArchiveRoot/run.sh',
  '$_segmentationArchiveRoot/README.md',
  '$_segmentationArchiveRoot/speaker-diarization-onnx.py',
  '$_segmentationArchiveRoot/model.onnx',
  '$_segmentationArchiveRoot/show-onnx.py',
  '$_segmentationArchiveRoot/export-onnx.py',
};

final class SpeakerDiarizationArchiveInstallFile {
  const SpeakerDiarizationArchiveInstallFile({
    required this.archivePath,
    required this.file,
  });

  final String archivePath;
  final ModelManifestFile file;
}

final class SpeakerDiarizationArchive {
  SpeakerDiarizationArchive({
    required this.download,
    required Set<String> allowedEntries,
    required List<SpeakerDiarizationArchiveInstallFile> installFiles,
  }) : allowedEntries = Set.unmodifiable(allowedEntries),
       installFiles = List.unmodifiable(installFiles);

  final ModelManifestFile download;
  final Set<String> allowedEntries;
  final List<SpeakerDiarizationArchiveInstallFile> installFiles;
}

final class SpeakerDiarizationEmbeddingModel {
  const SpeakerDiarizationEmbeddingModel({
    required this.download,
    required this.installation,
  });

  final ModelManifestFile download;
  final ModelManifestFile installation;
}

final class RuntimeAssetLicense {
  const RuntimeAssetLicense({
    required this.name,
    required this.noticePath,
    required this.licensePath,
  });

  final String name;
  final String noticePath;
  final String licensePath;
}

final class SpeakerDiarizationInferenceConfig {
  const SpeakerDiarizationInferenceConfig({
    required this.sampleRate,
    required this.numThreads,
    required this.provider,
    required this.numClusters,
    required this.clusteringThreshold,
    required this.minDurationOn,
    required this.minDurationOff,
  });

  final int sampleRate;
  final int numThreads;
  final String provider;
  final int numClusters;
  final double clusteringThreshold;
  final double minDurationOn;
  final double minDurationOff;
}

final class SpeakerDiarizationManifest {
  const SpeakerDiarizationManifest({
    required this.schemaVersion,
    required this.modelId,
    required this.version,
    required this.requiredBytes,
    required this.segmentationArchive,
    required this.embeddingModel,
    required this.inference,
    required this.segmentationLicense,
    required this.embeddingLicense,
  });

  final int schemaVersion;
  final String modelId;
  final String version;
  final int requiredBytes;
  final SpeakerDiarizationArchive segmentationArchive;
  final SpeakerDiarizationEmbeddingModel embeddingModel;
  final SpeakerDiarizationInferenceConfig inference;
  final RuntimeAssetLicense segmentationLicense;
  final RuntimeAssetLicense embeddingLicense;

  ModelManifestEntry get downloadManifest => ModelManifestEntry(
    modelId: modelId,
    version: version,
    installationType: 'downloadable',
    requiredBytes: requiredBytes,
    files: [segmentationArchive.download, embeddingModel.download],
    license: ModelLicense(
      name: '${segmentationLicense.name} + ${embeddingLicense.name}',
      noticePath: segmentationLicense.noticePath,
    ),
  );

  ModelManifestEntry get installationManifest {
    final files = [
      for (final extracted in segmentationArchive.installFiles) extracted.file,
      embeddingModel.installation,
    ];
    return ModelManifestEntry(
      modelId: modelId,
      version: version,
      installationType: 'downloadable',
      requiredBytes: files.fold(0, (sum, file) => sum + file.bytes),
      files: files,
      license: ModelLicense(
        name: '${segmentationLicense.name} + ${embeddingLicense.name}',
        noticePath: segmentationLicense.noticePath,
      ),
    );
  }
}

final class SpeakerDiarizationManifestParser {
  const SpeakerDiarizationManifestParser();

  SpeakerDiarizationManifest parse(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('说话人 Manifest 顶层必须是对象');
    }
    final schemaVersion = _requiredInt(decoded, 'schemaVersion');
    final modelId = _requiredText(decoded, 'modelId');
    final version = _requiredText(decoded, 'version');
    final requiredBytes = _requiredInt(decoded, 'requiredBytes');
    if (schemaVersion != 1 ||
        modelId != speakerDiarizationModelId ||
        version != speakerDiarizationModelVersion ||
        requiredBytes != speakerDiarizationDownloadBytes) {
      throw const FormatException('说话人 Manifest 与固定版本契约不一致');
    }

    final archiveJson = _requiredMap(decoded, 'segmentationArchive');
    final archiveDownload = _downloadFile(archiveJson);
    if (archiveDownload.path != speakerSegmentationArchivePath ||
        archiveDownload.bytes != speakerSegmentationArchiveBytes ||
        archiveDownload.sha256 != speakerSegmentationArchiveSha256 ||
        archiveDownload.url != _segmentationArchiveUrl) {
      throw const FormatException('Pyannote 归档与固定发布资产不一致');
    }
    final allowedEntries = _requiredStringSet(archiveJson, 'allowedEntries');
    if (allowedEntries.length != _segmentationArchiveAllowedEntries.length ||
        !allowedEntries.containsAll(_segmentationArchiveAllowedEntries)) {
      throw const FormatException('Pyannote 归档白名单与固定文件集不一致');
    }
    final installFiles = _archiveInstallFiles(archiveJson, archiveDownload.url);
    final installByArchivePath = {
      for (final file in installFiles) file.archivePath: file,
    };
    if (installByArchivePath.length != 2 ||
        installByArchivePath['$_segmentationArchiveRoot/model.int8.onnx']
                ?.file
                .path !=
            speakerSegmentationModelPath ||
        installByArchivePath['$_segmentationArchiveRoot/model.int8.onnx']
                ?.file
                .bytes !=
            1540506 ||
        installByArchivePath['$_segmentationArchiveRoot/model.int8.onnx']
                ?.file
                .sha256 !=
            'd582f4b4c6b48205de7e0643c57df0df5615a3c176189be3fc461e9d18827b5d' ||
        installByArchivePath['$_segmentationArchiveRoot/LICENSE']?.file.path !=
            'segmentation/LICENSE' ||
        installByArchivePath['$_segmentationArchiveRoot/LICENSE']?.file.bytes !=
            1061 ||
        installByArchivePath['$_segmentationArchiveRoot/LICENSE']
                ?.file
                .sha256 !=
            '14d7016ad68e7394d6e6b78d96cc2ae431c905287b89674cfdf021e79e62b8ba') {
      throw const FormatException('Pyannote 安装文件与固定 INT8 契约不一致');
    }
    if (installFiles.any(
      (file) => !allowedEntries.contains(file.archivePath),
    )) {
      throw const FormatException('Pyannote 提取文件不在归档白名单中');
    }

    final embeddingJson = _requiredMap(decoded, 'embeddingModel');
    final embeddingDownload = _downloadFile(embeddingJson);
    final embeddingInstallPath = _safePath(
      _requiredText(embeddingJson, 'installPath'),
    );
    if (embeddingDownload.path != '.downloads/$speakerEmbeddingModelFileName' ||
        embeddingInstallPath != speakerEmbeddingModelPath ||
        embeddingDownload.bytes != speakerEmbeddingModelBytes ||
        embeddingDownload.sha256 != speakerEmbeddingModelSha256 ||
        embeddingDownload.url != _embeddingModelUrl) {
      throw const FormatException('3D-Speaker 模型与固定发布资产不一致');
    }

    final inferenceJson = _requiredMap(decoded, 'inference');
    final inference = SpeakerDiarizationInferenceConfig(
      sampleRate: _requiredInt(inferenceJson, 'sampleRate'),
      numThreads: _requiredInt(inferenceJson, 'numThreads'),
      provider: _requiredText(inferenceJson, 'provider'),
      numClusters: _requiredInt(inferenceJson, 'numClusters'),
      clusteringThreshold: _requiredDouble(
        inferenceJson,
        'clusteringThreshold',
      ),
      minDurationOn: _requiredDouble(inferenceJson, 'minDurationOn'),
      minDurationOff: _requiredDouble(inferenceJson, 'minDurationOff'),
    );
    if (inference.sampleRate != speakerDiarizationSampleRate ||
        inference.numThreads != speakerDiarizationNumThreads ||
        inference.provider != speakerDiarizationProvider ||
        inference.numClusters != speakerDiarizationNumClusters ||
        inference.clusteringThreshold !=
            speakerDiarizationClusteringThreshold ||
        inference.minDurationOn != speakerDiarizationMinDurationOn ||
        inference.minDurationOff != speakerDiarizationMinDurationOff) {
      throw const FormatException('说话人推理配置与固定 Alpha 契约不一致');
    }

    final licenses = _requiredMap(decoded, 'licenses');
    final segmentationLicense = _license(
      _requiredMap(licenses, 'segmentation'),
    );
    final embeddingLicense = _license(_requiredMap(licenses, 'embedding'));
    if (segmentationLicense.name != 'MIT' ||
        segmentationLicense.noticePath !=
            'assets/licenses/pyannote-segmentation-NOTICE.txt' ||
        segmentationLicense.licensePath !=
            'assets/licenses/pyannote-segmentation-LICENSE.txt' ||
        embeddingLicense.name != 'Apache-2.0' ||
        embeddingLicense.noticePath !=
            'assets/licenses/3d-speaker-NOTICE.txt' ||
        embeddingLicense.licensePath !=
            'assets/licenses/3d-speaker-LICENSE.txt') {
      throw const FormatException('说话人模型许可声明与固定契约不一致');
    }

    final downloadTotal = archiveDownload.bytes + embeddingDownload.bytes;
    if (downloadTotal != requiredBytes) {
      throw const FormatException('说话人 requiredBytes 与下载文件合计不一致');
    }
    return SpeakerDiarizationManifest(
      schemaVersion: schemaVersion,
      modelId: modelId,
      version: version,
      requiredBytes: requiredBytes,
      segmentationArchive: SpeakerDiarizationArchive(
        download: archiveDownload,
        allowedEntries: allowedEntries,
        installFiles: installFiles,
      ),
      embeddingModel: SpeakerDiarizationEmbeddingModel(
        download: embeddingDownload,
        installation: ModelManifestFile(
          path: embeddingInstallPath,
          bytes: embeddingDownload.bytes,
          sha256: embeddingDownload.sha256,
          url: embeddingDownload.url,
        ),
      ),
      inference: inference,
      segmentationLicense: segmentationLicense,
      embeddingLicense: embeddingLicense,
    );
  }
}

List<SpeakerDiarizationArchiveInstallFile> _archiveInstallFiles(
  Map<String, dynamic> archive,
  String sourceUrl,
) {
  final raw = archive['installFiles'];
  if (raw is! List<dynamic> || raw.isEmpty) {
    throw const FormatException('Pyannote installFiles 必须是非空数组');
  }
  final result = <SpeakerDiarizationArchiveInstallFile>[];
  final archivePaths = <String>{};
  final targetPaths = <String>{};
  for (final value in raw) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Pyannote 安装文件条目必须是对象');
    }
    final archivePath = _safePath(_requiredText(value, 'archivePath'));
    final targetPath = _safePath(_requiredText(value, 'path'));
    if (!archivePaths.add(archivePath) || !targetPaths.add(targetPath)) {
      throw const FormatException('Pyannote 安装文件路径不得重复');
    }
    result.add(
      SpeakerDiarizationArchiveInstallFile(
        archivePath: archivePath,
        file: ModelManifestFile(
          path: targetPath,
          bytes: _requiredPositiveInt(value, 'bytes'),
          sha256: _sha256(value, 'sha256'),
          url: sourceUrl,
        ),
      ),
    );
  }
  return result;
}

ModelManifestFile _downloadFile(Map<String, dynamic> json) {
  final url = _requiredText(json, 'url');
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const FormatException('运行资源下载只允许 HTTPS');
  }
  return ModelManifestFile(
    path: _safePath(_requiredText(json, 'path')),
    bytes: _requiredPositiveInt(json, 'bytes'),
    sha256: _sha256(json, 'sha256'),
    url: url,
  );
}

RuntimeAssetLicense _license(Map<String, dynamic> json) => RuntimeAssetLicense(
  name: _requiredText(json, 'name'),
  noticePath: _safePath(_requiredText(json, 'noticePath')),
  licensePath: _safePath(_requiredText(json, 'licensePath')),
);

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key 必须是对象');
  }
  return value;
}

Set<String> _requiredStringSet(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List<dynamic> || value.isEmpty) {
    throw FormatException('$key 必须是非空数组');
  }
  final result = <String>{};
  for (final item in value) {
    if (item is! String || !result.add(_safePath(item))) {
      throw FormatException('$key 必须包含不重复的安全路径');
    }
  }
  return result;
}

String _sha256(Map<String, dynamic> json, String key) {
  final value = _requiredText(json, key).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw FormatException('$key 必须是 64 位 SHA-256');
  }
  return value;
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串');
  }
  return value.trim();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key 必须是整数');
  }
  return value;
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = _requiredInt(json, key);
  if (value <= 0) {
    throw FormatException('$key 必须大于 0');
  }
  return value;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('$key 必须是有限数值');
  }
  return value.toDouble();
}

String _safePath(String value) {
  final normalized = value.replaceAll(r'\', '/');
  if (normalized.contains('\u0000') ||
      p.posix.isAbsolute(normalized) ||
      RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
      normalized
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw FormatException('不安全的相对路径：$value');
  }
  return normalized;
}
