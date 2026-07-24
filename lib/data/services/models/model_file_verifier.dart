import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../domain/models/model_manifest.dart';

enum ModelFileIssueKind { missing, sizeMismatch, hashMismatch, unexpected }

final class ModelFileIssue {
  const ModelFileIssue({
    required this.path,
    required this.kind,
    required this.message,
  });

  final String path;
  final ModelFileIssueKind kind;
  final String message;
}

final class ModelFileVerificationResult {
  ModelFileVerificationResult({
    required this.verifiedBytes,
    required List<ModelFileIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final int verifiedBytes;
  final List<ModelFileIssue> issues;

  bool get isValid => issues.isEmpty;
}

final class ModelFileVerifier {
  const ModelFileVerifier();

  Future<ModelFileVerificationResult> verifyDirectory({
    required String directoryPath,
    required ModelManifestEntry manifest,
    bool strictFileSet = true,
  }) async {
    final root = p.normalize(p.absolute(directoryPath));
    final issues = <ModelFileIssue>[];
    var verifiedBytes = 0;

    for (final expected in manifest.files) {
      final file = File(p.joinAll([root, ...expected.path.split('/')]));
      if (!await file.exists()) {
        issues.add(
          ModelFileIssue(
            path: expected.path,
            kind: ModelFileIssueKind.missing,
            message: '缺少模型文件',
          ),
        );
        continue;
      }
      final size = await file.length();
      if (size != expected.bytes) {
        issues.add(
          ModelFileIssue(
            path: expected.path,
            kind: ModelFileIssueKind.sizeMismatch,
            message: '文件大小应为 ${expected.bytes}，实际为 $size',
          ),
        );
        continue;
      }
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString() != expected.sha256) {
        issues.add(
          ModelFileIssue(
            path: expected.path,
            kind: ModelFileIssueKind.hashMismatch,
            message: 'SHA-256 不匹配',
          ),
        );
        continue;
      }
      verifiedBytes += size;
    }

    if (strictFileSet) {
      final expectedPaths = manifest.files.map((file) => file.path).toSet();
      final directory = Directory(root);
      if (await directory.exists()) {
        final actualFiles = await directory
            .list(recursive: true, followLinks: false)
            .where((entity) => entity is File)
            .cast<File>()
            .toList();
        for (final file in actualFiles) {
          final relativePath = p
              .relative(file.path, from: root)
              .replaceAll(r'\', '/');
          if (!expectedPaths.contains(relativePath)) {
            issues.add(
              ModelFileIssue(
                path: relativePath,
                kind: ModelFileIssueKind.unexpected,
                message: '文件不在 Manifest 中',
              ),
            );
          }
        }
      }
    }

    issues.sort((left, right) => left.path.compareTo(right.path));
    return ModelFileVerificationResult(
      verifiedBytes: verifiedBytes,
      issues: issues,
    );
  }
}
