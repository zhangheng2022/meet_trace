import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/models/model_file_verifier.dart';
import 'package:meettrace/data/services/models/model_manifest_parser.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  test('内置 Whisper Base 真实资产与发布 Manifest 完全一致', () async {
    final projectRoot = Directory.current.path;
    final assembled = await Directory.systemTemp.createTemp(
      'meettrace-bundled-model-',
    );
    final manifestSource = await File(
      p.join(projectRoot, 'assets', 'models', 'manifest.json'),
    ).readAsString();
    final manifest = ModelManifestParser(
      registry: AsrModelRegistry.alpha,
      currentAppVersion: '1.0.0',
    ).parse(manifestSource);
    final entry = manifest.models.singleWhere(
      (model) => model.modelId == whisperBaseStandardModelId,
    );

    try {
      for (final file in entry.files) {
        final sourceUri = Uri.parse(file.url);
        final source = File(
          p.joinAll([projectRoot, sourceUri.host, ...sourceUri.pathSegments]),
        );
        final destination = File(
          p.joinAll([assembled.path, ...file.path.split('/')]),
        );
        expect(await source.exists(), isTrue, reason: file.url);
        await destination.parent.create(recursive: true);
        await source.copy(destination.path);
      }
      final result = await const ModelFileVerifier().verifyDirectory(
        directoryPath: assembled.path,
        manifest: entry,
      );

      expect(entry.modelId, whisperBaseStandardModelId);
      expect(entry.requiredBytes, 60592723);
      expect(result.isValid, isTrue, reason: _issues(result));
      expect(result.verifiedBytes, entry.requiredBytes);
      expect(
        File(
          p.join(
            projectRoot,
            entry.license.noticePath.replaceAll('/', p.separator),
          ),
        ).existsSync(),
        isTrue,
      );
    } finally {
      await assembled.delete(recursive: true);
    }
  });
}

String _issues(ModelFileVerificationResult result) {
  return result.issues
      .map((issue) => '${issue.path}: ${issue.message}')
      .join(', ');
}
