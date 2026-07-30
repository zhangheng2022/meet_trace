import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meettrace/data/services/asr/rust_bridge/generated/api/probe.dart';
import 'package:meettrace/data/services/asr/rust_bridge/generated/frb_generated.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _modelAsset =
    'assets/models/whisper-cpp-base-q5_1-v1.9.1/ggml-base-q5_1.bin';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(RustLib.init);
  tearDownAll(RustLib.dispose);

  testWidgets(
    'whisper-rs loads Base and runs a two-second mobile inference',
    (_) async {
      final temporary = await getTemporaryDirectory();
      final root = Directory(
        p.join(
          temporary.path,
          'meettrace-rust-whisper-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      final modelPath = p.join(root.path, 'ggml-base-q5_1.bin');
      await root.create(recursive: true);

      try {
        final data = await rootBundle.load(_modelAsset);
        await File(modelPath).writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );

        final result = await probeWhisperModel(
          modelPath: modelPath,
          pcmF32: Float32List(32000),
          language: 'en',
        );

        expect(result.sampleCount, 32000);
        expect(result.modelType, isNotEmpty);
      } finally {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
