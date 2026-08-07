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
    var expandedStart = (segment.startSample - contextBeforeSamples).clamp(
      availableStartSample,
      availableEndSample,
    );
    var expandedEnd = (segment.endSample + contextAfterSamples).clamp(
      availableStartSample,
      availableEndSample,
    );

    final speechSamples = segment.endSample - segment.startSample;
    if (speechSamples <= maximumWindowSamples &&
        expandedEnd - expandedStart > maximumWindowSamples) {
      final contextBudget = maximumWindowSamples - speechSamples;
      final requestedBefore = segment.startSample - expandedStart;
      final requestedAfter = expandedEnd - segment.endSample;
      var retainedBefore = requestedBefore < contextBudget ~/ 2
          ? requestedBefore
          : contextBudget ~/ 2;
      var retainedAfter = requestedAfter < contextBudget - retainedBefore
          ? requestedAfter
          : contextBudget - retainedBefore;
      var remaining = contextBudget - retainedBefore - retainedAfter;
      final additionalBefore = requestedBefore - retainedBefore < remaining
          ? requestedBefore - retainedBefore
          : remaining;
      retainedBefore += additionalBefore;
      remaining -= additionalBefore;
      final additionalAfter = requestedAfter - retainedAfter < remaining
          ? requestedAfter - retainedAfter
          : remaining;
      retainedAfter += additionalAfter;
      expandedStart = segment.startSample - retainedBefore;
      expandedEnd = segment.endSample + retainedAfter;
    }

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
  final normalizedLeft = _normalizeForOverlap(left);
  final normalizedRight = _normalizeForOverlap(right);
  final maximumOverlap =
      normalizedLeft.tokens.length < normalizedRight.tokens.length
      ? normalizedLeft.tokens.length
      : normalizedRight.tokens.length;
  for (var length = maximumOverlap; length >= 4; length--) {
    if (_hasNormalizedOverlap(
      normalizedLeft.tokens,
      normalizedRight.tokens,
      length,
    )) {
      var rightOffset = normalizedRight.sourceEndOffsets[length - 1];
      while (rightOffset < right.length &&
          _isOverlapSeparator(_runeAt(right, rightOffset))) {
        rightOffset += _runeWidth(_runeAt(right, rightOffset));
      }
      return '$left${right.substring(rightOffset)}';
    }
  }
  return '$left $right';
}

({List<String> tokens, List<int> sourceEndOffsets}) _normalizeForOverlap(
  String source,
) {
  final tokens = <String>[];
  final offsets = <int>[];
  var offset = 0;
  while (offset < source.length) {
    final rune = _runeAt(source, offset);
    final width = _runeWidth(rune);
    if (!_isOverlapSeparator(rune)) {
      tokens.add(String.fromCharCode(rune).toLowerCase());
      offsets.add(offset + width);
    }
    offset += width;
  }
  return (tokens: tokens, sourceEndOffsets: offsets);
}

bool _hasNormalizedOverlap(List<String> left, List<String> right, int length) {
  final leftStart = left.length - length;
  for (var index = 0; index < length; index++) {
    if (left[leftStart + index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _isOverlapSeparator(int rune) {
  if (rune <= 0x20) {
    return true;
  }
  return switch (rune) {
    0x0021 || // !
    0x0022 || // "
    0x0027 || // '
    0x0028 || // (
    0x0029 || // )
    0x002C || // ,
    0x002D || // -
    0x002E || // .
    0x003A || // :
    0x003B || // ;
    0x003F || // ?
    0x005B || // [
    0x005D || // ]
    0x2014 || // —
    0x2018 || // ‘
    0x2019 || // ’
    0x201C || // “
    0x201D || // ”
    0x2026 || // …
    0x3001 || // 、
    0x3002 || // 。
    0x3010 || // 【
    0x3011 || // 】
    0xFF01 || // ！
    0xFF08 || // （
    0xFF09 || // ）
    0xFF0C || // ，
    0xFF1A || // ：
    0xFF1B || // ；
    0xFF1F => true, // ？
    _ => false,
  };
}

int _runeWidth(int rune) => rune > 0xFFFF ? 2 : 1;

int _runeAt(String source, int offset) {
  final first = source.codeUnitAt(offset);
  if (first < 0xD800 || first > 0xDBFF || offset + 1 >= source.length) {
    return first;
  }
  final second = source.codeUnitAt(offset + 1);
  if (second < 0xDC00 || second > 0xDFFF) {
    return first;
  }
  return 0x10000 + ((first - 0xD800) << 10) + second - 0xDC00;
}
