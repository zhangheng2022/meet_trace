import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/models/model_file_verifier.dart';
import 'package:meettrace/data/services/models/model_manifest_parser.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  test('内置 Whisper Base 真实资产与发布 Manifest 完全一致', () async {
    final projectRoot = Directory.current.path;
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

    final result = await const ModelFileVerifier().verifyDirectory(
      directoryPath: p.join(
        projectRoot,
        'assets',
        'models',
        whisperBaseStandardModelId,
      ),
      manifest: entry,
    );

    expect(entry.modelId, whisperBaseStandardModelId);
    expect(entry.requiredBytes, 59707625);
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
  });
}

String _issues(ModelFileVerificationResult result) {
  return result.issues
      .map((issue) => '${issue.path}: ${issue.message}')
      .join(', ');
}
