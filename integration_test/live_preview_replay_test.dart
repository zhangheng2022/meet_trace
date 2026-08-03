import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meettrace/data/services/asr/asr_preview_coordinator.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';
import 'package:meettrace/data/services/asr/sense_voice_asr_engine.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';
import 'package:meettrace/data/services/vad/silero_vad_segmenter.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/recording.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';

const _pcmPath = String.fromEnvironment('MEETTRACE_REPLAY_PCM_PATH');
const _modelDirectory = String.fromEnvironment(
  'MEETTRACE_REPLAY_MODEL_DIRECTORY',
);
const _vadModelPath = String.fromEnvironment('MEETTRACE_REPLAY_VAD_PATH');
const _chunkDuration = Duration(milliseconds: 100);
const _senseVoiceModelSha256 =
    'c71f0ce00bec95b07744e116345e33d8cbbe08cef896382cf907bf4b51a2cd51';
const _tokensSha256 =
    'f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc';
const _vadModelSha256 =
    'c36d490aff5ab924ca6c7aeec4d8f6bd3d22db6fa17611b9c5b17eae58ac3a20';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final runtimeStatus = sherpaOnnxRuntimeInitializer.initialize();

  testWidgets('按真实时间回放 PCM 并测量真机实时转录', (_) async {
    expect(runtimeStatus.isReady, isTrue, reason: runtimeStatus.failure?.code);
    expect(_pcmPath, isNotEmpty, reason: '必须通过 dart-define 提供真机内 PCM 路径');
    expect(_modelDirectory, isNotEmpty, reason: '必须通过 dart-define 提供模型目录');
    expect(_vadModelPath, isNotEmpty, reason: '必须通过 dart-define 提供 VAD 模型路径');
    final inputFile = File(_pcmPath);
    expect(await inputFile.exists(), isTrue, reason: '真机内找不到回放 PCM');
    final byteLength = await inputFile.length();
    expect(byteLength, greaterThan(0));
    expect(byteLength.isEven, isTrue);

    final descriptor = AsrModelRegistry.alpha.defaultModel;
    final senseVoiceModel = File('$_modelDirectory/model.int8.onnx');
    final tokens = File('$_modelDirectory/tokens.txt');
    final vadModel = File(_vadModelPath);
    expect(await senseVoiceModel.length(), 239233841);
    expect(await tokens.length(), 315894);
    expect(await vadModel.length(), 212860);
    expect(await _sha256(senseVoiceModel), _senseVoiceModelSha256);
    expect(await _sha256(tokens), _tokensSha256);
    expect(await _sha256(vadModel), _vadModelSha256);

    AsrEngine? engine;
    AsrPreviewCoordinator? preview;
    RandomAccessFile? input;
    StreamSubscription<TranscriptEvent>? eventSubscription;
    StreamSubscription<AsrPreviewMetrics>? metricsSubscription;
    final replayWatch = Stopwatch();
    final eventLatenciesMs = <int>[];
    var segmentEvents = 0;
    var finalSegmentEvents = 0;
    var recognizedCharacters = 0;
    var maximumQueuedAudioMs = 0;
    var maximumPreviewLagMs = 0;
    var sawBacklog = false;

    try {
      engine = SenseVoiceAsrEngine(
        installation: ModelInstallation(
          modelId: descriptor.modelId,
          version: descriptor.version,
          installationType: descriptor.installationType,
          state: ModelInstallationState.installed,
          installedPath: _modelDirectory,
          verifiedAt: DateTime.now(),
          bytes: descriptor.requiredBytes,
        ),
      );
      await engine.initialize();
      preview = AsrPreviewCoordinator(
        vad: SileroVadSegmenter.official(modelPath: _vadModelPath),
        engine: engine,
      );

      eventSubscription = preview.events.listen((event) {
        if (event case final TranscriptSegmentEvent segment) {
          segmentEvents++;
          if (segment.isFinalForWindow) {
            finalSegmentEvents++;
          }
          recognizedCharacters += segment.text.runes.length;
          eventLatenciesMs.add(
            (replayWatch.elapsedMilliseconds - segment.endMs).clamp(
              0,
              replayWatch.elapsedMilliseconds,
            ),
          );
        }
      });
      metricsSubscription = preview.metricsChanges.listen((metrics) {
        maximumQueuedAudioMs = _max(
          maximumQueuedAudioMs,
          metrics.queuedAudioMs,
        );
        maximumPreviewLagMs = _max(maximumPreviewLagMs, metrics.previewLagMs);
        sawBacklog |= metrics.state == AsrPreviewState.backlogged;
      });

      input = await inputFile.open();
      final bytesPerChunk =
          recordingBytesPerSecond *
          _chunkDuration.inMilliseconds ~/
          Duration.millisecondsPerSecond;
      var startByteOffset = 0;
      replayWatch.start();
      while (startByteOffset < byteLength) {
        final remaining = byteLength - startByteOffset;
        final requested = remaining < bytesPerChunk ? remaining : bytesPerChunk;
        final bytes = await input.read(requested);
        expect(bytes.length, requested);
        final capturedThrough = Duration(
          microseconds:
              (startByteOffset + bytes.length) *
              Duration.microsecondsPerSecond ~/
              recordingBytesPerSecond,
        );
        final wait = capturedThrough - replayWatch.elapsed;
        if (wait > Duration.zero) {
          await Future<void>.delayed(wait);
        }
        await preview.add(
          RecordingPcmChunk(
            bytes: Uint8List.fromList(bytes),
            startByteOffset: startByteOffset,
          ),
        );
        startByteOffset += bytes.length;
      }
      await preview.flush();
      replayWatch.stop();

      final previewMetrics = preview.metrics;
      final engineMetrics = engine.metrics;
      final windowRtfs = <double>[
        for (final diagnostic in engine.diagnostics)
          if (diagnostic.endMs > diagnostic.startMs)
            diagnostic.elapsed.inMicroseconds /
                ((diagnostic.endMs - diagnostic.startMs) * 1000),
      ];
      final report = <String, Object?>{
        'schemaVersion': 1,
        'audioSeconds': byteLength / recordingBytesPerSecond,
        'replayElapsedMs': replayWatch.elapsedMilliseconds,
        'segmentEvents': segmentEvents,
        'finalSegmentEvents': finalSegmentEvents,
        'recognizedCharacters': recognizedCharacters,
        'processedPreviewWindows': previewMetrics.processedPreviewWindows,
        'droppedPreviewWindows': previewMetrics.droppedPreviewWindows,
        'maximumQueuedAudioMs': maximumQueuedAudioMs,
        'maximumPreviewLagMs': maximumPreviewLagMs,
        'sawBacklog': sawBacklog,
        'latencyP95Ms': _percentile(eventLatenciesMs, 0.95),
        'rtfP95': _percentile(windowRtfs, 0.95),
        'aggregateRtf': engineMetrics.realTimeFactor,
        'recognizedWindows': engineMetrics.recognizedWindowCount,
        'emptyWindows': engineMetrics.emptyWindowCount,
        'failedWindows': engineMetrics.failedWindowCount,
        'lastErrorCode':
            previewMetrics.lastErrorCode ?? engineMetrics.lastErrorCode,
        'deviceSupport': engine.deviceRisk.support.name,
        'memoryPressure': engine.deviceRisk.memoryPressure.name,
        'thermalState': engine.deviceRisk.thermalState.name,
      };
      debugPrintSynchronously(
        'MEETTRACE_LIVE_PREVIEW_REPLAY:${jsonEncode(report)}',
        wrapWidth: null,
      );

      expect(segmentEvents, greaterThan(0));
      expect(previewMetrics.processedPreviewWindows, greaterThan(0));
      expect(previewMetrics.state, isNot(AsrPreviewState.recordingOnly));
      expect(engineMetrics.failedWindowCount, 0);
      expect(report['lastErrorCode'], isNull);
    } finally {
      replayWatch.stop();
      await input?.close();
      await eventSubscription?.cancel();
      await metricsSubscription?.cancel();
      if (preview != null) {
        await preview.dispose();
      } else {
        await engine?.dispose();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

num _percentile<T extends num>(List<T> values, double percentile) {
  if (values.isEmpty) {
    return 0;
  }
  final sorted = values.map((value) => value.toDouble()).toList()..sort();
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index];
}

int _max(int left, int right) => left > right ? left : right;

Future<String> _sha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();
