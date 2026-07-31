import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'whisper_quality_protocol.dart';

final class WhisperQualityObservationMergeException implements Exception {
  const WhisperQualityObservationMergeException(this.message);

  final String message;

  @override
  String toString() => 'WhisperQualityObservationMergeException: $message';
}

final class WhisperQualityObservationMergeResult {
  const WhisperQualityObservationMergeResult({
    required this.outputPath,
    required this.batchCount,
    required this.combinationCount,
    required this.observationCount,
    required this.pipelineIds,
  });

  final String outputPath;
  final int batchCount;
  final int combinationCount;
  final int observationCount;
  final List<String> pipelineIds;
}

final class WhisperQualityObservationMerger {
  const WhisperQualityObservationMerger();

  Future<WhisperQualityObservationMergeResult> merge({
    required String corpusManifestPath,
    required List<String> inputPaths,
    required String repositoryRoot,
    required String outputPath,
    bool overwrite = false,
  }) async {
    if (inputPaths.isEmpty) {
      throw const WhisperQualityObservationMergeException('至少需要一个批次输入');
    }
    final repository = p.normalize(p.absolute(repositoryRoot));
    final manifestFile = File(p.normalize(p.absolute(corpusManifestPath)));
    final outputFile = File(p.normalize(p.absolute(outputPath)));
    final inputFiles = [
      for (final path in inputPaths) File(p.normalize(p.absolute(path))),
    ];
    final privateRoot = await _validateOutput(
      outputFile: outputFile,
      repositoryRoot: repository,
      protectedInputs: [manifestFile, ...inputFiles],
      overwrite: overwrite,
    );
    for (var index = 0; index < inputFiles.length; index++) {
      await _validatePrivateInput(
        inputFiles[index],
        privateRoot: privateRoot,
        label: '批次 ${index + 1}',
      );
    }

    final manifestBytes = await _readBytes(manifestFile, 'corpus manifest');
    final manifest = _decodeObject(manifestBytes, 'corpus manifest');
    if (manifest['schemaVersion'] != whisperQualityCorpusSchemaVersion) {
      throw const WhisperQualityObservationMergeException(
        'corpus manifest schemaVersion 必须为 2',
      );
    }
    final corpusId = _requiredText(manifest['id'], 'manifest.id');
    final corpusDeidentified = _requiredBool(
      manifest['deidentified'],
      'manifest.deidentified',
    );
    final corpusEvidenceClass = _requiredText(
      manifest['evidenceClass'],
      'manifest.evidenceClass',
    );
    final manifestSha256 = sha256.convert(manifestBytes).toString();
    final sampleIds = _manifestSampleIds(manifest);

    Map<String, Object?>? referenceExecution;
    final pipelineIds = <String>{};
    final observations = <Map<String, Object?>>[];
    final observationKeys = <String>{};
    final combinationSamples = <String, Set<String>>{};
    final batches = <Map<String, Object?>>[];
    for (var batchIndex = 0; batchIndex < inputFiles.length; batchIndex++) {
      final inputFile = inputFiles[batchIndex];
      final bytes = await _readBytes(inputFile, '批次 ${batchIndex + 1}');
      final batch = _decodeObject(bytes, '批次 ${batchIndex + 1}');
      if (batch['schemaVersion'] != whisperQualityMetricsSchemaVersion) {
        throw WhisperQualityObservationMergeException(
          '批次 ${batchIndex + 1} schemaVersion 必须为 '
          '$whisperQualityMetricsSchemaVersion',
        );
      }
      final execution = _object(
        batch['execution'],
        '批次 ${batchIndex + 1}.execution',
      );
      _validateCorpusAttestation(
        execution: execution,
        corpusId: corpusId,
        corpusDeidentified: corpusDeidentified,
        corpusEvidenceClass: corpusEvidenceClass,
        manifestSha256: manifestSha256,
        batchIndex: batchIndex,
      );
      if (referenceExecution == null) {
        referenceExecution = execution;
      } else {
        _validateExecutionCompatibility(
          reference: referenceExecution,
          candidate: execution,
          batchIndex: batchIndex,
        );
      }
      final declaredPipelines = _textList(
        execution['pipelineIds'],
        '批次 ${batchIndex + 1}.execution.pipelineIds',
      );
      if (declaredPipelines.isEmpty) {
        throw WhisperQualityObservationMergeException(
          '批次 ${batchIndex + 1} 必须声明至少一条 pipeline',
        );
      }
      final batchObservations = _objectList(
        batch['observations'],
        '批次 ${batchIndex + 1}.observations',
      );
      if (batchObservations.isEmpty) {
        throw WhisperQualityObservationMergeException(
          '批次 ${batchIndex + 1} observations 不能为空',
        );
      }
      final observedBatchPipelines = <String>{};
      for (var index = 0; index < batchObservations.length; index++) {
        final observation = Map<String, Object?>.from(batchObservations[index]);
        final sampleId = _requiredText(
          observation['sampleId'],
          '批次 ${batchIndex + 1}.observations[$index].sampleId',
        );
        if (!sampleIds.contains(sampleId)) {
          throw WhisperQualityObservationMergeException(
            '批次 ${batchIndex + 1} 包含 manifest 外样本：$sampleId',
          );
        }
        final modelId = _requiredText(
          observation['modelId'],
          'observation.modelId',
        );
        final modelVersion = _requiredText(
          observation['modelVersion'],
          'observation.modelVersion',
        );
        final profileId = _requiredText(
          observation['profileId'],
          'observation.profileId',
        );
        final pipelineId = _requiredText(
          observation['pipelineId'],
          'observation.pipelineId',
        );
        final deviceId = _requiredText(
          observation['deviceId'],
          'observation.deviceId',
        );
        if (deviceId != execution['deviceId']) {
          throw WhisperQualityObservationMergeException(
            '批次 ${batchIndex + 1} observation.deviceId 与 execution 不一致',
          );
        }
        observedBatchPipelines.add(pipelineId);
        pipelineIds.add(pipelineId);
        final combinationKey = [
          modelId,
          modelVersion,
          profileId,
          pipelineId,
          deviceId,
        ].join('\u0000');
        final observationKey = '$combinationKey\u0000$sampleId';
        if (!observationKeys.add(observationKey)) {
          throw WhisperQualityObservationMergeException(
            '重复观测：$sampleId / $modelId / $profileId / $pipelineId',
          );
        }
        combinationSamples
            .putIfAbsent(combinationKey, () => <String>{})
            .add(sampleId);
        await _rewriteTranscriptReference(
          observation: observation,
          inputFile: inputFile,
          outputFile: outputFile,
          privateRoot: privateRoot,
        );
        observations.add(observation);
      }
      if (observedBatchPipelines.length != declaredPipelines.toSet().length ||
          !observedBatchPipelines.containsAll(declaredPipelines)) {
        throw WhisperQualityObservationMergeException(
          '批次 ${batchIndex + 1} pipeline 声明与观测不一致',
        );
      }
      batches.add({
        'ref': _privateReference(
          from: outputFile.parent.path,
          target: inputFile.path,
          privateRoot: privateRoot,
        ),
        'sha256': sha256.convert(bytes).toString(),
      });
    }

    for (final entry in combinationSamples.entries) {
      if (entry.value.length != sampleIds.length ||
          !entry.value.containsAll(sampleIds)) {
        throw WhisperQualityObservationMergeException(
          '组合 ${entry.key.replaceAll('\u0000', ' / ')} '
          '未完整覆盖 manifest 的 ${sampleIds.length} 个样本',
        );
      }
    }
    final sortedPipelineIds = pipelineIds.toList()..sort();
    final execution = Map<String, Object?>.from(referenceExecution!)
      ..['capturedAtUtc'] = DateTime.now().toUtc().toIso8601String()
      ..['pipelineIds'] = sortedPipelineIds
      ..['mergedBatchEvidence'] = batches;
    final merged = <String, Object?>{
      'schemaVersion': whisperQualityMetricsSchemaVersion,
      'execution': execution,
      'observations': observations,
    };

    await outputFile.parent.create(recursive: true);
    final temporaryDirectory = await outputFile.parent.createTemp(
      '.meettrace-observation-merge-',
    );
    final temporaryFile = File(
      p.join(temporaryDirectory.path, p.basename(outputFile.path)),
    );
    try {
      await temporaryFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(merged)}\n',
        flush: true,
      );
      if (overwrite) {
        await _replaceOutputWithRollback(
          outputFile: outputFile,
          temporaryFile: temporaryFile,
        );
      } else {
        await _writeValidatedOutputExclusively(
          outputFile,
          await temporaryFile.readAsBytes(),
        );
      }
    } finally {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
    return WhisperQualityObservationMergeResult(
      outputPath: outputFile.path,
      batchCount: inputFiles.length,
      combinationCount: combinationSamples.length,
      observationCount: observations.length,
      pipelineIds: List.unmodifiable(sortedPipelineIds),
    );
  }
}

