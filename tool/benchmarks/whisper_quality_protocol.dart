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
const whisperQualityEvidenceClasses = {
  whisperProductMeetingEvidenceClass,
  whisperPublicRegressionEvidenceClass,
  whisperSyntheticSmokeEvidenceClass,
};

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
      if (_isWithin(resolvedRepositoryRoot, sourceFile.path) &&
          !_isWithin(allowedSpikeRoot, sourceFile.path)) {
        throw WhisperQualityProtocolException(
          'sample $id 必须位于仓库外或已忽略的 .spike 目录',
        );
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

      samples.add(
        WhisperQualityCorpusSample(
          id: id,
          sourcePath: sourceFile.path,
          sha256: expectedSha256,
          byteLength: byteLength,
          durationMs: measuredDurationMs,
          tags: _textList(
            raw['tags'],
            'manifest.samples[$index].tags',
            allowEmpty: false,
          ),
          expectedKeyFacts: _textList(
            raw['expectedKeyFacts'] ?? const <Object?>[],
            'manifest.samples[$index].expectedKeyFacts',
          ),
        ),
      );
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
