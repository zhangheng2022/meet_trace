import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const whisperQualityCorpusSchemaVersion = 2;
const whisperQualityDeviceManifestSchemaVersion = 1;
const whisperQualitySampleRateHz = 16000;
const whisperQualityChannelCount = 1;
const whisperQualityEncoding = 'pcm16le';
const whisperQualityWindowSamples = 2 * whisperQualitySampleRateHz;
const whisperQualityMetricsSchemaVersion = 4;
const whisperAsrQualityRunMode = 'asr-quality';
const whisperVadPreflightRunMode = 'vad-preflight';
const whisperFixedWindowPipelineId = 'fixed-window-v1';
const whisperVadSegmentedPipelineId = 'vad-segmented-v1';
const whisperVadRecallCandidatePipelineId = 'vad-recall-035-v1';
const whisperQualityPipelineIds = {
  whisperFixedWindowPipelineId,
  whisperVadSegmentedPipelineId,
  whisperVadRecallCandidatePipelineId,
};
const whisperProductMeetingEvidenceClass = 'product-meeting';
const whisperPublicRegressionEvidenceClass = 'public-regression';
const whisperSyntheticSmokeEvidenceClass = 'synthetic-smoke';
const whisperSilenceTag = 'silence';
const whisperNoiseOnlyTag = 'noise-only';
const whisperSpeechTag = 'speech';
const whisperSpeechBoundaryStartTag = 'speech-boundary-start';
const whisperSpeechBoundaryEndTag = 'speech-boundary-end';
const whisperQualityEvidenceClasses = {
  whisperProductMeetingEvidenceClass,
  whisperPublicRegressionEvidenceClass,
  whisperSyntheticSmokeEvidenceClass,
};

enum WhisperQualityModelSource { bundledBase, deviceFile }

final class WhisperQualityDeviceRun {
  const WhisperQualityDeviceRun({
    required this.mode,
    required this.corpusId,
    required this.deviceId,
    required this.threadCount,
    required this.samples,
    required this.models,
    required this.pipelineIds,
  });

  final String mode;
  final String corpusId;
  final String deviceId;
  final int threadCount;
  final List<WhisperQualityDeviceSample> samples;
  final List<WhisperQualityDeviceModel> models;
  final List<String> pipelineIds;

  bool get isVadPreflight => mode == whisperVadPreflightRunMode;

  int get evaluationRunCount => isVadPreflight
      ? pipelineIds.length
      : models.fold(0, (total, model) => total + model.profileIds.length) *
            pipelineIds.length;

  static Future<WhisperQualityDeviceRun> load(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw WhisperQualityProtocolException('设备评测清单不存在：$path');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException catch (error) {
      throw WhisperQualityProtocolException('设备评测清单不是有效 JSON：${error.message}');
    }
    return WhisperQualityDeviceRun.fromJson(_map(decoded, 'device manifest'));
  }

