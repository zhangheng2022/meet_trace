import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meettrace/data/services/asr/asr_engine.dart';
import 'package:meettrace/data/services/asr/whisper_base_standard_asr_engine.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace_whisper_native/meettrace_whisper_native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _modelAsset =
    'assets/models/whisper-cpp-base-q5_1-v1.9.1/ggml-base-q5_1.bin';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '真实内置 Whisper Base 完成窗口识别与事实音频最终处理',
    (_) async {
      final temporary = await getTemporaryDirectory();
      final root = Directory(
        p.join(
          temporary.path,
          'meettrace-whisper-base-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await root.create(recursive: true);
      final audioFile = File(p.join(root.path, 'one-second-silence.pcm'));

      try {
        expect(WhisperNativeContext.runtimeVersion, contains('1.9.1'));
        await _copyAsset(_modelAsset, p.join(root.path, 'ggml-base-q5_1.bin'));
        await audioFile.writeAsBytes(Uint8List(32000), flush: true);
        final descriptor = AsrModelRegistry.alpha.defaultModel;
        final engine = WhisperBaseStandardAsrEngine(
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
          try {
            await engine.initialize();
          } on AsrEngineException catch (error) {
            fail(
              'Whisper Base 初始化失败：${error.failure.code} '
              '${error.failure.diagnosticContext}',
            );
          }
          await engine.acceptAudio(
            Float32List(16000),
            sampleRate: whisperBaseSampleRate,
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
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _copyAsset(String assetKey, String targetPath) async {
  final data = await rootBundle.load(assetKey);
  await File(targetPath).writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
}
