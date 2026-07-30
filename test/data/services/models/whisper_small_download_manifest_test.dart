import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/models/model_manifest_parser.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  test('Whisper Small 发布 Manifest 使用固定版本 HTTPS 文件和真实哈希', () async {
    final source = await File(
      p.join(Directory.current.path, 'assets', 'models', 'manifest.json'),
    ).readAsString();
    final manifest = ModelManifestParser(
      registry: AsrModelRegistry.alpha,
      currentAppVersion: '1.0.0',
    ).parse(source);
    final entry = manifest.models.singleWhere(
      (model) => model.modelId == whisperSmallAdvancedModelId,
    );

    expect(entry.files, hasLength(1));
    expect(
      entry.files.fold<int>(0, (sum, file) => sum + file.bytes),
      190085487,
    );
    expect(
      entry.files.every(
        (file) =>
            Uri.parse(file.url).scheme == 'https' &&
            file.url.contains('5359861c739e955e79d9a303bcbc70fb988958b1'),
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