  factory WhisperQualityDeviceRun.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != whisperQualityDeviceManifestSchemaVersion) {
      throw const WhisperQualityProtocolException('设备评测清单 schemaVersion 必须为 1');
    }
    final mode = switch (json['mode']) {
      null => whisperAsrQualityRunMode,
      final String value => value.trim(),
      _ => '',
    };
    if (mode != whisperAsrQualityRunMode &&
        mode != whisperVadPreflightRunMode) {
      throw const WhisperQualityProtocolException(
        '设备评测 mode 必须为 asr-quality 或 vad-preflight',
      );
    }
    final rawSamples = json['samples'];
    final rawModels = json['models'];
    final rawPipelineIds = json['pipelineIds'];
    if (rawSamples is! List<Object?> || rawSamples.isEmpty) {
      throw const WhisperQualityProtocolException('设备评测 samples 不能为空');
    }
    if (rawModels is! List<Object?>) {
      throw const WhisperQualityProtocolException('设备评测 models 必须是数组');
    }
    if (mode == whisperAsrQualityRunMode && rawModels.isEmpty) {
      throw const WhisperQualityProtocolException('ASR 设备评测 models 不能为空');
    }
    if (mode == whisperVadPreflightRunMode && rawModels.isNotEmpty) {
      throw const WhisperQualityProtocolException('VAD 预检不得加载 ASR models');
    }
    if (rawPipelineIds is! List<Object?> ||
        rawPipelineIds.isEmpty ||
        rawPipelineIds.any(
          (value) => !whisperQualityPipelineIds.contains(value),
        ) ||
        rawPipelineIds.toSet().length != rawPipelineIds.length) {
      throw const WhisperQualityProtocolException(
        '设备评测 pipelineIds 必须是不重复的已知 pipeline',
      );
    }
    if (mode == whisperVadPreflightRunMode &&
        rawPipelineIds.contains(whisperFixedWindowPipelineId)) {
      throw const WhisperQualityProtocolException('VAD 预检只允许 VAD pipeline');
    }
    final threadCount = json['threadCount'];
    if (threadCount is! int || threadCount <= 0 || threadCount > 32) {
      throw const WhisperQualityProtocolException(
        '设备评测 threadCount 必须在 1 到 32 之间',
      );
    }
    final samples = [
      for (var index = 0; index < rawSamples.length; index++)
        WhisperQualityDeviceSample.fromJson(
          _map(rawSamples[index], 'samples[$index]'),
        ),
    ];
    if (samples.map((sample) => sample.id).toSet().length != samples.length) {
      throw const WhisperQualityProtocolException('设备评测 sample id 不得重复');
    }
    return WhisperQualityDeviceRun(
      mode: mode,
      corpusId: _requiredText(json['corpusId'], 'corpusId'),
      deviceId: _requiredText(json['deviceId'], 'deviceId'),
      threadCount: threadCount,
      samples: List.unmodifiable(samples),
      models: List.unmodifiable([
        for (var index = 0; index < rawModels.length; index++)
          WhisperQualityDeviceModel.fromJson(
            _map(rawModels[index], 'models[$index]'),
          ),
      ]),
      pipelineIds: List.unmodifiable(rawPipelineIds.cast<String>()),
    );
  }
}

final class WhisperQualityDeviceSample {
  const WhisperQualityDeviceSample({
    required this.id,
    required this.path,
    required this.sha256,
    required this.byteLength,
    required this.durationMs,
    required this.expectedKeyFacts,
  });

  factory WhisperQualityDeviceSample.fromJson(Map<String, Object?> json) {
    final byteLength = json['bytes'];
    final durationMs = json['durationMs'];
    final rawFacts = json['expectedKeyFacts'];
    if (byteLength is! int || byteLength <= 0 || byteLength.isOdd) {
      throw const WhisperQualityProtocolException('设备 sample bytes 必须是正偶数');
    }
    if (durationMs is! num || !durationMs.isFinite || durationMs <= 0) {
      throw const WhisperQualityProtocolException(
        '设备 sample durationMs 必须是正有限数值',
      );
    }
    if (rawFacts is! List<Object?> ||
        rawFacts.any((value) => value is! String)) {
      throw const WhisperQualityProtocolException(
        '设备 sample expectedKeyFacts 必须是字符串数组',
      );
    }
    return WhisperQualityDeviceSample(
      id: _requiredText(json['id'], 'sample.id'),
      path: _requiredText(json['path'], 'sample.path'),
      sha256: _sha256(json['sha256'], 'sample.sha256'),
      byteLength: byteLength,
      durationMs: durationMs.toDouble(),
      expectedKeyFacts: List.unmodifiable(rawFacts.cast<String>()),
    );
  }

  final String id;
  final String path;
  final String sha256;
  final int byteLength;
  final double durationMs;
  final List<String> expectedKeyFacts;
}

final class WhisperQualityDeviceModel {
  const WhisperQualityDeviceModel({
    required this.modelId,
    required this.modelVersion,
    required this.source,
    required this.path,
    required this.profileIds,
  });

