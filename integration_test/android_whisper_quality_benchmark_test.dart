import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meettrace/data/services/asr/whisper/whisper_adapter.dart';
import 'package:meettrace/data/services/asr/whisper/whisper_recognizer_profiles.dart';
import 'package:meettrace/data/services/vad/whisper_vad_segmenter.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../tool/benchmarks/whisper_quality_protocol.dart';

const _deviceManifestPath = String.fromEnvironment(
  'MEETTRACE_WHISPER_QUALITY_DEVICE_MANIFEST',
);
const _baseModelAsset =
    'assets/models/whisper-cpp-base-q5_1-v1.9.1/ggml-base-q5_1.bin';
const _vadModelAsset =
    'assets/models/whisper-vad-silero-v6.2.0/ggml-silero-v6.2.0.bin';
const _observationMarker = 'MEETTRACE_WHISPER_QUALITY_OBSERVATION:';
const _completeMarker = 'MEETTRACE_WHISPER_QUALITY_COMPLETE:';
const _fixedWindowCaptureLatency = Duration(seconds: 2);
const _vadStabilityMargin = Duration(seconds: 1);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '仓库外受控 PCM 在 Android 上生成 ASR 矩阵或 VAD 预检观测',
    (_) async {
      final run = await WhisperQualityDeviceRun.load(_deviceManifestPath);
      final temporary = await getTemporaryDirectory();
      final benchmarkRoot = Directory(
        p.join(
          temporary.path,
          'meettrace-quality-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await benchmarkRoot.create(recursive: true);
      var observationCount = 0;
      try {
        final baseModelPath = p.join(benchmarkRoot.path, 'ggml-base-q5_1.bin');
        final vadModelPath = p.join(
          benchmarkRoot.path,
          'ggml-silero-v6.2.0.bin',
        );
        if (!run.isVadPreflight) {
          await _copyAsset(_baseModelAsset, baseModelPath);
        }
        final vadPipelineIds = run.pipelineIds
            .where((pipelineId) => pipelineId != whisperFixedWindowPipelineId)
            .toList(growable: false);
        if (vadPipelineIds.isNotEmpty) {
          await _copyAsset(_vadModelAsset, vadModelPath);
        }

        final vadMeasurements = <String, Map<String, _VadMeasurement>>{};
        if (vadPipelineIds.isNotEmpty) {
          for (final sample in run.samples) {
            final bytes = await File(sample.path).readAsBytes();
            expect(bytes.length, sample.byteLength);
            expect(sha256.convert(bytes).toString(), sample.sha256);
            vadMeasurements[sample.id] = {
              for (final pipelineId in vadPipelineIds)
                pipelineId: await _segmentMeasured(
                  bytes,
                  config: _vadConfigForPipeline(
                    pipelineId,
                    modelPath: vadModelPath,
                    threadCount: run.threadCount,
                  ),
                ),
            };
          }
        }

        if (run.isVadPreflight) {
          for (final sample in run.samples) {
            for (final pipelineId in run.pipelineIds) {
              final vad = vadMeasurements[sample.id]![pipelineId]!;
              final speechSampleCount = vad.segments.fold<int>(
                0,
                (total, segment) =>
                    total + (segment.endSample - segment.startSample),
              );
              final observation = <String, Object?>{
                'sampleId': sample.id,
                'pipelineId': pipelineId,
                'deviceId': run.deviceId,
                'inferenceDurationMs': vad.elapsedMicros / 1000,
                'detectedSpeechSegmentCount': vad.segments.length,
                'detectedSpeechDurationMs':
                    speechSampleCount * 1000 / whisperQualitySampleRateHz,
                'firstSpeechStartMs': vad.segments.isEmpty
                    ? null
                    : vad.segments.first.startSample *
                          1000 /
                          whisperQualitySampleRateHz,
                'lastSpeechEndMs': vad.segments.isEmpty
                    ? null
                    : vad.segments.last.endSample *
                          1000 /
                          whisperQualitySampleRateHz,
                'speechSegments': [
                  for (final segment in vad.segments)
                    {
                      'startMs':
                          segment.startSample *
                          1000 /
                          whisperQualitySampleRateHz,
                      'endMs':
                          segment.endSample * 1000 / whisperQualitySampleRateHz,
                    },
                ],
                'peakRssBytes': vad.peakRssBytes,
              };
              debugPrintSynchronously(
                '$_observationMarker${jsonEncode({'observation': observation})}',
                wrapWidth: null,
              );
              observationCount++;
            }
          }
        }

        for (final model in run.models) {
          final modelPath = switch (model.source) {
            WhisperQualityModelSource.bundledBase => baseModelPath,
            WhisperQualityModelSource.deviceFile => model.path!,
          };
          expect(await File(modelPath).exists(), isTrue);

          for (final profileId in model.profileIds) {
            final profile = _profileById(profileId);
            final adapter = WhisperAdapter();
            await adapter.initialize(
              profile.createConfig(
                modelId: model.modelId,
                modelVersion: model.modelVersion,
                modelPath: modelPath,
                threadCount: run.threadCount,
                language: 'auto',
              ),
            );
            try {
              for (final sample in run.samples) {
                final bytes = await File(sample.path).readAsBytes();
                for (final pipelineId in run.pipelineIds) {
                  final result = switch (pipelineId) {
                    whisperFixedWindowPipelineId => await _recognizeFixedWindow(
                      adapter,
                      bytes,
                      durationMs: sample.durationMs,
                    ),
                    whisperVadSegmentedPipelineId =>
                      await _recognizeVadSegments(
                        adapter,
                        bytes,
                        vadMeasurements[sample.id]![pipelineId]!,
                        durationMs: sample.durationMs,
                      ),
                    whisperVadRecallCandidatePipelineId =>
                      await _recognizeVadSegments(
                        adapter,
                        bytes,
                        vadMeasurements[sample.id]![pipelineId]!,
                        durationMs: sample.durationMs,
                      ),
                    _ => throw WhisperQualityProtocolException(
                      '未知 pipelineId：$pipelineId',
                    ),
                  };
                  final recognizedFacts = recognizeExpectedKeyFacts(
                    transcript: result.transcript,
                    expectedKeyFacts: sample.expectedKeyFacts,
                  );
                  final observation = <String, Object?>{
                    'sampleId': sample.id,
                    'modelId': model.modelId,
                    'modelVersion': model.modelVersion,
                    'profileId': profile.id,
                    'pipelineId': pipelineId,
                    'deviceId': run.deviceId,
                    'inferenceDurationMs':
                        result.inferenceDurationMicros / 1000,
                    'sentenceLatencyMs': result.sentenceLatencyMicros == null
                        ? null
                        : result.sentenceLatencyMicros! / 1000,
                    'asrInvocationCount': result.asrInvocationCount,
                    'detectedSpeechSegmentCount':
                        result.detectedSpeechSegmentCount,
                    'detectedSpeechDurationMs': result.detectedSpeechDurationMs,
                    'emittedText': result.transcript.isNotEmpty,
                    'recognizedKeyFacts': recognizedFacts,
                    'peakRssBytes': result.peakRssBytes,
                    'energyWh': null,
                    'energyEvidenceRef': null,
                    'sustainedSevereOrCriticalThermal': null,
                    'thermalEvidenceRef': null,
                  };
                  debugPrintSynchronously(
                    '$_observationMarker${jsonEncode({
                      'observation': observation,
                      'transcript': {'schemaVersion': 1, 'sampleId': sample.id, 'modelId': model.modelId, 'modelVersion': model.modelVersion, 'profileId': profile.id, 'pipelineId': pipelineId, 'text': result.transcript, 'segments': result.segments},
                    })}',
                    wrapWidth: null,
                  );
                  observationCount++;
                }
              }
            } finally {
              await adapter.dispose();
            }
          }
        }

        final expectedCount = run.samples.length * run.evaluationRunCount;
        expect(observationCount, expectedCount);
        debugPrintSynchronously(
          '$_completeMarker${jsonEncode({'schemaVersion': 1, 'mode': run.mode, 'corpusId': run.corpusId, 'deviceId': run.deviceId, 'sampleCount': run.samples.length, 'evaluationRunCount': run.evaluationRunCount, 'pipelineIds': run.pipelineIds, 'observationCount': observationCount, 'windowDurationMs': 2000, 'energyStatus': 'not_collected', 'thermalStatus': 'not_collected'})}',
          wrapWidth: null,
        );
      } finally {
        if (await benchmarkRoot.exists()) {
          await benchmarkRoot.delete(recursive: true);
        }
      }
    },
    skip: _deviceManifestPath.isEmpty,
    timeout: const Timeout(Duration(hours: 6)),
  );
}

