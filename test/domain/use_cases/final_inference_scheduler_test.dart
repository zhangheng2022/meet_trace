import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/use_cases/final_inference_scheduler.dart';

void main() {
  test('跨会议任务按入队顺序串行执行', () async {
    final scheduler = FinalInferenceScheduler();
    final firstGate = Completer<void>();
    final events = <String>[];

    final first = scheduler.schedule(() async {
      events.add('first-start');
      await firstGate.future;
      events.add('first-end');
      return 1;
    });
    final second = scheduler.schedule(() async {
      events.add('second-start');
      return 2;
    });
    await Future<void>.delayed(Duration.zero);

    expect(events, ['first-start']);
    firstGate.complete();

    expect(await Future.wait([first, second]), [1, 2]);
    expect(events, ['first-start', 'first-end', 'second-start']);
  });

  test('前一任务失败后仍释放队列执行下一任务', () async {
    final scheduler = FinalInferenceScheduler();
    final first = scheduler.schedule<void>(
      () => throw StateError('inference failed'),
    );
    final second = scheduler.schedule(() async => 'completed');

    await expectLater(first, throwsStateError);
    expect(await second, 'completed');
  });
}
