import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'whisper_quality_protocol.dart';

const reviewedCorpusAttestationSchemaVersion = 1;

final class ReviewedCorpusPromotionException implements Exception {
  const ReviewedCorpusPromotionException(this.message);

  final String message;

  @override
  String toString() => 'ReviewedCorpusPromotionException: $message';
}

final class ReviewedCorpusPromotionResult {
  const ReviewedCorpusPromotionResult({
    required this.outputPath,
    required this.corpusId,
    required this.sampleCount,
    required this.reviewAttestationSha256,
  });

  final String outputPath;
  final String corpusId;
  final int sampleCount;
  final String reviewAttestationSha256;
}

final class ReviewedCorpusTemplateResult {
  const ReviewedCorpusTemplateResult({
    required this.outputPath,
    required this.sampleCount,
    required this.candidateManifestSha256,
  });

  final String outputPath;
  final int sampleCount;
  final String candidateManifestSha256;
}

/// Promotes a private candidate corpus only after an explicit human review
/// attestation passes all product-meeting evidence checks.
final class ReviewedCorpusPromoter {
  const ReviewedCorpusPromoter();

  Future<ReviewedCorpusTemplateResult> writeReviewTemplate({
    required String candidateManifestPath,
    required String environmentPath,
    required String repositoryRoot,
    required String outputPath,
  }) async {
    final resolvedRepositoryRoot = p.normalize(p.absolute(repositoryRoot));
    final candidateFile = File(p.normalize(p.absolute(candidateManifestPath)));
    final environmentFile = File(p.normalize(p.absolute(environmentPath)));
    final outputFile = File(p.normalize(p.absolute(outputPath)));
    await _validateOutputLocation(
      outputFile: outputFile,
      repositoryRoot: resolvedRepositoryRoot,
      protectedInputs: [candidateFile, environmentFile],
    );

    final candidateBytes = await _readBytes(candidateFile, '候选 manifest');
    final candidate = _decodeObject(candidateBytes, '候选 manifest');
    final environment = _stringMap(
      _decodeObject(await _readBytes(environmentFile, '私有环境映射'), '私有环境映射'),
      '私有环境映射',
    );
    final candidateCorpus = await WhisperQualityCorpus.load(
      manifestPath: candidateFile.path,
      repositoryRoot: resolvedRepositoryRoot,
      environment: environment,
      minimumSampleCount: 1,
      requiredEvidenceClass: whisperSyntheticSmokeEvidenceClass,
    );
    if (candidateCorpus.deidentified) {
      throw const ReviewedCorpusPromotionException(
        '候选 manifest 必须保留 deidentified=false，才能生成待人工确认模板',
      );
    }
    final samples = _objectList(candidate['samples'], 'candidate.samples');
    final template = <String, Object?>{
      'schemaVersion': reviewedCorpusAttestationSchemaVersion,
      'candidateManifestSha256': sha256.convert(candidateBytes).toString(),
      'corpusId': '',
      'reviewedAtUtc': '',
      'reviewedByRole': '',
      'deidentificationAttested': false,
      'samples': [
        for (var index = 0; index < samples.length; index++)
          _reviewTemplateSample(samples[index], index),
      ],
    };
    await outputFile.parent.create(recursive: true);
    await _writeValidatedOutputExclusively(
      outputFile,
      utf8.encode('${const JsonEncoder.withIndent('  ').convert(template)}\n'),
    );
    return ReviewedCorpusTemplateResult(
      outputPath: outputFile.path,
      sampleCount: samples.length,
      candidateManifestSha256: template['candidateManifestSha256']! as String,
    );
  }

