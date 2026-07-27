import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/models/model_manifest_parser.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  test('Qwen3-ASR 发布 Manifest 使用固定版本 HTTPS 文件和真实哈希', () async {
    final source = await File(
      p.join(Directory.current.path, 'assets', 'models', 'manifest.json'),
    ).readAsString();
    final manifest = ModelManifestParser(
      registry: AsrModelRegistry.alpha,
      currentAppVersion: '1.0.0',
    ).parse(source);
    final entry = manifest.models.singleWhere(
      (model) => model.modelId == qwenAdvancedModelId,
    );

    expect(entry.files, hasLength(6));
    expect(
      entry.files.fold<int>(0, (sum, file) => sum + file.bytes),
      987015347,
    );
    expect(
      entry.files.every(
        (file) =>
            Uri.parse(file.url).scheme == 'https' &&
            file.url.contains('68818b2313fe77bd06f6a7c5068ff3ef59d02b8a'),
      ),
      isTrue,
    );
    expect(
      File(
        p.join(
          Directory.current.path,
          entry.license.noticePath.replaceAll('/', p.separator),
        ),
      ).existsSync(),
      isTrue,
    );
  });
}
