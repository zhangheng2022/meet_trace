import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meetily_ai/data/services/asr/sherpa_onnx/sherpa_onnx_adapter.dart';
import 'package:meetily_ai/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _modelAsset =
    'assets/models/sherpa-onnx-paraformer-zh-small-2024-03-09/'
    'model.int8.onnx';
const _tokensAsset =
    'assets/models/sherpa-onnx-paraformer-zh-small-2024-03-09/tokens.txt';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '官方 bindings、识别器释放后可在独立 isolate 重复创建',
    (_) async {
      final runtimeStatus = sherpaOnnxRuntimeInitializer.initialize();
      expect(runtimeStatus.isReady, true, reason: runtimeStatus.failure?.code);

      final temporary = await getTemporaryDirectory();
      final root = Directory(
        p.join(
          temporary.path,
          'meetily-step08-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      final modelPath = p.join(root.path, 'model.int8.onnx');
      final tokensPath = p.join(root.path, 'tokens.txt');
      await root.create(recursive: true);

      try {
        await _copyAsset(_modelAsset, modelPath);
        await _copyAsset(_tokensAsset, tokensPath);
        final config = SherpaOnnxRecognizerConfig.paraformer(
          modelId: 'sherpa-onnx-paraformer-zh-small-2024-03-09',
          modelVersion: '2024-03-09-int8',
          modelPath: modelPath,
          tokensPath: tokensPath,
        );

        for (var attempt = 1; attempt <= 2; attempt++) {
          final adapter = SherpaOnnxAdapter();
          await adapter.initialize(config);
          final result = await adapter.recognize(
            Float32List(16000),
            sampleRate: 16000,
          );
          expect(result.sampleCount, 16000);
          expect(result.elapsed, greaterThan(Duration.zero));
          await adapter.dispose();
        }
      } finally {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _copyAsset(String assetKey, String targetPath) async {
  final data = await rootBundle.load(assetKey);
  final file = File(targetPath);
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
}
