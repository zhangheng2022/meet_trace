import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/models/downloadable_model_service.dart';
import 'package:meettrace/data/services/models/model_manifest_parser.dart';
import 'package:meettrace/data/services/vad/downloadable_silero_vad_model.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  final projectRoot = Directory.current.path;

  test('发布 Manifest 固定 SenseVoice 文件、哈希和不可变 revision', () {
    final manifest =
        ModelManifestParser(
          registry: AsrModelRegistry.alpha,
          currentAppVersion: '1.0.0',
        ).parse(
          File(
            p.join(projectRoot, 'assets', 'models', 'manifest.json'),
          ).readAsStringSync(),
        );
    final model = manifest.models.single;

    expect(model.modelId, senseVoiceDefaultModelId);
    expect(model.version, '2024-07-17');
    expect(model.requiredBytes, 239549735);
    expect(model.files.map((file) => file.path), [
      'model.int8.onnx',
      'tokens.txt',
    ]);
    expect(
      model.files.first.sha256,
      'c45ba1d6a13329c4aca1dc118cabdc643ca09cb8192abb979648dd68f9917323',
    );
    expect(
      model.files.last.sha256,
      'f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc',
    );
    expect(
      model.files.every(
        (file) => file.url.contains('2365baeacb507f821a0c8120fcee3d484dba7a07'),
      ),
      isTrue,
    );
  });

  test('SenseVoice 与 VAD 下载总量不超过十进制 300 MB', () {
    final model =
        ModelManifestParser(
              registry: AsrModelRegistry.alpha,
              currentAppVersion: '1.0.0',
            )
            .parse(
              File(
                p.join(projectRoot, 'assets', 'models', 'manifest.json'),
              ).readAsStringSync(),
            )
            .models
            .single;
    final vad = const SileroVadManifestParser().parse(
      File(
        p.join(projectRoot, 'assets', 'models', 'silero-vad-manifest.json'),
      ).readAsStringSync(),
    );

    expect(model.requiredBytes + vad.requiredBytes, 239762595);
    expect(
      model.requiredBytes + vad.requiredBytes,
      lessThanOrEqualTo(maximumRuntimeDownloadBytes),
    );
  });

  test('Flutter 安装包资产不声明任何 ASR 或 VAD 权重', () {
    final pubspec = File(
      p.join(projectRoot, 'pubspec.yaml'),
    ).readAsStringSync();

    expect(pubspec, isNot(contains('.onnx')));
    expect(pubspec, isNot(contains('assets/models/sherpa-onnx-')));
    expect(pubspec, isNot(contains('assets/models/silero-vad-int8-')));
  });
}
