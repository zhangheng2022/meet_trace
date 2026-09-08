import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_dependencies.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/ui/features/meetings/views/list/meeting_list_view.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('全新空模型目录启动直接进入会议首页，不前置下载全部权重', (tester) async {
    final originalFactory = databaseFactoryOrNull;
    sqfliteFfiInit();
    databaseFactoryOrNull = databaseFactoryFfi;
    addTearDown(() => databaseFactoryOrNull = originalFactory);
    final support = await tester.runAsync(
      () => Directory.systemTemp.createTemp('meettrace-bootstrap-test-'),
    );
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (
      call,
    ) async {
      if (call.method == 'getApplicationSupportDirectory') return support!.path;
      throw StateError('unexpected path request: ${call.method}');
    });
    FlutterSecureStorage.setMockInitialValues({});
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        paths,
        null,
      );
      if (support != null &&
          p.basename(support.path).startsWith('meettrace-bootstrap-test-')) {
        await support.delete(recursive: true);
      }
    });
    // 必须先验证实际应用目录已隔离，才能调用包含数据代清理的真实依赖创建。
    final layout = await tester.runAsync(AppFileLayout.forApplication);
    expect(p.isWithin(support!.path, layout!.rootPath), isTrue);
    final dependencies = await tester.runAsync(MeetTraceDependencies.create);
    expect(dependencies, isNotNull);
    final weights = await tester.runAsync(
      () async =>
          Directory(layout.modelsRoot)
              .list(recursive: true)
              .where((entry) => entry is File)
              .toList(),
    );
    expect(weights, isEmpty);

    await tester.pumpWidget(
      Application(
        home: MeetTraceBootstrap(
          preflight: () async {},
          loadDependencies: () async => dependencies!,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      await dependencies!.storage.meetings.listAll();
    });
    await tester.pump();

    expect(find.byType(MeetingListView), findsOneWidget);
    expect(find.text('正在准备会迹'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      // 等真实数据库订阅和 bootstrap 的异步 dispose 释放隔离目录。
      await tester.pumpWidget(const SizedBox());
      await dependencies!.dispose();
    });
  });

  testWidgets('首页不展示 Sentry 告知', (tester) async {
    await tester.pumpWidget(
      Application(
        home: MeetTraceBootstrap(
          preflight: () async {},
          loadDependencies: () => Completer<MeetTraceDependencies>().future,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('remote-diagnostics-notice')),
      findsNothing,
    );
    expect(find.text('正在准备会迹'), findsOneWidget);
  });

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