  factory WhisperQualityDeviceModel.fromJson(Map<String, Object?> json) {
    final sourceName = _requiredText(json['source'], 'model.source');
    final source = switch (sourceName) {
      'bundledBase' => WhisperQualityModelSource.bundledBase,
      'deviceFile' => WhisperQualityModelSource.deviceFile,
      _ => throw WhisperQualityProtocolException('未知 model.source：$sourceName'),
    };
    final rawProfileIds = json['profileIds'];
    if (rawProfileIds is! List<Object?> ||
        rawProfileIds.isEmpty ||
        rawProfileIds.any(
          (value) => value is! String || value.trim().isEmpty,
        )) {
      throw const WhisperQualityProtocolException(
        'model.profileIds 必须是非空字符串数组',
      );
    }
    final path = json['path'];
    if (source == WhisperQualityModelSource.deviceFile &&
        (path is! String || path.trim().isEmpty)) {
      throw const WhisperQualityProtocolException('deviceFile model 必须提供 path');
    }
    return WhisperQualityDeviceModel(
      modelId: _requiredText(json['modelId'], 'model.modelId'),
      modelVersion: _requiredText(json['modelVersion'], 'model.modelVersion'),
      source: source,
      path: path is String ? path.trim() : null,
      profileIds: List.unmodifiable(rawProfileIds.cast<String>()),
    );
  }

  final String modelId;
  final String modelVersion;
  final WhisperQualityModelSource source;
  final String? path;
  final List<String> profileIds;
}

final class WhisperQualityProtocolException implements Exception {
  const WhisperQualityProtocolException(this.message);

  final String message;

  @override
  String toString() => 'WhisperQualityProtocolException: $message';
}

final class WhisperQualityCorpus {
  WhisperQualityCorpus({
    required this.id,
    required this.deidentified,
    required this.evidenceClass,
    required this.provenance,
    required this.samples,
  });

  final String id;
  final bool deidentified;
  final String evidenceClass;
  final WhisperQualityCorpusProvenance provenance;
  final List<WhisperQualityCorpusSample> samples;