final class _VadMeasurement {
  const _VadMeasurement({
    required this.segments,
    required this.elapsedMicros,
    required this.peakRssBytes,
  });

  final List<VadSpeechSegment> segments;
  final int elapsedMicros;
  final int peakRssBytes;
}

final class _BenchmarkRecognition {
  const _BenchmarkRecognition({
    required this.transcript,
    required this.segments,
    required this.inferenceDurationMicros,
    required this.sentenceLatencyMicros,
    required this.asrInvocationCount,
    required this.detectedSpeechSegmentCount,
    required this.detectedSpeechDurationMs,
    required this.peakRssBytes,
  });

  final String transcript;
  final List<Map<String, Object?>> segments;
  final int inferenceDurationMicros;
  final int? sentenceLatencyMicros;
  final int asrInvocationCount;
  final int? detectedSpeechSegmentCount;
  final double? detectedSpeechDurationMs;
  final int peakRssBytes;
}

Future<_VadMeasurement> _segmentMeasured(
  Uint8List bytes, {
  required WhisperVadConfig config,
}) async {
  var peakRssBytes = ProcessInfo.currentRss;
  final timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
    peakRssBytes = math.max(peakRssBytes, ProcessInfo.currentRss);
  });
  final watch = Stopwatch()..start();
  final segmenter = WhisperVadSegmenter(
    modelPath: config.modelPath,
    config: config,
    stabilityMargin: _vadStabilityMargin,
  );
  try {
    final segments = <VadSpeechSegment>[];
    for (final window in decodePcm16LeWindows(bytes)) {
      segments.addAll(await segmenter.accept(window));
    }
    segments.addAll(await segmenter.flush());
    watch.stop();
    peakRssBytes = math.max(peakRssBytes, ProcessInfo.currentRss);
    return _VadMeasurement(
      segments: List.unmodifiable(segments),
      elapsedMicros: watch.elapsedMicroseconds,
      peakRssBytes: peakRssBytes,
    );
  } finally {
    watch.stop();
    timer.cancel();
    await segmenter.dispose();
  }
}

