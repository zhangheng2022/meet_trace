import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:meettrace/domain/use_cases/plan_asr_preview_windows.dart';

void main() {
  group('AsrPreviewWindowPlanner', () {
    test('加入前后文且不越过事实音频范围', () {
      const planner = AsrPreviewWindowPlanner();

      final windows = planner(
        segment: const VadSpeechSegment(startSample: 1600, endSample: 16000),
        availableStartSample: 0,
        availableEndSample: 17600,
      );

      expect(windows, [(startSample: 0, endSample: 17600)]);
    });

    test('超过 15 秒时使用固定重叠并保持单调区间', () {
      const planner = AsrPreviewWindowPlanner(
        contextBeforeMs: 0,
        contextAfterMs: 0,
      );

      final windows = planner(
        segment: const VadSpeechSegment(
          startSample: 0,
          endSample: 16 * asrPreviewSampleRate,
        ),
        availableStartSample: 0,
        availableEndSample: 16 * asrPreviewSampleRate,
      );

      expect(windows, [
        (startSample: 0, endSample: 15 * asrPreviewSampleRate),
        (
          startSample:
              (asrPreviewMaximumWindowMs - asrPreviewWindowOverlapMs) *
              asrPreviewSampleRate ~/
              1000,
          endSample: 16 * asrPreviewSampleRate,
        ),
      ]);
    });

    test('语音本身不超过上限时缩减上下文并只生成一个窗口', () {
      const planner = AsrPreviewWindowPlanner();
      const speechStart = 3200;
      const speechEnd = speechStart + 15 * asrPreviewSampleRate;

      final windows = planner(
        segment: const VadSpeechSegment(
          startSample: speechStart,
          endSample: speechEnd,
        ),
        availableStartSample: 0,
        availableEndSample: speechEnd + 3200,
      );

      expect(windows, [(startSample: speechStart, endSample: speechEnd)]);
    });
  });

  test('重叠窗口文本忽略边界标点并按可信后缀前缀合并', () {
    expect(
      mergeOverlappingTranscriptText('今天讨论项目计划', '项目计划已经确认'),
      '今天讨论项目计划已经确认',
    );
    expect(
      mergeOverlappingTranscriptText('今天讨论项目计划。', '项目计划，已经确认'),
      '今天讨论项目计划。已经确认',
    );
    expect(mergeOverlappingTranscriptText('第一段', '第二段'), '第一段 第二段');
    expect(mergeOverlappingTranscriptText('可以开始', '开始录音'), '可以开始 开始录音');
  });
}