  Future<ReviewedCorpusPromotionResult> promote({
    required String candidateManifestPath,
    required String reviewAttestationPath,
    required String environmentPath,
    required String repositoryRoot,
    required String outputPath,
  }) async {
    final resolvedRepositoryRoot = p.normalize(p.absolute(repositoryRoot));
    final candidateFile = File(p.normalize(p.absolute(candidateManifestPath)));
    final reviewFile = File(p.normalize(p.absolute(reviewAttestationPath)));
    final environmentFile = File(p.normalize(p.absolute(environmentPath)));
    final outputFile = File(p.normalize(p.absolute(outputPath)));

    await _validateOutputLocation(
      outputFile: outputFile,
      repositoryRoot: resolvedRepositoryRoot,
      protectedInputs: [candidateFile, reviewFile, environmentFile],
    );
    final candidateBytes = await _readBytes(candidateFile, '候选 manifest');
    final reviewBytes = await _readBytes(reviewFile, '人工复核证明');
    final candidate = _decodeObject(candidateBytes, '候选 manifest');
    final review = _decodeObject(reviewBytes, '人工复核证明');
    final environment = _stringMap(
      _decodeObject(await _readBytes(environmentFile, '私有环境映射'), '私有环境映射'),
      '私有环境映射',
    );

    final candidateHash = sha256.convert(candidateBytes).toString();
    final reviewHash = sha256.convert(reviewBytes).toString();
    final candidateCorpus = await WhisperQualityCorpus.load(
      manifestPath: candidateFile.path,
      repositoryRoot: resolvedRepositoryRoot,
      environment: environment,
      minimumSampleCount: 1,
      requiredEvidenceClass: whisperSyntheticSmokeEvidenceClass,
    );
    if (candidateCorpus.deidentified) {
      throw const ReviewedCorpusPromotionException(
        '候选 manifest 必须保留 deidentified=false，正式去敏只能由人工复核证明',
      );
    }

    final promoted = _buildPromotedManifest(
      candidate: candidate,
      candidateCorpus: candidateCorpus,
      candidateHash: candidateHash,
      review: review,
      reviewHash: reviewHash,
    );

    await outputFile.parent.create(recursive: true);
    final temporaryDirectory = await outputFile.parent.createTemp(
      '.meettrace-corpus-promotion-',
    );
    final temporaryFile = File(
      p.join(temporaryDirectory.path, p.basename(outputFile.path)),
    );
    try {
      await temporaryFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(promoted)}\n',
        flush: true,
      );
      final validated = await WhisperQualityCorpus.load(
        manifestPath: temporaryFile.path,
        repositoryRoot: resolvedRepositoryRoot,
        environment: environment,
        requiredEvidenceClass: whisperProductMeetingEvidenceClass,
      );
      await _writeValidatedOutputExclusively(
        outputFile,
        await temporaryFile.readAsBytes(),
      );
      return ReviewedCorpusPromotionResult(
        outputPath: outputFile.path,
        corpusId: validated.id,
        sampleCount: validated.samples.length,
        reviewAttestationSha256: reviewHash,
      );
    } finally {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  }
}

Map<String, Object?> _reviewTemplateSample(
  Map<String, Object?> candidateSample,
  int index,
) {
  final id = _requiredText(
    candidateSample['id'],
    'candidate.samples[$index].id',
  );
  final tags = _textList(
    candidateSample['tags'],
    'candidate.samples[$index].tags',
  );
  final proposedClasses = {
    for (final tag in tags)
      if (tag == whisperSilenceTag ||
          tag == whisperNoiseOnlyTag ||
          tag == whisperSpeechTag)
        tag,
  };
  return {
    'id': id,
    'candidateSuggestion': proposedClasses.length == 1
        ? proposedClasses.single
        : null,
    'approved': false,
    'containsSensitiveData': null,
    'reviewedClass': '',
    'expectedKeyFacts': <String>[],
    'boundaryStart': false,
    'boundaryEnd': false,
  };
}

