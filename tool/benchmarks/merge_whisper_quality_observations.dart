import 'dart:io';

import 'whisper_quality_observation_merger.dart';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options == null) {
    stderr.writeln(
      '用法：dart run tool/benchmarks/merge_whisper_quality_observations.dart '
      '--manifest <corpus.json> --repository-root <仓库> '
      '--output <合并 raw.json> [--overwrite] '
      '--input <批次1 raw.json> [--input <批次2 raw.json> ...]',
    );
    exitCode = 64;
    return;
  }

  try {
    final result = await const WhisperQualityObservationMerger().merge(
      corpusManifestPath: options.manifest,
      inputPaths: options.inputs,
      repositoryRoot: options.repositoryRoot,
      outputPath: options.output,
      overwrite: options.overwrite,
    );
    stdout.writeln(
      '已合并 ${result.batchCount} 个批次、'
      '${result.combinationCount} 个组合、'
      '${result.observationCount} 条观测：${result.outputPath}',
    );
  } on WhisperQualityObservationMergeException catch (error) {
    stderr.writeln('无法合并 Whisper 质量观测：${error.message}');
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln('无法读写 Whisper 质量观测：${error.message}');
    exitCode = 66;
  }
}

final class _Options {
  const _Options({
    required this.manifest,
    required this.repositoryRoot,
    required this.output,
    required this.inputs,
    required this.overwrite,
  });

  final String manifest;
  final String repositoryRoot;
  final String output;
  final List<String> inputs;
  final bool overwrite;

  static _Options? parse(List<String> arguments) {
    String? manifest;
    String? repositoryRoot;
    String? output;
    var overwrite = false;
    final inputs = <String>[];
    for (var index = 0; index < arguments.length; index++) {
      final name = arguments[index];
      if (name == '--overwrite') {
        if (overwrite) {
          return null;
        }
        overwrite = true;
        continue;
      }
      if (name != '--manifest' &&
          name != '--repository-root' &&
          name != '--output' &&
          name != '--input') {
        return null;
      }
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('--')) {
        return null;
      }
      final value = arguments[++index];
      switch (name) {
        case '--manifest':
          if (manifest != null) return null;
          manifest = value;
        case '--repository-root':
          if (repositoryRoot != null) return null;
          repositoryRoot = value;
        case '--output':
          if (output != null) return null;
          output = value;
        case '--input':
          inputs.add(value);
      }
    }
    if (manifest == null ||
        repositoryRoot == null ||
        output == null ||
        inputs.isEmpty) {
      return null;
    }
    return _Options(
      manifest: manifest,
      repositoryRoot: repositoryRoot,
      output: output,
      inputs: List.unmodifiable(inputs),
      overwrite: overwrite,
    );
  }
}
