import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meetily_ai/data/services/asr/asr_engine.dart';
import 'package:meetily_ai/data/services/asr/paraformer_standard_asr_engine.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/audio_source.dart';
import 'package:meetily_ai/domain/models/model_installation.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _modelAsset =
    'assets/models/sherpa-onnx-paraformer-zh-small-2024-03-09/'
    'model.int8.onnx';
const _tokensAsset =
    'assets/models/sherpa-onnx-paraformer-zh-small-2024-03-09/tokens.txt';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真实内置 Paraformer 完成窗口识别与事实音频最终处理', (_) async {
    final temporary = await getTemporaryDirectory();
    final root = Directory(
      p.join(
        temporary.path,
        'meetily-step09-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await root.create(recursive: true);
    final audioFile = File(p.join(root.path, 'one-second-silence.pcm'));

    try {
      await _copyAsset(_modelAsset, p.join(root.path, 'model.int8.onnx'));
      await _copyAsset(_tokensAsset, p.join(root.path, 'tokens.txt'));
      await audioFile.writeAsBytes(Uint8List(32000), flush: true);
      final descriptor = AsrModelRegistry.alpha.defaultModel;
      final engine = ParaformerStandardAsrEngine(
        installation: ModelInstallation(
          modelId: descriptor.modelId,
          version: descriptor.version,
          installationType: descriptor.installationType,
          state: ModelInstallationState.installed,
          installedPath: root.path,
          verifiedAt: DateTime.now(),
          bytes: descriptor.requiredBytes,
        ),
      );
      final progress = <AsrFinalizationProgress>[];
      final subscription = engine.finalizationProgress.listen(progress.add);

      try {
        await engine.initialize();
        await engine.acceptAudio(
          Float32List(16000),
          sampleRate: paraformerSampleRate,
          startMs: 5000,
        );
        final snapshot = await engine.finalizeMeeting(
          AudioSource(path: audioFile.path, durationMs: 1000),
          meetingId: 'device-meeting',
        );

        expect(snapshot.status, TranscriptSnapshotStatus.complete);
        expect(snapshot.actualModelId, descriptor.modelId);
        expect(snapshot.actualModelVersion, descriptor.version);
        expect(engine.metrics.totalWindowCount, 2);
        expect(engine.metrics.failedWindowCount, 0);
        expect(
          engine.metrics.totalInferenceDuration,
          greaterThan(Duration.zero),
        );
        expect(progress.last.phase, AsrFinalizationPhase.completed);
        expect(progress.last.fraction, 1);
      } finally {
        await subscription.cancel();
        await engine.dispose();
      }
    } finally {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> _copyAsset(String assetKey, String targetPath) async {
  final data = await rootBundle.load(assetKey);
  await File(targetPath).writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
}