  static Future<WhisperQualityCorpus> load({
    required String manifestPath,
    required String repositoryRoot,
    Map<String, String>? environment,
    int minimumSampleCount = 20,
    String? requiredEvidenceClass,
  }) async {
    final manifestFile = File(p.normalize(p.absolute(manifestPath)));
    if (!await manifestFile.exists()) {
      throw WhisperQualityProtocolException(
        'Corpus manifest 不存在：${manifestFile.path}',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(await manifestFile.readAsString());
    } on FormatException catch (error) {
      throw WhisperQualityProtocolException(
        'Corpus manifest 不是有效 JSON：${error.message}',
      );
    }
    final manifest = _map(decoded, 'manifest');
    if (manifest['schemaVersion'] != whisperQualityCorpusSchemaVersion) {
      throw const WhisperQualityProtocolException(
        'manifest.schemaVersion 必须为 2',
      );
    }
    final deidentified = manifest['deidentified'];
    if (deidentified is! bool) {
      throw const WhisperQualityProtocolException(
        'manifest.deidentified 必须是布尔值',
      );
    }
    final evidenceClass = _requiredText(
      manifest['evidenceClass'],
      'manifest.evidenceClass',
    );
    if (!whisperQualityEvidenceClasses.contains(evidenceClass)) {
      throw const WhisperQualityProtocolException(
        'manifest.evidenceClass 必须为 product-meeting、'
        'public-regression 或 synthetic-smoke',
      );
    }
    if (evidenceClass == whisperProductMeetingEvidenceClass && !deidentified) {
      throw const WhisperQualityProtocolException(
        'product-meeting 语料必须声明 deidentified=true',
      );
    }
    if (requiredEvidenceClass != null &&
        evidenceClass != requiredEvidenceClass) {
      throw WhisperQualityProtocolException(
        '语料 evidenceClass 必须为 $requiredEvidenceClass，实际为 $evidenceClass',
      );
    }
    final provenance = WhisperQualityCorpusProvenance.fromJson(
      _map(manifest['provenance'], 'manifest.provenance'),
    );
    final audioFormat = _map(manifest['audioFormat'], 'manifest.audioFormat');
    if (audioFormat['encoding'] != whisperQualityEncoding ||
        audioFormat['sampleRateHz'] != whisperQualitySampleRateHz ||
        audioFormat['channels'] != whisperQualityChannelCount) {
      throw const WhisperQualityProtocolException(
        '语料必须为无文件头的 16 kHz 单声道 PCM16LE',
      );
    }
    final rawSamples = manifest['samples'];
    if (rawSamples is! List<Object?> ||
        rawSamples.length < minimumSampleCount) {
      throw WhisperQualityProtocolException(
        'manifest.samples 必须至少包含 $minimumSampleCount 段',
      );
    }

    final resolvedRepositoryRoot = p.normalize(p.absolute(repositoryRoot));
    final canonicalRepositoryRoot = p.normalize(
      await Directory(resolvedRepositoryRoot).resolveSymbolicLinks(),
    );
    final allowedSpikeRoot = p.join(resolvedRepositoryRoot, '.spike');
    final values = environment ?? Platform.environment;
    final ids = <String>{};
    final samples = <WhisperQualityCorpusSample>[];
    for (var index = 0; index < rawSamples.length; index++) {
      final raw = _map(rawSamples[index], 'manifest.samples[$index]');
      final id = _requiredText(raw['id'], 'manifest.samples[$index].id');
      if (!ids.add(id)) {
        throw WhisperQualityProtocolException('重复 sample id：$id');
      }
      final pathEnv = _requiredText(
        raw['pathEnv'],
        'manifest.samples[$index].pathEnv',
      );
      if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(pathEnv)) {
        throw WhisperQualityProtocolException(
          'manifest.samples[$index].pathEnv 必须是大写环境变量名',
        );
      }
      final sourcePathValue = values[pathEnv];
      if (sourcePathValue == null || sourcePathValue.trim().isEmpty) {
        throw WhisperQualityProtocolException('环境变量 $pathEnv 未配置');
      }
      final sourceFile = File(p.normalize(p.absolute(sourcePathValue)));
      if (!await sourceFile.exists()) {
        throw WhisperQualityProtocolException(
          'sample $id 的 PCM 文件不存在：${sourceFile.path}',
        );
      }
      if (p.extension(sourceFile.path).toLowerCase() != '.pcm') {
        throw WhisperQualityProtocolException('sample $id 必须使用 .pcm 文件');
      }
      final canonicalSourcePath = p.normalize(
        await sourceFile.resolveSymbolicLinks(),
      );
      if (_isWithin(canonicalRepositoryRoot, canonicalSourcePath)) {
        final spikeDirectory = Directory(allowedSpikeRoot);
        final insideAllowedSpike =
            await spikeDirectory.exists() &&
            _isWithin(
              p.normalize(await spikeDirectory.resolveSymbolicLinks()),
              canonicalSourcePath,
            );
        if (!insideAllowedSpike) {
          throw WhisperQualityProtocolException(
            'sample $id 必须位于仓库外或已忽略的 .spike 目录',
          );
        }
      }

      final byteLength = await sourceFile.length();
      if (byteLength <= 0 || byteLength.isOdd) {
        throw WhisperQualityProtocolException(
          'sample $id 必须是非空且字节数为偶数的 PCM16LE',
        );
      }
      final expectedSha256 = _sha256(
        raw['sha256'],
        'manifest.samples[$index].sha256',
      );
      final actualSha256 = (await sha256.bind(sourceFile.openRead()).first)
          .toString();
      if (actualSha256 != expectedSha256) {
        throw WhisperQualityProtocolException('sample $id SHA-256 不匹配');
      }
      final durationMs = _positiveNumber(
        raw['durationMs'],
        'manifest.samples[$index].durationMs',
      );
      final measuredDurationMs =
          byteLength * 1000 / (whisperQualitySampleRateHz * 2);
      if ((durationMs - measuredDurationMs).abs() > 1) {
        throw WhisperQualityProtocolException('sample $id 时长与 PCM 字节数不一致');
      }

      final tags = _textList(
        raw['tags'],
        'manifest.samples[$index].tags',
        allowEmpty: false,
      );
      final expectedKeyFacts = _textList(
        raw['expectedKeyFacts'] ?? const <Object?>[],
        'manifest.samples[$index].expectedKeyFacts',
      );
      _validateSampleSemantics(
        id: id,
        tags: tags,
        expectedKeyFacts: expectedKeyFacts,
      );
      samples.add(
        WhisperQualityCorpusSample(
          id: id,
          sourcePath: sourceFile.path,
          sha256: expectedSha256,
          byteLength: byteLength,
          durationMs: measuredDurationMs,
          tags: tags,
          expectedKeyFacts: expectedKeyFacts,
        ),
      );
    }
    if (evidenceClass == whisperProductMeetingEvidenceClass) {
      _validateProductMeetingCoverage(samples);
    }
    return WhisperQualityCorpus(
      id: _requiredText(manifest['id'], 'manifest.id'),
      deidentified: deidentified,
      evidenceClass: evidenceClass,
      provenance: provenance,
      samples: List.unmodifiable(samples),
    );
  }

