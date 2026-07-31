import 'dart:io';

import 'reviewed_corpus_promoter.dart';
import 'whisper_quality_protocol.dart';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options == null) {
    stderr.writeln(
      '用法：dart run tool/benchmarks/promote_reviewed_whisper_corpus.dart '
      '--candidate-manifest <候选.json> '
      '--review-attestation <人工复核.json> '
      '--environment <私有环境映射.json> '
      '--repository-root <仓库路径> '
      '--output <正式私有清单.json>',
    );
    exitCode = 64;
    return;
  }

  try {
    final result = await const ReviewedCorpusPromoter().promote(
      candidateManifestPath: options.candidateManifest,
      reviewAttestationPath: options.reviewAttestation,
      environmentPath: options.environment,
      repositoryRoot: options.repositoryRoot,
      outputPath: options.output,
    );
    stdout
      ..writeln('已晋升 ${result.sampleCount} 段人工复核语料：${result.corpusId}')
      ..writeln('正式私有清单：${result.outputPath}')
      ..writeln('复核证明 SHA-256：${result.reviewAttestationSha256}');
  } on ReviewedCorpusPromotionException catch (error) {
    stderr.writeln('无法晋升人工复核语料：${error.message}');
    exitCode = 65;
  } on WhisperQualityProtocolException catch (error) {
    stderr.writeln('候选或正式语料校验失败：${error.message}');
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln('无法读写人工复核语料：${error.message}');
    exitCode = 66;
  }
}

final class _Options {
  const _Options({
    required this.candidateManifest,
    required this.reviewAttestation,
    required this.environment,
    required this.repositoryRoot,
    required this.output,
  });

  final String candidateManifest;
  final String reviewAttestation;
  final String environment;
  final String repositoryRoot;
  final String output;

  static _Options? parse(List<String> arguments) {
    if (arguments.length.isOdd) {
      return null;
    }
    const allowed = {
      '--candidate-manifest',
      '--review-attestation',
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
      reviewAttestation: values['--review-attestation']!,
      environment: values['--environment']!,
      repositoryRoot: values['--repository-root']!,
      output: values['--output']!,
    );
  }
}
