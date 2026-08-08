import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/speaker_diarization.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/use_cases/map_speaker_turns.dart';

void main() {
  final segment = TranscriptSegment(
    id: 'segment-1',
    snapshotId: 'snapshot-1',
    startMs: 1000,
    endMs: 3000,
    text: '测试',
    modelId: 'sense-voice',
    modelVersion: 'v1',
  );

  test('选择重叠时间最长的说话人并清理 ID 空白', () {
    final speakerId = mapTranscriptSegmentToSpeaker(
      segment: segment,
      turns: const [
        SpeakerTurn(startMs: 500, endMs: 1500, speakerId: 'speaker-1'),
        SpeakerTurn(startMs: 1200, endMs: 2800, speakerId: ' speaker-2 '),
      ],
      fallbackSpeakerId: 'fallback',
    );

    expect(speakerId, 'speaker-2');
  });

  test('重叠相同时优先更早开始的区段', () {
    final speakerId = mapTranscriptSegmentToSpeaker(
      segment: segment,
      turns: const [
        SpeakerTurn(startMs: 2000, endMs: 3000, speakerId: 'speaker-2'),
        SpeakerTurn(startMs: 500, endMs: 2000, speakerId: 'speaker-1'),
      ],
      fallbackSpeakerId: 'fallback',
    );

    expect(speakerId, 'speaker-1');
  });

  test('开始时间也相同时按说话人 ID 保持确定性', () {
    final speakerId = mapTranscriptSegmentToSpeaker(
      segment: segment,
      turns: const [
        SpeakerTurn(startMs: 1000, endMs: 2000, speakerId: 'speaker-b'),
        SpeakerTurn(startMs: 1000, endMs: 2000, speakerId: 'speaker-a'),
      ],
      fallbackSpeakerId: 'fallback',
    );

    expect(speakerId, 'speaker-a');
  });

  test('没有重叠时返回单一说话人降级值', () {
    final speakerId = mapTranscriptSegmentToSpeaker(
      segment: segment,
      turns: const [
        SpeakerTurn(startMs: 3000, endMs: 4000, speakerId: 'speaker-2'),
      ],
      fallbackSpeakerId: 'speaker-1',
    );

    expect(speakerId, 'speaker-1');
  });

  group('validateSpeakerTurns', () {
    test('接受事实音频范围内的非空说话人时间段', () {
      expect(
        () => validateSpeakerTurns(const [
          SpeakerTurn(startMs: 0, endMs: 1000, speakerId: 'speaker-1'),
        ], 1000),
        returnsNormally,
      );
    });

    test('拒绝超过事实音频范围的时间段', () {
      expect(
        () => validateSpeakerTurns(const [
          SpeakerTurn(startMs: 0, endMs: 1001, speakerId: 'speaker-1'),
        ], 1000),
        _throwsInvalidResult,
      );
    });

    test('拒绝只包含空白的说话人 ID', () {
      expect(
        () => validateSpeakerTurns(const [
          SpeakerTurn(startMs: 0, endMs: 1000, speakerId: ' '),
        ], 1000),
        _throwsInvalidResult,
      );
    });
  });
}

final Matcher _throwsInvalidResult = throwsA(
  isA<SpeakerDiarizationException>().having(
    (error) => error.code,
    'code',
    'speaker_diarization.invalid_result',
  ),
);
