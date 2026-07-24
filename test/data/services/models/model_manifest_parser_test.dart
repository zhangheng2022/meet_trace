import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/models/model_manifest_parser.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';

void main() {
  late ModelManifestParser parser;

  setUp(() {
    parser = ModelManifestParser(
      registry: AsrModelRegistry.alpha,
      currentAppVersion: '1.0.0',
    );
  });

  test('解析与 Registry 一致的 v1 Manifest', () {
    final manifest = parser.parse(jsonEncode(_validManifest()));

    expect(manifest.schemaVersion, 1);
    expect(manifest.models.single.modelId, qwenAdvancedModelId);
    expect(manifest.models.single.files, hasLength(6));
    expect(
      manifest.models.single.files.fold<int>(
        0,
        (sum, file) => sum + file.bytes,
      ),
      manifest.models.single.requiredBytes,
    );
  });

  test('拒绝不兼容 schema', () {
    final json = _validManifest()..['schemaVersion'] = 2;

    expect(() => parser.parse(jsonEncode(json)), throwsFormatException);
  });

  test('拒绝高于当前 App 的最低版本', () {
    final json = _validManifest()..['minAppVersion'] = '1.1.0';

    expect(() => parser.parse(jsonEncode(json)), throwsFormatException);
  });

  test('拒绝重复模型 ID 与版本', () {
    final json = _validManifest();
    final models = json['models']! as List<Object?>;
    models.add(Map<String, Object?>.from(models.single! as Map));

    expect(() => parser.parse(jsonEncode(json)), throwsFormatException);
  });

  test('拒绝非法哈希、缺文件和空许可字段', () {
    final invalidHash = _validManifest();
    final invalidHashModel = _model(invalidHash);
    final invalidHashFiles = invalidHashModel['files']! as List<Object?>;
    (invalidHashFiles.first! as Map<String, Object?>)['sha256'] = 'pending';

    final missingFiles = _validManifest();
    _model(missingFiles).remove('files');

    final missingLicense = _validManifest();
    (_model(missingLicense)['license']! as Map<String, Object?>)['name'] = '';

    expect(() => parser.parse(jsonEncode(invalidHash)), throwsFormatException);
    expect(() => parser.parse(jsonEncode(missingFiles)), throwsFormatException);
    expect(
      () => parser.parse(jsonEncode(missingLicense)),
      throwsFormatException,
    );
  });

  test('拒绝路径穿越和非 HTTPS 下载地址', () {
    final traversal = _validManifest();
    final traversalModel = _model(traversal);
    final traversalFiles = traversalModel['files']! as List<Object?>;
    (traversalFiles.first! as Map<String, Object?>)['path'] = '../model.onnx';

    final insecure = _validManifest();
    final insecureModel = _model(insecure);
    final insecureFiles = insecureModel['files']! as List<Object?>;
    (insecureFiles.first! as Map<String, Object?>)['url'] =
        'http://example.com/model.onnx';

    expect(() => parser.parse(jsonEncode(traversal)), throwsFormatException);
    expect(() => parser.parse(jsonEncode(insecure)), throwsFormatException);
  });
}

Map<String, Object?> _model(Map<String, Object?> manifest) {
  final models = manifest['models']! as List<Object?>;
  return models.single! as Map<String, Object?>;
}

Map<String, Object?> _validManifest() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  return <String, Object?>{
    'schemaVersion': 1,
    'minAppVersion': '1.0.0',
    'models': <Object?>[
      <String, Object?>{
        'modelId': qwenAdvancedModelId,
        'version': '2026-03-25',
        'tier': 'advanced',
        'installationType': 'downloadable',
        'requiredBytes': 987015347,
        'files': <Object?>[
          _file('conv_frontend.onnx', 44148281, hash),
          _file('decoder.int8.onnx', 755914231, hash),
          _file('encoder.int8.onnx', 182491662, hash),
          _file('tokenizer/merges.txt', 1671853, hash),
          _file('tokenizer/tokenizer_config.json', 12487, hash),
          _file('tokenizer/vocab.json', 2776833, hash),
        ],
        'license': <String, Object?>{
          'name': 'Apache-2.0',
          'noticePath': 'licenses/qwen3-asr-NOTICE.txt',
        },
      },
    ],
  };
}

Map<String, Object?> _file(String path, int bytes, String hash) {
  return <String, Object?>{
    'path': path,
    'bytes': bytes,
    'sha256': hash,
    'url': 'https://example.com/$path',
  };
}