Future<void> _replaceOutputWithRollback({
  required File outputFile,
  required File temporaryFile,
}) async {
  File? previousOutput;
  Directory? backupDirectory;
  if (await outputFile.exists()) {
    backupDirectory = await outputFile.parent.createTemp(
      '.meettrace-previous-observation-',
    );
    try {
      previousOutput = await outputFile.rename(
        p.join(backupDirectory.path, p.basename(outputFile.path)),
      );
    } catch (_) {
      await backupDirectory.delete(recursive: true);
      rethrow;
    }
  }
  try {
    await temporaryFile.rename(outputFile.path);
  } catch (error) {
    if (!await outputFile.exists() &&
        previousOutput != null &&
        await previousOutput.exists()) {
      await previousOutput.rename(outputFile.path);
      if (backupDirectory != null && await backupDirectory.exists()) {
        await backupDirectory.delete();
      }
      rethrow;
    }
    if (previousOutput == null) {
      rethrow;
    }
    throw WhisperQualityObservationMergeException(
      '覆盖输出时检测到并发写入；旧输出保留在 '
      '${backupDirectory!.path}：$error',
    );
  }
  if (backupDirectory != null && await backupDirectory.exists()) {
    await backupDirectory.delete(recursive: true);
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

Set<String> _manifestSampleIds(Map<String, Object?> manifest) {
  final samples = _objectList(manifest['samples'], 'manifest.samples');
  if (samples.isEmpty) {
    throw const WhisperQualityObservationMergeException(
      'manifest.samples 不能为空',
    );
  }
  final ids = <String>{};
  for (var index = 0; index < samples.length; index++) {
    final id = _requiredText(
      samples[index]['id'],
      'manifest.samples[$index].id',
    );
    if (!ids.add(id)) {
      throw WhisperQualityObservationMergeException(
        'manifest 存在重复 sample id：$id',
      );
    }
  }
  return ids;
}

void _validateCorpusAttestation({
  required Map<String, Object?> execution,
  required String corpusId,
  required bool corpusDeidentified,
  required String corpusEvidenceClass,
  required String manifestSha256,
  required int batchIndex,
}) {
  if (execution['corpusId'] != corpusId ||
      execution['corpusDeidentified'] != corpusDeidentified ||
      execution['corpusEvidenceClass'] != corpusEvidenceClass ||
      execution['corpusManifestSha256'] != manifestSha256) {
    throw WhisperQualityObservationMergeException(
      '批次 ${batchIndex + 1} 的 corpus 证明与 manifest 不一致',
    );
  }
}

void _validateExecutionCompatibility({
  required Map<String, Object?> reference,
  required Map<String, Object?> candidate,
  required int batchIndex,
}) {
  const fields = [
    'platform',
    'deviceId',
    'abi',
    'apiLevel',
    'threadCount',
    'windowDurationMs',
    'fixedWindowCaptureLatencyMs',
    'vadStabilityMarginMs',
    'energyStatus',
    'thermalStatus',
  ];
  for (final field in fields) {
    if (candidate[field] != reference[field]) {
      throw WhisperQualityObservationMergeException(
        '批次 ${batchIndex + 1} 的 execution.$field 与首批不一致',
      );
    }
  }
}

Future<void> _rewriteTranscriptReference({
  required Map<String, Object?> observation,
  required File inputFile,
  required File outputFile,
  required String privateRoot,
}) async {
  final value = observation['transcriptRef'];
  if (value == null) {
    throw const WhisperQualityObservationMergeException(
      '每条 ASR 质量观测都必须保留 transcriptRef',
    );
  }
  final reference = _requiredText(value, 'observation.transcriptRef');
  if (p.isAbsolute(reference)) {
    throw const WhisperQualityObservationMergeException(
      'transcriptRef 不得为绝对路径',
    );
  }
  final transcriptFile = File(
    p.normalize(p.join(inputFile.parent.path, reference)),
  );
  if (!transcriptFile.existsSync()) {
    throw WhisperQualityObservationMergeException(
      'transcriptRef 不存在或越过仓库边界：$reference',
    );
  }
  final canonicalBatchRoot = p.normalize(
    inputFile.parent.resolveSymbolicLinksSync(),
  );
  final canonicalTranscript = p.normalize(
    transcriptFile.resolveSymbolicLinksSync(),
  );
  if (!_isWithin(canonicalBatchRoot, canonicalTranscript) ||
      !_isWithin(privateRoot, transcriptFile.path)) {
    throw WhisperQualityObservationMergeException(
      'transcriptRef 不存在或越过私有批次边界：$reference',
    );
  }
  final expectedSha256 = _sha256Text(
    observation['transcriptSha256'],
    'observation.transcriptSha256',
  );
  final actualSha256 = await sha256.bind(transcriptFile.openRead()).first;
  if (actualSha256.toString() != expectedSha256) {
    throw WhisperQualityObservationMergeException(
      'transcriptRef SHA-256 不匹配：$reference',
    );
  }
  observation['transcriptRef'] = _privateReference(
    from: outputFile.parent.path,
    target: transcriptFile.path,
    privateRoot: privateRoot,
  );
}

String _privateReference({
  required String from,
  required String target,
  required String privateRoot,
}) {
  if (!_isWithin(privateRoot, from) || !_isWithin(privateRoot, target)) {
    throw const WhisperQualityObservationMergeException(
      '私有批次引用必须位于仓库 .spike 边界内',
    );
  }
  final relative = p.relative(target, from: from);
  return relative.replaceAll(r'\', '/');
}

Future<String> _validateOutput({
  required File outputFile,
  required String repositoryRoot,
  required List<File> protectedInputs,
  required bool overwrite,
}) async {
  if (p.extension(outputFile.path).toLowerCase() != '.json') {
    throw const WhisperQualityObservationMergeException('输出必须使用 .json 扩展名');
  }
  if (!overwrite && await outputFile.exists()) {
    throw WhisperQualityObservationMergeException(
      '输出已存在，拒绝覆盖：${outputFile.path}',
    );
  }
  final spikeRoot = p.join(repositoryRoot, '.spike');
  if (!_isWithin(spikeRoot, outputFile.path)) {
    throw const WhisperQualityObservationMergeException('合并输出必须位于仓库 .spike 目录');
  }
  if (protectedInputs.any((input) => p.equals(input.path, outputFile.path))) {
    throw const WhisperQualityObservationMergeException(
      '输出不得覆盖 manifest 或批次输入',
    );
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
    throw const WhisperQualityObservationMergeException(
      '合并输出经符号链接解析后必须仍位于 .spike 边界内',
    );
  }
  return spikeRoot;
}

Future<void> _validatePrivateInput(
  File input, {
  required String privateRoot,
  required String label,
}) async {
  if (!await input.exists() || !_isWithin(privateRoot, input.path)) {
    throw WhisperQualityObservationMergeException(
      '$label 必须是 .spike 内的现有私有 JSON',
    );
  }
  final canonicalPrivateRoot = p.normalize(
    await Directory(privateRoot).resolveSymbolicLinks(),
  );
  final canonicalInput = p.normalize(await input.resolveSymbolicLinks());
  if (!_isWithin(canonicalPrivateRoot, canonicalInput)) {
    throw WhisperQualityObservationMergeException(
      '$label 经符号链接解析后越过 .spike 边界',
    );
  }
}

Future<List<int>> _readBytes(File file, String name) async {
  if (!await file.exists()) {
    throw WhisperQualityObservationMergeException('$name 不存在：${file.path}');
  }
  return file.readAsBytes();
}

Map<String, Object?> _decodeObject(List<int> bytes, String name) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (error) {
    throw WhisperQualityObservationMergeException(
      '$name 不是有效 JSON：${error.message}',
    );
  }
  return _object(decoded, name);
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw WhisperQualityObservationMergeException('$name 必须是 JSON 对象');
  }
  return value;
}

List<Map<String, Object?>> _objectList(Object? value, String name) {
  if (value is! List<Object?>) {
    throw WhisperQualityObservationMergeException('$name 必须是对象数组');
  }
  return [
    for (var index = 0; index < value.length; index++)
      _object(value[index], '$name[$index]'),
  ];
}

List<String> _textList(Object? value, String name) {
  if (value is! List<Object?> ||
      value.any((item) => item is! String || item.trim().isEmpty)) {
    throw WhisperQualityObservationMergeException('$name 必须是字符串数组');
  }
  return value
      .cast<String>()
      .map((item) => item.trim())
      .toList(growable: false);
}

String _requiredText(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw WhisperQualityObservationMergeException('$name 不能为空');
  }
  return value.trim();
}

String _sha256Text(Object? value, String name) {
  final text = _requiredText(value, name).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw WhisperQualityObservationMergeException('$name 必须是 64 位十六进制');
  }
  return text;
}

bool _requiredBool(Object? value, String name) {
  if (value is! bool) {
    throw WhisperQualityObservationMergeException('$name 必须是布尔值');
  }
  return value;
}

bool _isWithin(String parent, String child) {
  final relative = p.relative(p.normalize(child), from: p.normalize(parent));
  return relative == '.' ||
      (relative != '..' && !relative.startsWith('..${p.separator}'));
}
