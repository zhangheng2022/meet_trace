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
    '仓库外受控 PCM 在 Android 上生成 Base/Small/Profile 原始观测',
    (_) async {
      final run = await _DeviceBenchmarkRun.load(_deviceManifestPath);
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
        await _copyAsset(_baseModelAsset, baseModelPath);
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

        for (final model in run.models) {
          final modelPath = switch (model.source) {
            _ModelSource.bundledBase => baseModelPath,
            _ModelSource.deviceFile => model.path!,
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
          '$_completeMarker${jsonEncode({'schemaVersion': 1, 'corpusId': run.corpusId, 'deviceId': run.deviceId, 'sampleCount': run.samples.length, 'evaluationRunCount': run.evaluationRunCount, 'pipelineIds': run.pipelineIds, 'observationCount': observationCount, 'windowDurationMs': 2000, 'energyStatus': 'not_collected', 'thermalStatus': 'not_collected'})}',
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

enum _ModelSource { bundledBase, deviceFile }

final class _DeviceBenchmarkRun {
  const _DeviceBenchmarkRun({
    required this.corpusId,
    required this.deviceId,
    required this.threadCount,
    required this.samples,
    required this.models,
    required this.pipelineIds,
  });

  final String corpusId;
  final String deviceId;
  final int threadCount;
  final List<_DeviceSample> samples;
  final List<_DeviceModel> models;
  final List<String> pipelineIds;

  int get evaluationRunCount =>
      models.fold(0, (total, model) => total + model.profileIds.length) *
      pipelineIds.length;

  static Future<_DeviceBenchmarkRun> load(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw WhisperQualityProtocolException('设备评测清单不存在：$path');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?> ||
        decoded['schemaVersion'] != whisperQualityDeviceManifestSchemaVersion) {
      throw const WhisperQualityProtocolException('设备评测清单 schemaVersion 必须为 1');
    }
    final rawSamples = decoded['samples'];
    final rawModels = decoded['models'];
    final rawPipelineIds = decoded['pipelineIds'];
    if (rawSamples is! List<Object?> || rawSamples.isEmpty) {
      throw const WhisperQualityProtocolException('设备评测 samples 不能为空');
    }
    if (rawModels is! List<Object?> || rawModels.isEmpty) {
      throw const WhisperQualityProtocolException('设备评测 models 不能为空');
    }
    if (rawPipelineIds is! List<Object?> ||
        rawPipelineIds.isEmpty ||
        rawPipelineIds.any(
          (value) => !whisperQualityPipelineIds.contains(value),
        ) ||
        rawPipelineIds.toSet().length != rawPipelineIds.length) {
      throw const WhisperQualityProtocolException(
        '设备评测 pipelineIds 必须是不重复的已知 pipeline',
      );
    }
    final threadCount = decoded['threadCount'];
    if (threadCount is! int || threadCount <= 0 || threadCount > 32) {
      throw const WhisperQualityProtocolException(
        '设备评测 threadCount 必须在 1 到 32 之间',
      );
    }
    return _DeviceBenchmarkRun(
      corpusId: _text(decoded['corpusId'], 'corpusId'),
      deviceId: _text(decoded['deviceId'], 'deviceId'),
      threadCount: threadCount,
      samples: [
        for (var index = 0; index < rawSamples.length; index++)
          _DeviceSample.fromJson(_object(rawSamples[index], 'samples[$index]')),
      ],
      models: [
        for (var index = 0; index < rawModels.length; index++)
          _DeviceModel.fromJson(_object(rawModels[index], 'models[$index]')),
      ],
      pipelineIds: rawPipelineIds.cast<String>(),
    );
  }
}

final class _DeviceSample {
  const _DeviceSample({
    required this.id,
    required this.path,
    required this.sha256,
    required this.byteLength,
    required this.durationMs,
    required this.expectedKeyFacts,
  });

  factory _DeviceSample.fromJson(Map<String, Object?> json) {
    final byteLength = json['bytes'];
    final durationMs = json['durationMs'];
    final rawFacts = json['expectedKeyFacts'];
    if (byteLength is! int || byteLength <= 0 || byteLength.isOdd) {
      throw const WhisperQualityProtocolException('设备 sample bytes 必须是正偶数');
    }
    if (durationMs is! num || !durationMs.isFinite || durationMs <= 0) {
      throw const WhisperQualityProtocolException(
        '设备 sample durationMs 必须是正有限数值',
      );
    }
    if (rawFacts is! List<Object?> ||
        rawFacts.any((value) => value is! String)) {
      throw const WhisperQualityProtocolException(
        '设备 sample expectedKeyFacts 必须是字符串数组',
      );
    }
    return _DeviceSample(
      id: _text(json['id'], 'sample.id'),
      path: _text(json['path'], 'sample.path'),
      sha256: _text(json['sha256'], 'sample.sha256'),
      byteLength: byteLength,
      durationMs: durationMs.toDouble(),
      expectedKeyFacts: rawFacts.cast<String>(),
    );
  }

  final String id;
  final String path;
  final String sha256;
  final int byteLength;
  final double durationMs;
  final List<String> expectedKeyFacts;
}

final class _DeviceModel {
  const _DeviceModel({
    required this.modelId,
    required this.modelVersion,
    required this.source,
    required this.path,
    required this.profileIds,
  });

  factory _DeviceModel.fromJson(Map<String, Object?> json) {
    final sourceName = _text(json['source'], 'model.source');
    final source = switch (sourceName) {
      'bundledBase' => _ModelSource.bundledBase,
      'deviceFile' => _ModelSource.deviceFile,
      _ => throw WhisperQualityProtocolException('未知 model.source：$sourceName'),
    };
    final rawProfileIds = json['profileIds'];
    if (rawProfileIds is! List<Object?> ||
        rawProfileIds.isEmpty ||
        rawProfileIds.any(
          (value) => value is! String || value.trim().isEmpty,
        )) {
      throw const WhisperQualityProtocolException(
        'model.profileIds 必须是非空字符串数组',
      );
    }
    final path = json['path'];
    if (source == _ModelSource.deviceFile &&
        (path is! String || path.trim().isEmpty)) {
      throw const WhisperQualityProtocolException('deviceFile model 必须提供 path');
    }
    return _DeviceModel(
      modelId: _text(json['modelId'], 'model.modelId'),
      modelVersion: _text(json['modelVersion'], 'model.modelVersion'),
      source: source,
      path: path is String ? path.trim() : null,
      profileIds: rawProfileIds.cast<String>(),
    );
  }

  final String modelId;
  final String modelVersion;
  final _ModelSource source;
  final String? path;
  final List<String> profileIds;
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw WhisperQualityProtocolException('$name 必须是对象');
  }
  return value;
}

String _text(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw WhisperQualityProtocolException('$name 不能为空');
  }
  return value.trim();
}

Future<void> _copyAsset(String assetKey, String targetPath) async {
  final data = await rootBundle.load(assetKey);
  final target = File(targetPath);
  await target.parent.create(recursive: true);
  await target.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
}
