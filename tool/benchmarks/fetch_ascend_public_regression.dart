import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const ascendDatasetId = 'CAiRE/ASCEND';
const ascendDatasetRevision = '737e9800ae31be9932ba8464c80366559bd28424';
const ascendDatasetConfig = 'main';
const ascendDatasetLicense = 'CC-BY-SA-4.0';
const _sampleRateHz = 16000;
const _maximumAudioBytes = 16 * 1024 * 1024;

final class AscendRegressionException implements Exception {
  const AscendRegressionException(this.message);

  final String message;

  @override
  String toString() => 'AscendRegressionException: $message';
}

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final repositoryRoot = p.normalize(p.absolute(options.repositoryRoot));
  final outputRoot = p.normalize(
    p.isAbsolute(options.outputDirectory)
        ? options.outputDirectory
        : p.join(repositoryRoot, options.outputDirectory),
  );
  final allowedRoot = p.join(repositoryRoot, '.spike');
  if (!_isWithin(allowedRoot, outputRoot) || outputRoot == allowedRoot) {
    throw const AscendRegressionException('输出目录必须位于仓库 .spike 的子目录中');
  }

  final outputDirectory = Directory(outputRoot);
  final audioDirectory = Directory(p.join(outputRoot, 'audio'));
  await outputDirectory.create(recursive: true);
  await audioDirectory.create(recursive: true);

  final rows = await _fetchRows(options);
  final selectedRows = selectAscendRows(
    rows,
    sampleCount: options.sampleCount,
    minimumDurationSeconds: options.minimumDurationSeconds,
    maximumDurationSeconds: options.maximumDurationSeconds,
  );
  final environment = <String, String>{};
  final samples = <Map<String, Object?>>[];
  for (final selected in selectedRows.indexed) {
    final index = selected.$1;
    final row = selected.$2;
    final wav = await _downloadBytes(
      row.audioUri,
      label: 'ASCEND row ${row.rowIndex} audio',
    );
    final pcm = extractPcm16Mono16Khz(wav);
    final durationMs = pcm.length * 1000 / (_sampleRateHz * 2);
    if ((durationMs / 1000 - row.durationSeconds).abs() > 0.05) {
      throw AscendRegressionException(
        'ASCEND row ${row.rowIndex} 的 WAV 时长与元数据不一致',
      );
    }

    final fileName =
        'sample-${index.toString().padLeft(2, '0')}-'
        '${row.rowIndex.toString().padLeft(5, '0')}.pcm';
    final audioPath = p.join(audioDirectory.path, fileName);
    await File(audioPath).writeAsBytes(pcm, flush: true);
    final environmentName =
        'MEETTRACE_ASCEND_${options.split.toUpperCase()}_'
        '${index.toString().padLeft(2, '0')}';
    environment[environmentName] = audioPath;
    samples.add({
      'id': 'ascend-${options.split}-${row.rowIndex}',
      'pathEnv': environmentName,
      'sha256': sha256.convert(pcm).toString(),
      'durationMs': durationMs,
      'tags': ['speech', 'public-regression', 'conversation', row.language],
      'expectedKeyFacts': [
        if (normalizeReferenceText(row.transcription).length >= 2)
          row.transcription,
      ],
    });
  }

  final corpusId =
      'ascend-${ascendDatasetRevision.substring(0, 8)}-'
      '${options.split}-${options.offset}-${options.sampleCount}';
  final manifest = {
    'schemaVersion': 2,
    'id': corpusId,
    'deidentified': false,
    'evidenceClass': 'public-regression',
    'provenance': {
      'sourceId':
          'huggingface:$ascendDatasetId@$ascendDatasetRevision:'
          '${options.split}:${options.offset}:${options.rowPoolSize}',
      'licenseId': ascendDatasetLicense,
    },
    'audioFormat': const {
      'encoding': 'pcm16le',
      'sampleRateHz': _sampleRateHz,
      'channels': 1,
    },
    'samples': samples,
  };
  await _writeJson(File(p.join(outputRoot, 'manifest.private.json')), manifest);
  await _writeJson(
    File(p.join(outputRoot, 'environment.private.json')),
    environment,
  );
  stdout.writeln(
    'ASCEND public regression corpus prepared: '
    '${selectedRows.length} samples ($corpusId)',
  );
}

Future<List<Object?>> _fetchRows(_Options options) async {
  final uri = Uri.https('datasets-server.huggingface.co', '/rows', {
    'dataset': ascendDatasetId,
    'config': ascendDatasetConfig,
    'split': options.split,
    'offset': '${options.offset}',
    'length': '${options.rowPoolSize}',
    'revision': ascendDatasetRevision,
  });
  final bytes = await _downloadBytes(uri, label: 'ASCEND row metadata');
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (error) {
    throw AscendRegressionException(
      'ASCEND row metadata 不是有效 JSON：${error.message}',
    );
  }
  if (decoded is! Map<String, Object?> || decoded['rows'] is! List<Object?>) {
    throw const AscendRegressionException('ASCEND row metadata 缺少 rows 数组');
  }
  return decoded['rows']! as List<Object?>;
}