WhisperVadConfig _vadConfigForPipeline(
  String pipelineId, {
  required String modelPath,
  required int threadCount,
}) {
  return switch (pipelineId) {
    whisperVadSegmentedPipelineId => WhisperVadConfig(
      modelPath: modelPath,
      threadCount: threadCount,
    ),
    whisperVadRecallCandidatePipelineId => WhisperVadConfig(
      modelPath: modelPath,
      threadCount: threadCount,
      threshold: 0.35,
      minSpeechDurationMs: 100,
      speechPadMs: 100,
    ),
    _ => throw WhisperQualityProtocolException('未知 VAD pipelineId：$pipelineId'),
  };
}

Future<_BenchmarkRecognition> _recognizeFixedWindow(
  WhisperAdapter adapter,
  Uint8List bytes, {
  required double durationMs,
}) async {
  final transcriptParts = <String>[];
  final segments = <Map<String, Object?>>[];
  var inferenceDurationMicros = 0;
  var maximumWindowLatencyMicros = 0;
  var peakRssBytes = ProcessInfo.currentRss;
  var windowIndex = 0;
  for (final window in decodePcm16LeWindows(bytes)) {
    final measured = await _recognizeMeasured(adapter, window);
    final recognition = measured.recognition;
    inferenceDurationMicros += recognition.elapsed.inMicroseconds;
    maximumWindowLatencyMicros = math.max(
      maximumWindowLatencyMicros,
      measured.wallElapsed.inMicroseconds,
    );
    peakRssBytes = math.max(peakRssBytes, measured.peakRssBytes);
    final windowOffsetMs =
        windowIndex *
        whisperQualityWindowSamples *
        1000 ~/
        whisperQualitySampleRateHz;
    _appendRecognition(
      recognition,
      transcriptParts: transcriptParts,
      segments: segments,
      offsetMs: windowOffsetMs,
      durationMs: durationMs,
    );
    windowIndex++;
  }
  return _BenchmarkRecognition(
    transcript: transcriptParts.join(' ').trim(),
    segments: List.unmodifiable(segments),
    inferenceDurationMicros: inferenceDurationMicros,
    // 保守覆盖一句话在 2 秒窗口起点结束时等待窗口到齐的时间。
    sentenceLatencyMicros:
        _fixedWindowCaptureLatency.inMicroseconds + maximumWindowLatencyMicros,
    asrInvocationCount: windowIndex,
    detectedSpeechSegmentCount: null,
    detectedSpeechDurationMs: null,
    peakRssBytes: peakRssBytes,
  );
}

