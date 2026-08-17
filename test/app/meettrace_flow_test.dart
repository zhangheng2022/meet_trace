import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_dependencies.dart';
import 'package:meettrace/app/meettrace_flow.dart';

void main() {
  testWidgets('初始化失败页连续点击重试只启动一个依赖创建任务', (tester) async {
    final retryCompletion = Completer<MeetTraceDependencies>();
    var attempts = 0;

    Future<MeetTraceDependencies> loadDependencies() {
      attempts++;
      if (attempts == 1) {
        return Future.error(StateError('initial failure'));
      }
      return retryCompletion.future;
    }

    await tester.pumpWidget(
      Application(
        home: MeetTraceBootstrap(
          preflight: () async {},
          loadDependencies: loadDependencies,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('重试'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text('重试'));
    await tester.tap(find.text('重试'));

    expect(attempts, 2);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('重试'), findsNothing);

    retryCompletion.completeError(StateError('retry failure'));
    await tester.pump();
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