List<AscendRow> selectAscendRows(
  List<Object?> rawRows, {
  required int sampleCount,
  required double minimumDurationSeconds,
  required double maximumDurationSeconds,
}) {
  final result = <AscendRow>[];
  for (var index = 0; index < rawRows.length; index++) {
    final wrapper = _map(rawRows[index], 'rows[$index]');
    final row = _map(wrapper['row'], 'rows[$index].row');
    final rawAudio = row['audio'];
    if (rawAudio is! List<Object?> || rawAudio.length != 1) {
      throw AscendRegressionException('rows[$index].row.audio 必须是单元素数组');
    }
    final audio = _map(rawAudio.single, 'rows[$index].row.audio[0]');
    final duration = _positiveNumber(
      row['duration'],
      'rows[$index].row.duration',
    );
    if (duration < minimumDurationSeconds ||
        duration > maximumDurationSeconds) {
      continue;
    }
    final audioType = _requiredText(
      audio['type'],
      'rows[$index].row.audio.type',
    );
    if (audioType != 'audio/wav') {
      throw AscendRegressionException(
        'rows[$index].row.audio.type 必须为 audio/wav',
      );
    }
    final audioUri = Uri.tryParse(
      _requiredText(audio['src'], 'rows[$index].row.audio.src'),
    );
    if (audioUri == null ||
        audioUri.scheme != 'https' ||
        audioUri.host != 'datasets-server.huggingface.co' ||
        audioUri.hasPort) {
      throw AscendRegressionException(
        'rows[$index].row.audio.src 必须是 Hugging Face HTTPS 地址',
      );
    }
    result.add(
      AscendRow(
        rowIndex: _nonNegativeInteger(
          wrapper['row_idx'],
          'rows[$index].row_idx',
        ),
        id: _requiredText(row['id'], 'rows[$index].row.id'),
        durationSeconds: duration,
        language: _language(row['language'], 'rows[$index].row.language'),
        transcription: _requiredText(
          row['transcription'],
          'rows[$index].row.transcription',
        ),
        audioUri: audioUri,
      ),
    );
    if (result.length == sampleCount) {
      break;
    }
  }
  if (result.length != sampleCount) {
    throw AscendRegressionException(
      '在 ${rawRows.length} 条候选中只找到 ${result.length} 条满足 '
      '$minimumDurationSeconds～$maximumDurationSeconds 秒的样本，'
      '需要 $sampleCount 条',
    );
  }
  return List.unmodifiable(result);
}

final class AscendRow {
  const AscendRow({
    required this.rowIndex,
    required this.id,
    required this.durationSeconds,
    required this.language,
    required this.transcription,
    required this.audioUri,
  });

  final int rowIndex;
  final String id;
  final double durationSeconds;
  final String language;
  final String transcription;
  final Uri audioUri;
}

Uint8List extractPcm16Mono16Khz(Uint8List wav) {
  if (wav.length < 12 ||
      _fourCc(wav, 0) != 'RIFF' ||
      _fourCc(wav, 8) != 'WAVE') {
    throw const AscendRegressionException('音频不是 RIFF/WAVE');
  }
  final data = ByteData.sublistView(wav);
  int? formatCode;
  int? channels;
  int? sampleRate;
  int? bitsPerSample;
  Uint8List? pcm;
  var offset = 12;
  while (offset + 8 <= wav.length) {
    final chunkId = _fourCc(wav, offset);
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkStart = offset + 8;
    final chunkEnd = chunkStart + chunkSize;
    if (chunkEnd > wav.length) {
      throw const AscendRegressionException('WAV chunk 越界');
    }
    if (chunkId == 'fmt ') {
      if (chunkSize < 16) {
        throw const AscendRegressionException('WAV fmt chunk 过短');
      }
      formatCode = data.getUint16(chunkStart, Endian.little);
      channels = data.getUint16(chunkStart + 2, Endian.little);
      sampleRate = data.getUint32(chunkStart + 4, Endian.little);
      bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
    } else if (chunkId == 'data') {
      pcm = Uint8List.fromList(wav.sublist(chunkStart, chunkEnd));
    }
    offset = chunkEnd + (chunkSize.isOdd ? 1 : 0);
  }
  if (formatCode != 1 ||
      channels != 1 ||
      sampleRate != _sampleRateHz ||
      bitsPerSample != 16 ||
      pcm == null ||
      pcm.isEmpty ||
      pcm.length.isOdd) {
    throw const AscendRegressionException('WAV 必须为 16 kHz、单声道、PCM16LE');
  }
  return pcm;
}

String normalizeReferenceText(String value) => value.toLowerCase().replaceAll(
  RegExp(r'''[\s，。！？、,.!?;；:：'"“”‘’（）()\[\]【】<>《》\-—_]+'''),
  '',
);