Future<_BenchmarkRecognition> _recognizeVadSegments(
  WhisperAdapter adapter,
  Uint8List bytes,
  _VadMeasurement vad, {
  required double durationMs,
}) async {
  final allSamples = decodePcm16Le(bytes);
  final transcriptParts = <String>[];
  final segments = <Map<String, Object?>>[];
  var inferenceDurationMicros = vad.elapsedMicros;
  var maximumSegmentLatencyMicros = 0;
  var peakRssBytes = vad.peakRssBytes;
  var asrInvocationCount = 0;
  var detectedSpeechSampleCount = 0;
  for (final speech in vad.segments) {
    final start = speech.startSample.clamp(0, allSamples.length);
    final end = speech.endSample.clamp(start, allSamples.length);
    if (end <= start) {
      continue;
    }
    asrInvocationCount++;
    detectedSpeechSampleCount += end - start;
    final measured = await _recognizeMeasured(
      adapter,
      Float32List.sublistView(allSamples, start, end),
    );
    final recognition = measured.recognition;
    inferenceDurationMicros += recognition.elapsed.inMicroseconds;
    maximumSegmentLatencyMicros = math.max(
      maximumSegmentLatencyMicros,
      measured.wallElapsed.inMicroseconds,
    );
    peakRssBytes = math.max(peakRssBytes, measured.peakRssBytes);
    final offsetMs = start * 1000 ~/ whisperQualitySampleRateHz;
    _appendRecognition(
      recognition,
      transcriptParts: transcriptParts,
      segments: segments,
      offsetMs: offsetMs,
      durationMs: durationMs,
    );
  }
  return _BenchmarkRecognition(
    transcript: transcriptParts.join(' ').trim(),
    segments: List.unmodifiable(segments),
    inferenceDurationMicros: inferenceDurationMicros,
    sentenceLatencyMicros: asrInvocationCount == 0
        ? null
        : _vadStabilityMargin.inMicroseconds +
              vad.elapsedMicros +
              maximumSegmentLatencyMicros,
    asrInvocationCount: asrInvocationCount,
    detectedSpeechSegmentCount: asrInvocationCount,
    detectedSpeechDurationMs:
        detectedSpeechSampleCount * 1000 / whisperQualitySampleRateHz,
    peakRssBytes: peakRssBytes,
  );
}

void _appendRecognition(
  WhisperRecognition recognition, {
  required List<String> transcriptParts,
  required List<Map<String, Object?>> segments,
  required int offsetMs,
  required double durationMs,
}) {
  final text = recognition.text.trim();
  if (text.isNotEmpty) {
    transcriptParts.add(text);
  }
  for (final segment in recognition.segments) {
    final startMs = math.min(durationMs.floor(), offsetMs + segment.startMs);
    final endMs = math.min(durationMs.ceil(), offsetMs + segment.endMs);
    if (endMs > startMs) {
      segments.add({'text': segment.text, 'startMs': startMs, 'endMs': endMs});
    }
  }
}

Future<
  ({WhisperRecognition recognition, Duration wallElapsed, int peakRssBytes})
>
_recognizeMeasured(WhisperAdapter adapter, Float32List samples) async {
  var peakRssBytes = ProcessInfo.currentRss;
  final timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
    peakRssBytes = math.max(peakRssBytes, ProcessInfo.currentRss);
  });
  final watch = Stopwatch()..start();
  try {
    final recognition = await adapter.recognize(
      samples,
      sampleRate: whisperQualitySampleRateHz,
    );
    watch.stop();
    peakRssBytes = math.max(peakRssBytes, ProcessInfo.currentRss);
    return (
      recognition: recognition,
      wallElapsed: watch.elapsed,
      peakRssBytes: peakRssBytes,
    );
  } finally {
    watch.stop();
    timer.cancel();
  }
}

WhisperRecognizerProfile _profileById(String id) => switch (id) {
  'baseline-fixed-greedy-v1' => whisperBaselineRecognizerProfile,
  'preview-greedy-low-latency-v1' => whisperPreviewRecognizerProfile,
  'final-beam-quality-v1' => whisperFinalRecognizerProfile,
  _ => throw WhisperQualityProtocolException('未知 Whisper Profile：$id'),
};

Future<void> _copyAsset(String assetKey, String targetPath) async {
  final data = await rootBundle.load(assetKey);
  final target = File(targetPath);
  await target.parent.create(recursive: true);
  await target.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
}
