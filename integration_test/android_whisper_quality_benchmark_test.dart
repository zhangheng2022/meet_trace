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
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../tool/benchmarks/whisper_quality_protocol.dart';

const _deviceManifestPath = String.fromEnvironment(
  'MEETTRACE_WHISPER_QUALITY_DEVICE_MANIFEST',
);
const _baseModelAsset =
    'assets/models/whisper-cpp-base-q5_1-v1.9.1/ggml-base-q5_1.bin';
const _observationMarker = 'MEETTRACE_WHISPER_QUALITY_OBSERVATION:';
const _completeMarker = 'MEETTRACE_WHISPER_QUALITY_COMPLETE:';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '仓库外去敏 PCM 在 Android 上生成 Base/Small/Profile 原始观测',
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
        await _copyAsset(_baseModelAsset, baseModelPath);

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
                expect(bytes.length, sample.byteLength);
                expect(sha256.convert(bytes).toString(), sample.sha256);

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
                  final text = recognition.text.trim();
                  if (text.isNotEmpty) {
                    transcriptParts.add(text);
                  }
                  for (final segment in recognition.segments) {
                    final startMs = math.min(
                      sample.durationMs.floor(),
                      windowOffsetMs + segment.startMs,
                    );
                    final endMs = math.min(
                      sample.durationMs.ceil(),
                      windowOffsetMs + segment.endMs,
                    );
                    if (endMs > startMs) {
                      segments.add({
                        'text': segment.text,
                        'startMs': startMs,
                        'endMs': endMs,
                      });
                    }
                  }
                  windowIndex++;
                }
                final transcript = transcriptParts.join(' ').trim();
                final recognizedFacts = recognizeExpectedKeyFacts(
                  transcript: transcript,
                  expectedKeyFacts: sample.expectedKeyFacts,
                );
                final observation = <String, Object?>{
                  'sampleId': sample.id,
                  'modelId': model.modelId,
                  'modelVersion': model.modelVersion,
                  'profileId': profile.id,
                  'deviceId': run.deviceId,
                  'inferenceDurationMs': inferenceDurationMicros / 1000,
                  // 固定 2 秒窗口到齐后的最慢端到端识别往返，作为保守句后延迟。
                  'sentenceLatencyMs': maximumWindowLatencyMicros / 1000,
                  'emittedText': transcript.isNotEmpty,
                  'recognizedKeyFacts': recognizedFacts,
                  'peakRssBytes': peakRssBytes,
                  'energyWh': null,
                  'energyEvidenceRef': null,
                  'sustainedSevereOrCriticalThermal': null,
                  'thermalEvidenceRef': null,
                };
                debugPrintSynchronously(
                  '$_observationMarker${jsonEncode({
                    'observation': observation,
                    'transcript': {'schemaVersion': 1, 'sampleId': sample.id, 'modelId': model.modelId, 'modelVersion': model.modelVersion, 'profileId': profile.id, 'text': transcript, 'segments': segments},
                  })}',
                  wrapWidth: null,
                );
                observationCount++;
              }
            } finally {
              await adapter.dispose();
            }
          }
        }

        final expectedCount = run.samples.length * run.profileRunCount;
        expect(observationCount, expectedCount);
        debugPrintSynchronously(
          '$_completeMarker${jsonEncode({'schemaVersion': 1, 'corpusId': run.corpusId, 'deviceId': run.deviceId, 'sampleCount': run.samples.length, 'profileRunCount': run.profileRunCount, 'observationCount': observationCount, 'windowDurationMs': 2000, 'energyStatus': 'not_collected', 'thermalStatus': 'not_collected'})}',
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
  });

  final String corpusId;
  final String deviceId;
  final int threadCount;
  final List<_DeviceSample> samples;
  final List<_DeviceModel> models;

  int get profileRunCount =>
      models.fold(0, (total, model) => total + model.profileIds.length);

  static Future<_DeviceBenchmarkRun> load(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw WhisperQualityProtocolException('设备评测清单不存在：$path');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?> ||
        decoded['schemaVersion'] != whisperQualitySchemaVersion) {
      throw const WhisperQualityProtocolException('设备评测清单 schemaVersion 必须为 1');
    }
    final rawSamples = decoded['samples'];
    final rawModels = decoded['models'];
    if (rawSamples is! List<Object?> || rawSamples.isEmpty) {
      throw const WhisperQualityProtocolException('设备评测 samples 不能为空');
    }
    if (rawModels is! List<Object?> || rawModels.isEmpty) {
      throw const WhisperQualityProtocolException('设备评测 models 不能为空');
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