  Map<String, Object?> toPreparedJson() => {
    'schemaVersion': whisperQualityCorpusSchemaVersion,
    'id': id,
    'deidentified': deidentified,
    'evidenceClass': evidenceClass,
    'provenance': provenance.toJson(),
    'audioFormat': const {
      'encoding': whisperQualityEncoding,
      'sampleRateHz': whisperQualitySampleRateHz,
      'channels': whisperQualityChannelCount,
    },
    'samples': [for (final sample in samples) sample.toPreparedJson()],
  };
}

final class WhisperQualityCorpusProvenance {
  const WhisperQualityCorpusProvenance({
    required this.sourceId,
    required this.licenseId,
  });

  factory WhisperQualityCorpusProvenance.fromJson(Map<String, Object?> json) {
    return WhisperQualityCorpusProvenance(
      sourceId: _requiredText(json['sourceId'], 'manifest.provenance.sourceId'),
      licenseId: _requiredText(
        json['licenseId'],
        'manifest.provenance.licenseId',
      ),
    );
  }

  final String sourceId;
  final String licenseId;

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'licenseId': licenseId,
  };
}

final class WhisperQualityCorpusSample {
  const WhisperQualityCorpusSample({
    required this.id,
    required this.sourcePath,
    required this.sha256,
    required this.byteLength,
    required this.durationMs,
    required this.tags,
    required this.expectedKeyFacts,
  });

  final String id;
  final String sourcePath;
  final String sha256;
  final int byteLength;
  final double durationMs;
  final List<String> tags;
  final List<String> expectedKeyFacts;

  Map<String, Object?> toPreparedJson() => {
    'id': id,
    'sourcePath': sourcePath,
    'sha256': sha256,
    'bytes': byteLength,
    'durationMs': durationMs,
    'tags': tags,
    'expectedKeyFacts': expectedKeyFacts,
  };
}

Iterable<Float32List> decodePcm16LeWindows(
  Uint8List bytes, {
  int windowSamples = whisperQualityWindowSamples,
}) sync* {
  if (bytes.isEmpty || bytes.length.isOdd) {
    throw const WhisperQualityProtocolException('PCM16LE 必须非空且字节数为偶数');
  }
  if (windowSamples <= 0) {
    throw const WhisperQualityProtocolException('windowSamples 必须大于 0');
  }
  final pcm = ByteData.sublistView(bytes);
  final sampleCount = bytes.length ~/ 2;
  for (var start = 0; start < sampleCount; start += windowSamples) {
    final length = (sampleCount - start).clamp(0, windowSamples);
    final samples = Float32List(length);
    for (var offset = 0; offset < length; offset++) {
      samples[offset] =
          pcm.getInt16((start + offset) * 2, Endian.little) / 32768;
    }
    yield samples;
  }
}

Float32List decodePcm16Le(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length.isOdd) {
    throw const WhisperQualityProtocolException('PCM16LE 必须非空且字节数为偶数');
  }
  final pcm = ByteData.sublistView(bytes);
  final samples = Float32List(bytes.length ~/ 2);
  for (var index = 0; index < samples.length; index++) {
    samples[index] = pcm.getInt16(index * 2, Endian.little) / 32768;
  }
  return samples;
}

List<String> recognizeExpectedKeyFacts({
  required String transcript,
  required List<String> expectedKeyFacts,
}) {
  final normalizedTranscript = _normalizeFactText(transcript);
  return [
    for (final fact in expectedKeyFacts)
      if (_normalizeFactText(fact).isNotEmpty &&
          normalizedTranscript.contains(_normalizeFactText(fact)))
        fact,
  ];
}

String _normalizeFactText(String value) => value.toLowerCase().replaceAll(
  RegExp(r'''[\s，。！？、,.!?;；:：'"“”‘’（）()\[\]【】<>《》\-—_]+'''),
  '',
);

