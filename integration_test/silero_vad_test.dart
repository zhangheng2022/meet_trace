import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';
import 'package:meettrace/data/services/models/flutter_model_asset_source.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/vad/bundled_silero_vad_model.dart';
import 'package:meettrace/data/services/vad/silero_vad_segmenter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android 使用内置 INT8 权重重复初始化、连续输入、flush 和释放',
    (_) async {
      final runtimeStatus = sherpaOnnxRuntimeInitializer.initialize();
      expect(runtimeStatus.isReady, true, reason: runtimeStatus.failure?.code);

      final temporary = await getTemporaryDirectory();
      final root = Directory(
        p.join(
          temporary.path,
          'meettrace-step12-vad-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      final service = BundledSileroVadModelService(
        fileLayout: AppFileLayout(rootPath: root.path),
        assetSource: FlutterModelAssetSource(rootBundle),
      );

      try {
        final prepared = await service.prepare();
        expect(await File(prepared.modelPath).length(), 212860);

        for (var attempt = 0; attempt < 2; attempt++) {
          final vad = SileroVadSegmenter.official(
            modelPath: prepared.modelPath,
          );
          try {
            vad.reset(nextStartSample: attempt * 16000);
            for (var window = 0; window < 40; window++) {
              expect(vad.accept(Float32List(sileroVadWindowSize)), isEmpty);
            }
            expect(vad.flush(), isEmpty);
          } finally {
            vad.dispose();
          }
        }

        final reused = await service.prepare();
        expect(reused.alreadyReady, isTrue);
        expect(reused.modelPath, prepared.modelPath);
      } finally {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
