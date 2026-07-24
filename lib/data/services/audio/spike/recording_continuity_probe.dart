import 'dart:async';
import 'dart:io';

import 'package:record/record.dart';

import 'recording_continuity_metrics.dart';

final class RecordingContinuityProbe {
  static const sampleRate = 16000;
  static const channelCount = 1;

  Future<RecordingContinuityMetrics> run({
    required String outputPcmPath,
    required Duration duration,
    Future<void> Function()? concurrentWork,
  }) async {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', '必须大于 0。');
    }

    final recorder = AudioRecorder();
    if (!await recorder.hasPermission()) {
      await recorder.dispose();
      throw StateError('未获得麦克风权限，无法执行录音连续性 Spike。');
    }

    final output = File(outputPcmPath);
    await output.parent.create(recursive: true);
    final sink = output.openWrite();
    var bytesWritten = 0;
    Object? concurrentError;
    StackTrace? concurrentStackTrace;

    final audioStream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: channelCount,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
    final consumeFuture = audioStream.forEach((chunk) {
      sink.add(chunk);
      bytesWritten += chunk.length;
    });
    final concurrentFuture = (concurrentWork?.call() ?? Future<void>.value())
        .catchError((Object error, StackTrace stackTrace) {
          concurrentError = error;
          concurrentStackTrace = stackTrace;
        });

    final watch = Stopwatch()..start();
    try {
      await Future<void>.delayed(duration);
      await recorder.stop();
      await consumeFuture;
    } finally {
      watch.stop();
      await recorder.dispose();
      await sink.flush();
      await sink.close();
    }
    await concurrentFuture;

    if (concurrentError != null) {
      Error.throwWithStackTrace(concurrentError!, concurrentStackTrace!);
    }

    return RecordingContinuityMetrics(
      bytesWritten: bytesWritten,
      elapsed: watch.elapsed,
      sampleRate: sampleRate,
      channelCount: channelCount,
    );
  }
}
