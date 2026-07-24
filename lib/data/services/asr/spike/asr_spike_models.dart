import 'dart:io';

const paraformerSpikeModelId = 'sherpa-onnx-paraformer-zh-small-2024-03-09';
const qwenSpikeModelId = 'sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25';

enum AsrSpikeModelKind { paraformer, qwen3Asr }

final class AsrSpikeModelSpec {
  const AsrSpikeModelSpec._({
    required this.modelId,
    required this.kind,
    required this.rootPath,
    required this.requiredRelativePaths,
  });

  factory AsrSpikeModelSpec.paraformer({required String rootPath}) {
    return AsrSpikeModelSpec._(
      modelId: paraformerSpikeModelId,
      kind: AsrSpikeModelKind.paraformer,
      rootPath: rootPath,
      requiredRelativePaths: const ['model.int8.onnx', 'tokens.txt'],
    );
  }

  factory AsrSpikeModelSpec.qwen({required String rootPath}) {
    return AsrSpikeModelSpec._(
      modelId: qwenSpikeModelId,
      kind: AsrSpikeModelKind.qwen3Asr,
      rootPath: rootPath,
      requiredRelativePaths: const [
        'conv_frontend.onnx',
        'encoder.int8.onnx',
        'decoder.int8.onnx',
        'tokenizer/merges.txt',
        'tokenizer/tokenizer_config.json',
        'tokenizer/vocab.json',
      ],
    );
  }

  final String modelId;
  final AsrSpikeModelKind kind;
  final String rootPath;
  final List<String> requiredRelativePaths;

  String resolve(String relativePath) {
    final separator = rootPath.contains(r'\') && !rootPath.contains('/')
        ? r'\'
        : '/';
    final normalizedRoot = rootPath.endsWith(separator)
        ? rootPath.substring(0, rootPath.length - 1)
        : rootPath;
    final normalizedRelative = relativePath.replaceAll('/', separator);
    return '$normalizedRoot$separator$normalizedRelative';
  }

  Future<AsrSpikeFileValidation> validateFiles() async {
    final missing = <String>[];
    final sizes = <String, int>{};
    for (final relativePath in requiredRelativePaths) {
      final file = File(resolve(relativePath));
      if (!await file.exists()) {
        missing.add(relativePath);
        continue;
      }
      sizes[relativePath] = await file.length();
    }
    return AsrSpikeFileValidation(
      missingRelativePaths: List.unmodifiable(missing),
      byteSizes: Map.unmodifiable(sizes),
    );
  }
}

final class AsrSpikeFileValidation {
  const AsrSpikeFileValidation({
    required this.missingRelativePaths,
    required this.byteSizes,
  });

  final List<String> missingRelativePaths;
  final Map<String, int> byteSizes;

  bool get isValid => missingRelativePaths.isEmpty;

  Map<String, Object> toJson() => {
    'isValid': isValid,
    'missingRelativePaths': missingRelativePaths,
    'byteSizes': byteSizes,
  };
}

final class AsrSpikeMetrics {
  const AsrSpikeMetrics({
    required this.audioDuration,
    required this.initializationDuration,
    required this.firstResultDuration,
    required this.inferenceDuration,
  });

  final Duration audioDuration;
  final Duration initializationDuration;
  final Duration firstResultDuration;
  final Duration inferenceDuration;

  double get realTimeFactor {
    if (audioDuration.inMicroseconds == 0) {
      return double.infinity;
    }
    return inferenceDuration.inMicroseconds / audioDuration.inMicroseconds;
  }

  int get utteranceLatencyMs => firstResultDuration.inMilliseconds;

  Map<String, Object> toJson() => {
    'audioDurationMs': audioDuration.inMilliseconds,
    'initializationDurationMs': initializationDuration.inMilliseconds,
    'firstResultDurationMs': firstResultDuration.inMilliseconds,
    'inferenceDurationMs': inferenceDuration.inMilliseconds,
    'realTimeFactor': realTimeFactor,
    'utteranceLatencyMs': utteranceLatencyMs,
    'latencySemantics': '首个离线窗口从开始解码到结果可读。',
  };
}

final class AsrSpikeWindowMetrics {
  const AsrSpikeWindowMetrics({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.inferenceDuration,
    required this.resultCharacterCount,
  });

  final int index;
  final int startMs;
  final int endMs;
  final Duration inferenceDuration;
  final int resultCharacterCount;

  bool get resultWasReadable => resultCharacterCount > 0;

  Map<String, Object> toJson() => {
    'index': index,
    'startMs': startMs,
    'endMs': endMs,
    'inferenceDurationMs': inferenceDuration.inMilliseconds,
    'resultCharacterCount': resultCharacterCount,
    'resultWasReadable': resultWasReadable,
  };
}

final class AsrSpikeRunResult {
  const AsrSpikeRunResult({
    required this.modelId,
    required this.packageVersion,
    required this.nativeVersion,
    required this.nativeGitSha1,
    required this.nativeGitDate,
    required this.metrics,
    required this.resultText,
    required this.fileValidation,
    required this.repeatIndex,
    required this.peakProcessRssBytes,
    required this.windows,
  });

  final String modelId;
  final String packageVersion;
  final String nativeVersion;
  final String nativeGitSha1;
  final String nativeGitDate;
  final AsrSpikeMetrics metrics;
  final String resultText;
  final AsrSpikeFileValidation fileValidation;
  final int repeatIndex;
  final int peakProcessRssBytes;
  final List<AsrSpikeWindowMetrics> windows;

  int get totalWindowCount => windows.length;
  int get readableWindowCount =>
      windows.where((window) => window.resultWasReadable).length;
  int get emptyWindowCount => totalWindowCount - readableWindowCount;

  Map<String, Object> toJson() => {
    'modelId': modelId,
    'packageVersion': packageVersion,
    'nativeVersion': nativeVersion,
    'nativeGitSha1': nativeGitSha1,
    'nativeGitDate': nativeGitDate,
    'metrics': metrics.toJson(),
    'resultCharacterCount': resultText.runes.length,
    'resultWasReadable': resultText.trim().isNotEmpty,
    'fileValidation': fileValidation.toJson(),
    'repeatIndex': repeatIndex,
    'peakProcessRssBytes': peakProcessRssBytes,
    'totalWindowCount': totalWindowCount,
    'readableWindowCount': readableWindowCount,
    'emptyWindowCount': emptyWindowCount,
    'windows': windows.map((window) => window.toJson()).toList(),
  };
}
