import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/monitoring/sentry_isolate_error_monitor.dart';

void main() {
  test('转发后台 Isolate 未处理错误并可重复关闭', () async {
    final captured = Completer<(Object, StackTrace?)>();
    final isolate = await Isolate.spawn<void>(
      _throwUnhandled,
      null,
      paused: true,
    );
    final monitor = SentryIsolateErrorMonitor.attach(
      isolate,
      capture: (error, stackTrace) {
        captured.complete((error, stackTrace));
      },
    );

    isolate.resume(isolate.pauseCapability!);
    final (error, stackTrace) = await captured.future.timeout(
      const Duration(seconds: 2),
    );

    expect(error.toString(), 'BackgroundIsolateError');
    expect(error.toString(), isNot(contains('isolate-test-error')));
    expect(stackTrace.toString(), contains('_throwUnhandled'));
    monitor.close();
    monitor.close();
    isolate.kill(priority: Isolate.immediate);
  });

  test('同步或异步捕获失败均不产生未处理异常', () async {
    for (final failCapture in <IsolateErrorCapture>[
      (_, _) => throw StateError('sync-capture-failed'),
      (_, _) async => throw StateError('async-capture-failed'),
    ]) {
      final uncaught = <Object>[];
      final attempted = Completer<void>();
      final guarded = runZonedGuarded(() async {
        final isolate = await Isolate.spawn<void>(
          _throwUnhandled,
          null,
          paused: true,
        );
        final monitor = SentryIsolateErrorMonitor.attach(
          isolate,
          capture: (error, stackTrace) {
            attempted.complete();
            return failCapture(error, stackTrace);
          },
        );
        isolate.resume(isolate.pauseCapability!);
        await attempted.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);
        monitor.close();
        isolate.kill(priority: Isolate.immediate);
      }, (error, _) => uncaught.add(error));

      await guarded;
      expect(uncaught, isEmpty);
    }
  });
}

Never _throwUnhandled(void _) => throw StateError('isolate-test-error');
