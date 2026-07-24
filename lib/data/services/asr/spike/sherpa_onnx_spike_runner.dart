import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart';

import 'asr_spike_models.dart';
import 'sherpa_onnx_spike_config.dart';

const sherpaOnnxSpikePackageVersion = '1.13.4';
// Paraformer 上游建议单段输入短于 20 秒，保留 5 秒余量。
const _spikeWindowSeconds = 15;

final class AsrSpikePrerequisiteException implements Exception {
  const AsrSpikePrerequisiteException({
    required this.message,
    this.missingRelativePaths = const [],
  });

  final String message;
  final List<String> missingRelativePaths;

  @override
  String toString() {
    final suffix = missingRelativePaths.isEmpty
        ? ''
        : ' 缺失：${missingRelativePaths.join(', ')}';
    return 'AsrSpikePrerequisiteException: $message$suffix';
  }
}

final class SherpaOnnxSpikeRunner {
  Future<List<AsrSpikeRunResult>> run({
    required AsrSpikeModelSpec spec,
    required String wavePath,
    int repeatCount = 2,
  }) async {
    if (repeatCount < 2) {
      throw const AsrSpikePrerequisiteException(
        message: '必须至少重复创建两次，以验证资源释放和重复初始化。',
      );
    }

    final validation = await spec.validateFiles();
    if (!validation.isValid) {
      throw AsrSpikePrerequisiteException(
        message: '模型文件不完整。',
        missingRelativePaths: validation.missingRelativePaths,
      );
    }
    if (!await File(wavePath).exists()) {
      throw const AsrSpikePrerequisiteException(message: '找不到 Spike 音频样本。');
    }

    var peakProcessRssBytes = ProcessInfo.currentRss;
    final memoryTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final currentRss = ProcessInfo.currentRss;
      if (currentRss > peakProcessRssBytes) {
        peakProcessRssBytes = currentRss;
      }
    });
    late final List<AsrSpikeRunResult> results;
    try {
      results = await Isolate.run(
        () => _runBlocking(
          spec: spec,
          wavePath: wavePath,
          repeatCount: repeatCount,
          validation: validation,
        ),
        debugName: 'meetily-asr-spike-${spec.kind.name}',
      );
    } finally {
      memoryTimer.cancel();
    }
    return List.unmodifiable(
      results.map(
        (result) => AsrSpikeRunResult(
          modelId: result.modelId,
          packageVersion: result.packageVersion,
          nativeVersion: result.nativeVersion,
          nativeGitSha1: result.nativeGitSha1,
          nativeGitDate: result.nativeGitDate,
          metrics: result.metrics,
          resultText: result.resultText,
          fileValidation: result.fileValidation,
          repeatIndex: result.repeatIndex,
          peakProcessRssBytes: peakProcessRssBytes,
          windows: result.windows,
        ),
      ),
    );
  }
}

List<AsrSpikeRunResult> _runBlocking({
  required AsrSpikeModelSpec spec,
  required String wavePath,
  required int repeatCount,
  required AsrSpikeFileValidation validation,
}) {
  initBindings();

  final wave = readWave(wavePath);
  if (wave.samples.isEmpty || wave.sampleRate <= 0) {
    throw const AsrSpikePrerequisiteException(
      message: '样本必须是 sherpa-onnx 可读取的单声道 PCM WAV。',
    );
  }

  final audioDuration = Duration(
    microseconds:
        (wave.samples.length * Duration.microsecondsPerSecond) ~/
        wave.sampleRate,
  );
  final results = <AsrSpikeRunResult>[];

  for (var repeatIndex = 1; repeatIndex <= repeatCount; repeatIndex++) {
    OfflineRecognizer? recognizer;
    final initializationWatch = Stopwatch()..start();
    try {
      recognizer = OfflineRecognizer(SherpaOnnxSpikeConfigFactory.create(spec));
      initializationWatch.stop();

      final inferenceWatch = Stopwatch()..start();
      Duration? firstResultDuration;
      final texts = <String>[];
      final windows = <AsrSpikeWindowMetrics>[];
      final samplesPerWindow = wave.sampleRate * _spikeWindowSeconds;
      for (
        var offset = 0;
        offset < wave.samples.length;
        offset += samplesPerWindow
      ) {
        final proposedEnd = offset + samplesPerWindow;
        final end = proposedEnd < wave.samples.length
            ? proposedEnd
            : wave.samples.length;
        final samples = Float32List.sublistView(wave.samples, offset, end);
        final stream = recognizer.createStream();
        final windowWatch = Stopwatch()..start();
        var resultCharacterCount = 0;
        try {
          stream.acceptWaveform(samples: samples, sampleRate: wave.sampleRate);
          recognizer.decode(stream);
          final text = recognizer.getResult(stream).text.trim();
          resultCharacterCount = text.runes.length;
          if (text.isNotEmpty) {
            firstResultDuration ??= inferenceWatch.elapsed;
            texts.add(text);
          }
        } finally {
          windowWatch.stop();
          stream.free();
        }
        windows.add(
          AsrSpikeWindowMetrics(
            index: windows.length + 1,
            startMs: (offset * 1000) ~/ wave.sampleRate,
            endMs: (end * 1000) ~/ wave.sampleRate,
            inferenceDuration: windowWatch.elapsed,
            resultCharacterCount: resultCharacterCount,
          ),
        );
      }
      inferenceWatch.stop();
      firstResultDuration ??= inferenceWatch.elapsed;

      results.add(
        AsrSpikeRunResult(
          modelId: spec.modelId,
          packageVersion: sherpaOnnxSpikePackageVersion,
          nativeVersion: getVersion(),
          nativeGitSha1: getGitSha1(),
          nativeGitDate: getGitDate(),
          metrics: AsrSpikeMetrics(
            audioDuration: audioDuration,
            initializationDuration: initializationWatch.elapsed,
            firstResultDuration: firstResultDuration,
            inferenceDuration: inferenceWatch.elapsed,
          ),
          resultText: texts.join('\n'),
          fileValidation: validation,
          repeatIndex: repeatIndex,
          peakProcessRssBytes: 0,
          windows: List.unmodifiable(windows),
        ),
      );
    } finally {
      if (initializationWatch.isRunning) {
        initializationWatch.stop();
      }
      recognizer?.free();
    }
  }

  return List.unmodifiable(results);
}