void _validateSampleSemantics({
  required String id,
  required List<String> tags,
  required List<String> expectedKeyFacts,
}) {
  final tagSet = tags.toSet();
  if (tagSet.length != tags.length) {
    throw WhisperQualityProtocolException('sample $id 的 tags 不得重复');
  }
  final isSilence = tagSet.contains(whisperSilenceTag);
  final isNoiseOnly = tagSet.contains(whisperNoiseOnlyTag);
  final isSpeech = tagSet.contains(whisperSpeechTag);
  final isBoundary =
      tagSet.contains(whisperSpeechBoundaryStartTag) ||
      tagSet.contains(whisperSpeechBoundaryEndTag);
  if ((isSilence && (isNoiseOnly || isSpeech || isBoundary)) ||
      (isNoiseOnly && (isSpeech || isBoundary))) {
    throw WhisperQualityProtocolException(
      'sample $id 的 silence、noise-only 与 speech 标签互斥',
    );
  }
  if (isBoundary && !isSpeech) {
    throw WhisperQualityProtocolException('sample $id 的语音首尾标签必须同时声明 speech');
  }
  if ((isSilence || isNoiseOnly) && expectedKeyFacts.isNotEmpty) {
    throw WhisperQualityProtocolException('sample $id 的纯静音或纯噪声不得声明关键事实');
  }
  final normalizedFacts = <String>{};
  for (final fact in expectedKeyFacts) {
    final normalized = _normalizeFactText(fact);
    if (normalized.isEmpty) {
      throw WhisperQualityProtocolException('sample $id 的关键事实归一化后不得为空');
    }
    if (!normalizedFacts.add(normalized)) {
      throw WhisperQualityProtocolException('sample $id 的关键事实归一化后不得重复');
    }
  }
}

void _validateProductMeetingCoverage(List<WhisperQualityCorpusSample> samples) {
  int countTag(String tag) =>
      samples.where((sample) => sample.tags.contains(tag)).length;
  final silenceCount = countTag(whisperSilenceTag);
  final noiseOnlyCount = countTag(whisperNoiseOnlyTag);
  final keyFactSampleCount = samples
      .where(
        (sample) =>
            sample.tags.contains(whisperSpeechTag) &&
            sample.expectedKeyFacts.isNotEmpty,
      )
      .length;
  final boundaryStartCount = countTag(whisperSpeechBoundaryStartTag);
  final boundaryEndCount = countTag(whisperSpeechBoundaryEndTag);
  if (silenceCount < 20 ||
      noiseOnlyCount < 20 ||
      keyFactSampleCount < 20 ||
      boundaryStartCount < 1 ||
      boundaryEndCount < 1) {
    throw WhisperQualityProtocolException(
      'product-meeting 语料必须至少包含 20 段 silence、20 段 noise-only、'
      '20 段带关键事实的 speech，并同时覆盖语音起始和结束边界',
    );
  }
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw WhisperQualityProtocolException('$name 必须是对象');
  }
  return value;
}

String _requiredText(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw WhisperQualityProtocolException('$name 不能为空');
  }
  return value.trim();
}

String _sha256(Object? value, String name) {
  final text = _requiredText(value, name).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw WhisperQualityProtocolException('$name 必须是 64 位十六进制');
  }
  return text;
}

double _positiveNumber(Object? value, String name) {
  if (value is! num || !value.isFinite || value <= 0) {
    throw WhisperQualityProtocolException('$name 必须是正有限数值');
  }
  return value.toDouble();
}

List<String> _textList(Object? value, String name, {bool allowEmpty = true}) {
  if (value is! List<Object?> ||
      value.any((item) => item is! String || item.trim().isEmpty) ||
      (!allowEmpty && value.isEmpty)) {
    throw WhisperQualityProtocolException(
      '$name 必须是${allowEmpty ? '' : '非空'}字符串数组',
    );
  }
  return value
      .cast<String>()
      .map((item) => item.trim())
      .toList(growable: false);
}

bool _isWithin(String parent, String child) {
  final relative = p.relative(p.normalize(child), from: p.normalize(parent));
  return relative == '.' ||
      (relative != '..' && !relative.startsWith('..${p.separator}'));
}
