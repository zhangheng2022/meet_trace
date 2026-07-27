import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/spike/recording_continuity_metrics.dart';

void main() {
  group('RecordingContinuityMetrics', () {
    test('PCM16 单声道写入量符合持续时间时完整率为 100%', () {
      final metrics = RecordingContinuityMetrics(
        bytesWritten: 320000,
        elapsed: const Duration(seconds: 10),
        sampleRate: 16000,
        channelCount: 1,
      );

      expect(metrics.expectedBytes, 320000);
      expect(metrics.completenessRatio, 1);
      expect(metrics.isComplete, isTrue);
    });

    test('低于 98% 时判定录音不完整', () {
      final metrics = RecordingContinuityMetrics(
        bytesWritten: 300000,
        elapsed: const Duration(seconds: 10),
        sampleRate: 16000,
        channelCount: 1,
      );

      expect(metrics.completenessRatio, closeTo(0.9375, 0.0001));
      expect(metrics.isComplete, isFalse);
    });
  });
}
