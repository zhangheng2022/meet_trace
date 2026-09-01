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
}

Never _throwUnhandled(void _) => throw StateError('isolate-test-error');
