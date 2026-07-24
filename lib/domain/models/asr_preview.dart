import 'dart:typed_data';

enum AsrPreviewState { ready, backlogged, recordingOnly, disposed }

final class VadSpeechSegment {
  const VadSpeechSegment({required this.startSample, required this.endSample})
    : assert(startSample >= 0),
      assert(endSample > startSample);

  final int startSample;
  final int endSample;
}

final class AsrPreviewWindow {
  AsrPreviewWindow({
    required this.groupId,
    required this.windowIndex,
    required this.windowCount,
    required this.startSample,
    required this.endSample,
    required this.sampleRate,
    required Float32List samples,
  }) : samples = Float32List.fromList(samples) {
    if (groupId.trim().isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', '不能为空');
    }
    if (windowIndex < 0 || windowIndex >= windowCount) {
      throw ArgumentError('窗口序号必须位于窗口总数范围内');
    }
    if (sampleRate <= 0 ||
        startSample < 0 ||
        endSample <= startSample ||
        samples.length != endSample - startSample) {
      throw ArgumentError('预览窗口样本区间无效');
    }
  }

  final String groupId;
  final int windowIndex;
  final int windowCount;
  final int startSample;
  final int endSample;
  final int sampleRate;
  final Float32List samples;

  int get startMs => startSample * 1000 ~/ sampleRate;
  int get endMs => (endSample * 1000 + sampleRate - 1) ~/ sampleRate;
  int get audioDurationMs => endMs - startMs;
  bool get isLastWindow => windowIndex == windowCount - 1;
}

final class AsrPreviewMetrics {
  const AsrPreviewMetrics({
    required this.state,
    required this.vadSegmentCount,
    required this.queuedAudioMs,
    required this.processedPreviewWindows,
    required this.droppedPreviewWindows,
    required this.previewLagMs,
    this.lastErrorCode,
  });

  final AsrPreviewState state;
  final int vadSegmentCount;
  final int queuedAudioMs;
  final int processedPreviewWindows;
  final int droppedPreviewWindows;
  final int previewLagMs;
  final String? lastErrorCode;
}