Map<String, Object?> _buildPromotedManifest({
  required Map<String, Object?> candidate,
  required WhisperQualityCorpus candidateCorpus,
  required String candidateHash,
  required Map<String, Object?> review,
  required String reviewHash,
}) {
  if (review['schemaVersion'] != reviewedCorpusAttestationSchemaVersion) {
    throw const ReviewedCorpusPromotionException('人工复核证明 schemaVersion 必须为 1');
  }
  if (_sha256Text(
        review['candidateManifestSha256'],
        'candidateManifestSha256',
      ) !=
      candidateHash) {
    throw const ReviewedCorpusPromotionException(
      '人工复核证明绑定的候选 manifest SHA-256 不匹配',
    );
  }
  if (review['deidentificationAttested'] != true) {
    throw const ReviewedCorpusPromotionException(
      '人工复核证明必须明确 deidentificationAttested=true',
    );
  }
  _requiredText(review['reviewedByRole'], 'reviewedByRole');
  final reviewedAtUtc = _utcTimestamp(review['reviewedAtUtc'], 'reviewedAtUtc');
  final corpusId = _requiredText(review['corpusId'], 'corpusId');

  final candidateSamples = _objectList(
    candidate['samples'],
    'candidate.samples',
  );
  final candidateById = <String, Map<String, Object?>>{};
  for (var index = 0; index < candidateSamples.length; index++) {
    final sample = candidateSamples[index];
    final id = _requiredText(sample['id'], 'candidate.samples[$index].id');
    if (candidateById[id] != null) {
      throw ReviewedCorpusPromotionException('候选 manifest 存在重复 sample id：$id');
    }
    candidateById[id] = sample;
  }
  final loadedIds = candidateCorpus.samples.map((sample) => sample.id).toSet();
  if (loadedIds.length != candidateById.length ||
      !loadedIds.containsAll(candidateById.keys)) {
    throw const ReviewedCorpusPromotionException('候选 manifest 原始样本与已校验样本不一致');
  }

  final reviews = _objectList(review['samples'], 'samples');
  final reviewById = <String, Map<String, Object?>>{};
  for (var index = 0; index < reviews.length; index++) {
    final item = reviews[index];
    final id = _requiredText(item['id'], 'samples[$index].id');
    if (reviewById[id] != null) {
      throw ReviewedCorpusPromotionException('人工复核证明存在重复 sample id：$id');
    }
    reviewById[id] = item;
  }
  final missingIds = candidateById.keys
      .where((id) => !reviewById.containsKey(id))
      .toList();
  final extraIds = reviewById.keys
      .where((id) => !candidateById.containsKey(id))
      .toList();
  if (missingIds.isNotEmpty || extraIds.isNotEmpty) {
    throw ReviewedCorpusPromotionException(
      '人工复核样本必须与候选 manifest 完全一致；'
      '缺少 ${missingIds.length} 段，多出 ${extraIds.length} 段',
    );
  }

  final promotedSamples = <Map<String, Object?>>[];
  for (final candidateSample in candidateSamples) {
    final id = _requiredText(candidateSample['id'], 'candidate sample id');
    final reviewed = reviewById[id]!;
    final approved = _requiredBool(reviewed['approved'], 'sample $id approved');
    final containsSensitiveData = _requiredBool(
      reviewed['containsSensitiveData'],
      'sample $id containsSensitiveData',
    );
    final expectedKeyFacts = _textList(
      reviewed['expectedKeyFacts'],
      'sample $id expectedKeyFacts',
    );
    final boundaryStart = _requiredBool(
      reviewed['boundaryStart'],
      'sample $id boundaryStart',
    );
    final boundaryEnd = _requiredBool(
      reviewed['boundaryEnd'],
      'sample $id boundaryEnd',
    );
    if (!approved) {
      if (expectedKeyFacts.isNotEmpty || boundaryStart || boundaryEnd) {
        throw ReviewedCorpusPromotionException(
          'sample $id 未批准时不得包含关键事实或语音首尾边界',
        );
      }
      continue;
    }
    if (containsSensitiveData) {
      throw ReviewedCorpusPromotionException(
        'sample $id 必须明确 containsSensitiveData=false',
      );
    }
    final classification = _requiredText(
      reviewed['reviewedClass'],
      'sample $id reviewedClass',
    );
    if (classification != whisperSilenceTag &&
        classification != whisperNoiseOnlyTag &&
        classification != whisperSpeechTag) {
      throw ReviewedCorpusPromotionException(
        'sample $id reviewedClass 必须为 silence、noise-only 或 speech',
      );
    }
    if (classification == whisperSpeechTag && expectedKeyFacts.isEmpty) {
      throw ReviewedCorpusPromotionException(
        'sample $id 的 speech 人工标签必须至少包含一个关键事实',
      );
    }
    if (classification != whisperSpeechTag &&
        (expectedKeyFacts.isNotEmpty || boundaryStart || boundaryEnd)) {
      throw ReviewedCorpusPromotionException(
        'sample $id 的非 speech 标签不得包含关键事实或语音首尾边界',
      );
    }
    promotedSamples.add({
      'id': id,
      'pathEnv': _requiredText(
        candidateSample['pathEnv'],
        'candidate sample $id pathEnv',
      ),
      'sha256': _sha256Text(
        candidateSample['sha256'],
        'candidate sample $id sha256',
      ),
      'durationMs': _positiveNumber(
        candidateSample['durationMs'],
        'candidate sample $id durationMs',
      ),
      'tags': [
        classification,
        if (boundaryStart) whisperSpeechBoundaryStartTag,
        if (boundaryEnd) whisperSpeechBoundaryEndTag,
      ],
      'expectedKeyFacts': expectedKeyFacts,
    });
  }

  final candidateProvenance = _object(
    candidate['provenance'],
    'candidate.provenance',
  );
  return {
    'schemaVersion': whisperQualityCorpusSchemaVersion,
    'id': corpusId,
    'deidentified': true,
    'evidenceClass': whisperProductMeetingEvidenceClass,
    'provenance': {
      'sourceId': _requiredText(
        candidateProvenance['sourceId'],
        'candidate.provenance.sourceId',
      ),
      'licenseId': _requiredText(
        candidateProvenance['licenseId'],
        'candidate.provenance.licenseId',
      ),
      'reviewAttestationSha256': reviewHash,
      'reviewedAtUtc': reviewedAtUtc,
    },
    'audioFormat': const {
      'encoding': whisperQualityEncoding,
      'sampleRateHz': whisperQualitySampleRateHz,
      'channels': whisperQualityChannelCount,
    },
    'samples': promotedSamples,
  };
}

