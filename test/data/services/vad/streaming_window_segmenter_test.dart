import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/vad/streaming_window_segmenter.dart';

void main() {
  test('默认以 2 秒窗口和 0.5 秒重叠连续生成全局区间', () {
    final segmenter = StreamingWindowSegmenter();

    expect(segmenter.accept(Float32List(16000)), isEmpty);
    expect(
      segmenter
          .accept(Float32List(16000))
          .map((segment) => (segment.startSample, segment.endSample)),
      [(0, 32000)],
    );
    expect(
      segmenter
          .accept(Float32List(24000))
          .map((segment) => (segment.startSample, segment.endSample)),
      [(24000, 56000)],
    );
  });

  test('flush 只输出至少 0.5 秒的剩余窗口且不会重复输出', () {
    final segmenter = StreamingWindowSegmenter();
    segmenter.accept(Float32List(12000));

    expect(
      segmenter.flush().map(
        (segment) => (segment.startSample, segment.endSample),
      ),
      [(0, 12000)],
    );
    expect(segmenter.flush(), isEmpty);
  });

  test('时间轴中断后 reset 从新的全局样本位置继续', () {
    final segmenter = StreamingWindowSegmenter();
    segmenter.accept(Float32List(16000));

    segmenter.reset(nextStartSample: 80000);

    expect(
      segmenter
          .accept(Float32List(32000))
          .map((segment) => (segment.startSample, segment.endSample)),
      [(80000, 112000)],
    );
  });

  test('释放后拒绝继续接收或刷新', () {
    final segmenter = StreamingWindowSegmenter()..dispose();

    expect(() => segmenter.accept(Float32List(1)), throwsStateError);
    expect(segmenter.flush, throwsStateError);
  });
}
