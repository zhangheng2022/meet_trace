import 'dart:io';

import 'reviewed_corpus_promoter.dart';
import 'whisper_quality_protocol.dart';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options == null) {
    stderr.writeln(
      '用法：dart run '
      'tool/benchmarks/create_whisper_review_attestation_template.dart '
      '--candidate-manifest <候选.json> '
      '--environment <私有环境映射.json> '
      '--repository-root <仓库路径> '
      '--output <待填写人工复核.json>',
    );
    exitCode = 64;
    return;
  }

  try {
    final result = await const ReviewedCorpusPromoter().writeReviewTemplate(
      candidateManifestPath: options.candidateManifest,
      environmentPath: options.environment,
      repositoryRoot: options.repositoryRoot,
      outputPath: options.output,
    );
    stdout
      ..writeln('已生成 ${result.sampleCount} 段待人工复核模板：${result.outputPath}')
      ..writeln('候选 manifest SHA-256：${result.candidateManifestSha256}')
      ..writeln('模板默认全部未批准，不会自动晋升为正式质量证据。');
  } on ReviewedCorpusPromotionException catch (error) {
    stderr.writeln('无法生成人工复核模板：${error.message}');
    exitCode = 65;
  } on WhisperQualityProtocolException catch (error) {
    stderr.writeln('候选语料校验失败：${error.message}');
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln('无法读写人工复核模板：${error.message}');
    exitCode = 66;
  }
}

final class _Options {
  const _Options({
    required this.candidateManifest,
    required this.environment,
    required this.repositoryRoot,
    required this.output,
  });

  final String candidateManifest;
  final String environment;
  final String repositoryRoot;
  final String output;

  static _Options? parse(List<String> arguments) {
    if (arguments.length.isOdd) {
      return null;
    }
    const allowed = {
      '--candidate-manifest',
      '--environment',
      '--repository-root',
      '--output',
    };
    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index += 2) {
      final name = arguments[index];
      if (!allowed.contains(name) ||
          values.containsKey(name) ||
          index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('--')) {
        return null;
      }
      values[name] = arguments[index + 1];
    }
    if (!allowed.every(values.containsKey)) {
      return null;
    }
    return _Options(
      candidateManifest: values['--candidate-manifest']!,
      environment: values['--environment']!,
      repositoryRoot: values['--repository-root']!,
      output: values['--output']!,
    );
  }
}