Future<void> _validateOutputLocation({
  required File outputFile,
  required String repositoryRoot,
  required List<File> protectedInputs,
}) async {
  if (p.extension(outputFile.path).toLowerCase() != '.json') {
    throw const ReviewedCorpusPromotionException('输出必须使用 .json 扩展名');
  }
  if (await outputFile.exists()) {
    throw ReviewedCorpusPromotionException('输出已存在，拒绝覆盖：${outputFile.path}');
  }
  for (final input in protectedInputs) {
    if (p.equals(input.path, outputFile.path)) {
      throw const ReviewedCorpusPromotionException('输出不得覆盖任何输入文件');
    }
  }
  if (_isWithin(repositoryRoot, outputFile.path)) {
    final spikeRoot = p.join(repositoryRoot, '.spike');
    if (!_isWithin(spikeRoot, outputFile.path) ||
        p.equals(spikeRoot, outputFile.path)) {
      throw const ReviewedCorpusPromotionException('仓库内输出必须位于已忽略的 .spike 子目录');
    }
    await outputFile.parent.create(recursive: true);
    final canonicalSpikeRoot = p.normalize(
      await Directory(spikeRoot).resolveSymbolicLinks(),
    );
    final canonicalOutputParent = p.normalize(
      await outputFile.parent.resolveSymbolicLinks(),
    );
    if (!_isWithin(
      canonicalSpikeRoot,
      p.join(canonicalOutputParent, p.basename(outputFile.path)),
    )) {
      throw const ReviewedCorpusPromotionException(
        '输出路径经符号链接解析后必须仍位于 .spike 边界内',
      );
    }
  }
}

Future<void> _writeValidatedOutputExclusively(
  File outputFile,
  List<int> bytes,
) async {
  var created = false;
  try {
    await outputFile.create(exclusive: true);
    created = true;
    await outputFile.writeAsBytes(bytes, flush: true);
  } catch (_) {
    if (created && await outputFile.exists()) {
      await outputFile.delete();
    }
    rethrow;
  }
}

Future<List<int>> _readBytes(File file, String name) async {
  if (!await file.exists()) {
    throw ReviewedCorpusPromotionException('$name 不存在：${file.path}');
  }
  return file.readAsBytes();
}

Map<String, Object?> _decodeObject(List<int> bytes, String name) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (error) {
    throw ReviewedCorpusPromotionException('$name 不是有效 JSON：${error.message}');
  }
  return _object(decoded, name);
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw ReviewedCorpusPromotionException('$name 必须是 JSON 对象');
  }
  return value;
}

List<Map<String, Object?>> _objectList(Object? value, String name) {
  if (value is! List<Object?>) {
    throw ReviewedCorpusPromotionException('$name 必须是对象数组');
  }
  return [
    for (var index = 0; index < value.length; index++)
      _object(value[index], '$name[$index]'),
  ];
}

Map<String, String> _stringMap(Map<String, Object?> value, String name) {
  final result = <String, String>{};
  for (final entry in value.entries) {
    final item = entry.value;
    if (item is! String || item.trim().isEmpty) {
      throw ReviewedCorpusPromotionException('$name.${entry.key} 必须是非空字符串');
    }
    result[entry.key] = item;
  }
  return result;
}

String _requiredText(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw ReviewedCorpusPromotionException('$name 不能为空');
  }
  return value.trim();
}

String _sha256Text(Object? value, String name) {
  final text = _requiredText(value, name).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw ReviewedCorpusPromotionException('$name 必须是 64 位十六进制');
  }
  return text;
}

String _utcTimestamp(Object? value, String name) {
  final text = _requiredText(value, name);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !text.endsWith('Z') || !parsed.isUtc) {
    throw ReviewedCorpusPromotionException('$name 必须是以 Z 结尾的 ISO 8601 UTC 时间');
  }
  return text;
}

List<String> _textList(Object? value, String name) {
  if (value is! List<Object?> ||
      value.any((item) => item is! String || item.trim().isEmpty)) {
    throw ReviewedCorpusPromotionException('$name 必须是字符串数组');
  }
  return value
      .cast<String>()
      .map((item) => item.trim())
      .toList(growable: false);
}

bool _requiredBool(Object? value, String name) {
  if (value is! bool) {
    throw ReviewedCorpusPromotionException('$name 必须是布尔值');
  }
  return value;
}

num _positiveNumber(Object? value, String name) {
  if (value is! num || !value.isFinite || value <= 0) {
    throw ReviewedCorpusPromotionException('$name 必须是正有限数值');
  }
  return value;
}

bool _isWithin(String parent, String child) {
  final relative = p.relative(p.normalize(child), from: p.normalize(parent));
  return relative == '.' ||
      (relative != '..' && !relative.startsWith('..${p.separator}'));
}
