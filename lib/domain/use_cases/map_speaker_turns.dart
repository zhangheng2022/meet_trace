import '../models/speaker_diarization.dart';
import '../models/transcript.dart';

/// 校验说话人时间段是否能安全应用到指定事实音频。
///
/// 最终转录与独立说话人增强必须共用这一契约，避免同一服务结果在两条路径中
/// 得到不同处理。
void validateSpeakerTurns(Iterable<SpeakerTurn> turns, int audioDurationMs) {
  for (final turn in turns) {
    if (turn.startMs < 0 ||
        turn.endMs <= turn.startMs ||
        turn.endMs > audioDurationMs ||
        turn.speakerId.trim().isEmpty) {
      throw const SpeakerDiarizationException(
        'speaker_diarization.invalid_result',
      );
    }
  }
}

/// 按时间重叠将转录片段映射到最匹配的说话人。
///
/// 重叠时长相同则优先选择更早开始的区段；开始时间仍相同则按说话人 ID
/// 排序，确保最终快照和独立说话人增强得到确定性一致结果。
String mapTranscriptSegmentToSpeaker({
  required TranscriptSegment segment,
  required Iterable<SpeakerTurn> turns,
  required String fallbackSpeakerId,
}) {
  SpeakerTurn? best;
  var bestOverlap = 0;
  for (final turn in turns) {
    final start = segment.startMs > turn.startMs
        ? segment.startMs
        : turn.startMs;
    final end = segment.endMs < turn.endMs ? segment.endMs : turn.endMs;
    final overlap = end > start ? end - start : 0;
    if (overlap > bestOverlap ||
        (overlap == bestOverlap && overlap > 0 && _comesBefore(turn, best!))) {
      best = turn;
      bestOverlap = overlap;
    }
  }
  return bestOverlap == 0 ? fallbackSpeakerId : best!.speakerId.trim();
}

bool _comesBefore(SpeakerTurn candidate, SpeakerTurn current) {
  final byStart = candidate.startMs.compareTo(current.startMs);
  if (byStart != 0) {
    return byStart < 0;
  }
  return candidate.speakerId.compareTo(current.speakerId) < 0;
}
