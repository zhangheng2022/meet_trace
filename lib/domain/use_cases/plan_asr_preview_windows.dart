import '../models/asr_preview.dart';

const asrPreviewSampleRate = 16000;
const asrPreviewMaximumWindowMs = 15000;
const asrPreviewWindowOverlapMs = 500;
const asrPreviewContextBeforeMs = 200;
const asrPreviewContextAfterMs = 200;

final class AsrPreviewWindowPlanner {
  const AsrPreviewWindowPlanner({
    this.sampleRate = asrPreviewSampleRate,
    this.maximumWindowMs = asrPreviewMaximumWindowMs,
    this.overlapMs = asrPreviewWindowOverlapMs,
    this.contextBeforeMs = asrPreviewContextBeforeMs,
    this.contextAfterMs = asrPreviewContextAfterMs,
  }) : assert(sampleRate > 0),
       assert(maximumWindowMs > 0),
       assert(overlapMs >= 0),
       assert(overlapMs < maximumWindowMs),
       assert(contextBeforeMs >= 0),
       assert(contextAfterMs >= 0);

  final int sampleRate;
  final int maximumWindowMs;
  final int overlapMs;
  final int contextBeforeMs;
  final int contextAfterMs;

  List<({int startSample, int endSample})> call({
    required VadSpeechSegment segment,
    required int availableStartSample,
    required int availableEndSample,
  }) {
    if (availableStartSample < 0 ||
        availableEndSample <= availableStartSample ||
        segment.startSample < availableStartSample ||
        segment.endSample > availableEndSample) {
      throw ArgumentError('VAD 片段超出当前可用音频范围');
    }

    final contextBeforeSamples = _samplesForMs(contextBeforeMs);
    final contextAfterSamples = _samplesForMs(contextAfterMs);
    final maximumWindowSamples = _samplesForMs(maximumWindowMs);
    final overlapSamples = _samplesForMs(overlapMs);
    final expandedStart = (segment.startSample - contextBeforeSamples).clamp(
      availableStartSample,
      availableEndSample,
    );
    final expandedEnd = (segment.endSample + contextAfterSamples).clamp(
      availableStartSample,
      availableEndSample,
    );

    final windows = <({int startSample, int endSample})>[];
    var start = expandedStart;
    while (expandedEnd - start > maximumWindowSamples) {
      final end = start + maximumWindowSamples;
      windows.add((startSample: start, endSample: end));
      start = end - overlapSamples;
    }
    windows.add((startSample: start, endSample: expandedEnd));
    return List.unmodifiable(windows);
  }

  int _samplesForMs(int milliseconds) {
    return milliseconds * sampleRate ~/ Duration.millisecondsPerSecond;
  }
}

String mergeOverlappingTranscriptText(String earlier, String later) {
  final left = earlier.trim();
  final right = later.trim();
  if (left.isEmpty) {
    return right;
  }
  if (right.isEmpty || left == right) {
    return left;
  }
  final maximumOverlap = left.length < right.length
      ? left.length
      : right.length;
  for (var length = maximumOverlap; length > 0; length--) {
    if (left.endsWith(right.substring(0, length))) {
      return '$left${right.substring(length)}';
    }
  }
  return '$left $right';
}