Future<Uint8List> _downloadBytes(Uri uri, {required String label}) async {
  if (uri.scheme != 'https' ||
      uri.host != 'datasets-server.huggingface.co' ||
      uri.hasPort) {
    throw AscendRegressionException('$label 使用了未批准的下载地址');
  }
  Object? lastError;
  for (var attempt = 1; attempt <= 3; attempt++) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'MeetTrace-benchmark/1');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw AscendRegressionException(
          '$label 下载失败：HTTP ${response.statusCode}',
        );
      }
      final builder = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in response) {
        total += chunk.length;
        if (total > _maximumAudioBytes) {
          throw AscendRegressionException('$label 超过 16 MiB 安全上限');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    } catch (error) {
      lastError = error;
      if (attempt < 3) {
        await Future<void>.delayed(Duration(milliseconds: attempt * 500));
      }
    } finally {
      client.close(force: true);
    }
  }
  throw AscendRegressionException('$label 下载失败：$lastError');
}

Future<void> _writeJson(File file, Object value) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(value),
    flush: true,
  );
}

String _fourCc(Uint8List bytes, int offset) =>
    ascii.decode(bytes.sublist(offset, offset + 4));

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw AscendRegressionException('$name 必须是对象');
  }
  return value;
}

String _requiredText(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw AscendRegressionException('$name 不能为空');
  }
  return value.trim();
}

double _positiveNumber(Object? value, String name) {
  if (value is! num || !value.isFinite || value <= 0) {
    throw AscendRegressionException('$name 必须是正有限数值');
  }
  return value.toDouble();
}

int _nonNegativeInteger(Object? value, String name) {
  if (value is! int || value < 0) {
    throw AscendRegressionException('$name 必须是非负整数');
  }
  return value;
}

String _language(Object? value, String name) {
  final language = _requiredText(value, name).toLowerCase();
  if (!const {'zh', 'en', 'mixed'}.contains(language)) {
    throw AscendRegressionException('$name 必须为 zh、en 或 mixed');
  }
  return language;
}

bool _isWithin(String parent, String child) {
  final relative = p.relative(p.normalize(child), from: p.normalize(parent));
  return relative != '..' && !relative.startsWith('..${p.separator}');
}

final class _Options {
  const _Options({
    required this.repositoryRoot,
    required this.outputDirectory,
    required this.split,
    required this.offset,
    required this.rowPoolSize,
    required this.sampleCount,
    required this.minimumDurationSeconds,
    required this.maximumDurationSeconds,
  });

  factory _Options.parse(List<String> arguments) {
    String? valueOf(String name) {
      final index = arguments.indexOf(name);
      if (index < 0 || index + 1 >= arguments.length) {
        return null;
      }
      return arguments[index + 1];
    }

    final repositoryRoot =
        valueOf('--repository-root') ?? Directory.current.path;
    final outputDirectory =
        valueOf('--output-directory') ??
        '.spike/corpora/ascend-public-regression-v1';
    final split = valueOf('--split') ?? 'validation';
    final offset = int.tryParse(valueOf('--offset') ?? '0');
    final rowPoolSize = int.tryParse(valueOf('--row-pool-size') ?? '100');
    final sampleCount = int.tryParse(valueOf('--sample-count') ?? '20');
    final minimumDurationSeconds = double.tryParse(
      valueOf('--minimum-duration-seconds') ?? '1',
    );
    final maximumDurationSeconds = double.tryParse(
      valueOf('--maximum-duration-seconds') ?? '3',
    );
    if (!const {'train', 'validation', 'test'}.contains(split) ||
        offset == null ||
        offset < 0 ||
        rowPoolSize == null ||
        rowPoolSize < 20 ||
        rowPoolSize > 100 ||
        sampleCount == null ||
        sampleCount < 20 ||
        sampleCount > rowPoolSize ||
        minimumDurationSeconds == null ||
        minimumDurationSeconds <= 0 ||
        maximumDurationSeconds == null ||
        maximumDurationSeconds < minimumDurationSeconds) {
      throw const AscendRegressionException(
        '参数无效：split=train|validation|test，offset>=0，'
        '20<=sample-count<=row-pool-size<=100，且时长范围必须为正',
      );
    }
    return _Options(
      repositoryRoot: repositoryRoot,
      outputDirectory: outputDirectory,
      split: split,
      offset: offset,
      rowPoolSize: rowPoolSize,
      sampleCount: sampleCount,
      minimumDurationSeconds: minimumDurationSeconds,
      maximumDurationSeconds: maximumDurationSeconds,
    );
  }

  final String repositoryRoot;
  final String outputDirectory;
  final String split;
  final int offset;
  final int rowPoolSize;
  final int sampleCount;
  final double minimumDurationSeconds;
  final double maximumDurationSeconds;
}
