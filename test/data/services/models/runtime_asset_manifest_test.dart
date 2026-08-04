import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/models/runtime/silero_vad_manifest.dart';
import 'package:meettrace/data/models/runtime/speaker_diarization_manifest.dart';
import 'package:meettrace/data/services/models/downloadable_model_service.dart';
import 'package:meettrace/data/services/models/model_manifest_parser.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  final projectRoot = Directory.current.path;

  test('发布 Manifest 固定 SenseVoice 文件、内容哈希和下载源', () {
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
      'c71f0ce00bec95b07744e116345e33d8cbbe08cef896382cf907bf4b51a2cd51',
    );
    expect(
      model.files.last.sha256,
      'f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc',
    );
    expect(model.files.map((file) => file.url), [
      'https://mt.zhangheng.eu.org/models/SenseVoice/model.int8.onnx',
      'https://mt.zhangheng.eu.org/models/SenseVoice/tokens.txt',
    ]);
  });

  test('SenseVoice、VAD 与说话人资源下载总量不超过十进制 300 MB', () {
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
    final speaker = const SpeakerDiarizationManifestParser().parse(
      File(
        p.join(
          projectRoot,
          'assets',
          'models',
          'speaker-diarization-manifest.json',
        ),
      ).readAsStringSync(),
    );

    expect(
      vad.files.single.url,
      'https://mt.zhangheng.eu.org/models/SenseVoice/silero_vad.int8.onnx',
    );

    expect(speaker.requiredBytes, 46552205);
    expect(
      speaker.segmentationArchive.download.sha256,
      speakerSegmentationArchiveSha256,
    );
    expect(speaker.embeddingModel.download.sha256, speakerEmbeddingModelSha256);
    expect(
      speaker.downloadManifest.files.map((file) => file.url),
      everyElement(startsWith('https://mt.zhangheng.eu.org/models/')),
    );
    expect(
      [
        ...model.files,
        ...vad.files,
        ...speaker.downloadManifest.files,
      ].map((file) => Uri.parse(file.url).host).toSet(),
      {'mt.zhangheng.eu.org'},
    );
    expect(
      model.requiredBytes + vad.requiredBytes + speaker.requiredBytes,
      286314800,
    );
    expect(
      model.requiredBytes + vad.requiredBytes + speaker.requiredBytes,
      lessThanOrEqualTo(maximumRuntimeDownloadBytes),
    );
  });

  test('Flutter 安装包资产只声明 Manifest 与许可，不声明任何模型权重', () {
    final pubspec = File(
      p.join(projectRoot, 'pubspec.yaml'),
    ).readAsStringSync();

    expect(pubspec, isNot(contains('.onnx')));
    expect(pubspec, isNot(contains('assets/models/sherpa-onnx-')));
    expect(pubspec, isNot(contains('assets/models/silero-vad-int8-')));
    expect(pubspec, contains(speakerDiarizationManifestAssetPath));
    expect(pubspec, contains('assets/licenses/3d-speaker-LICENSE.txt'));
    expect(
      pubspec,
      contains('assets/licenses/pyannote-segmentation-LICENSE.txt'),
    );
  });

  test('说话人模型许可与 NOTICE 文件均已入库', () {
    for (final path in [
      'assets/licenses/pyannote-segmentation-NOTICE.txt',
      'assets/licenses/pyannote-segmentation-LICENSE.txt',
      'assets/licenses/3d-speaker-NOTICE.txt',
      'assets/licenses/3d-speaker-LICENSE.txt',
    ]) {
      final file = File(p.joinAll([projectRoot, ...path.split('/')]));
      expect(file.existsSync(), isTrue, reason: path);
      expect(file.lengthSync(), greaterThan(100), reason: path);
    }
  });
}
