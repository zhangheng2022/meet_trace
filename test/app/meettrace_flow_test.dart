import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_dependencies.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/app/meettrace_meeting_dependencies.dart';
import 'package:meettrace/data/services/asr/platform_asr_device_risk_monitor.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/l10n/l10n.dart';
import 'package:meettrace/ui/features/meetings/views/detail/meeting_detail_view.dart';
import 'package:meettrace/ui/features/meetings/views/list/meeting_list_view.dart';
import 'package:meettrace/ui/features/meetings/views/recording/recording_bootstrap_view.dart';
import 'package:meettrace/ui/features/settings/views/transcription_sources_view.dart';
import 'package:meettrace/ui/features/startup/views/meettrace_startup_view.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  for (final scenario in const {
    'home': '全新空模型目录启动直接进入会议首页，不前置下载全部权重',
    'start': '开始会议的来源偏好读取失败显示安全提示并解除忙碌状态',
    'retranscribe': '会后换来源的偏好读取失败显示安全提示并保留录音',
  }.entries) {
    testWidgets(scenario.value, (tester) async {
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
        if (call.method == 'getApplicationSupportDirectory') {
          return support!.path;
        }
        throw StateError('unexpected path request: ${call.method}');
      });
      FlutterSecureStorage.setMockInitialValues({});
      final audioChannels = <MethodChannel>[];
      void mockAudioChannel(String name) {
        final channel = MethodChannel(name);
        audioChannels.add(channel);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'create') {
              mockAudioChannel(
                'xyz.luan/audioplayers/events/${call.arguments['playerId']}',
              );
            }
            return null;
          },
        );
      }

      if (scenario.key == 'retranscribe') {
        for (final name in [
          'xyz.luan/audioplayers',
          'xyz.luan/audioplayers.global',
          'xyz.luan/audioplayers.global/events',
        ]) {
          mockAudioChannel(name);
        }
      }
      addTearDown(() async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          paths,
          null,
        );
        for (final channel in audioChannels) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        }
        if (support != null &&
            p.basename(support.path).startsWith('meettrace-bootstrap-test-')) {
          await support.delete(recursive: true);
        }
      });
      // 必须先验证实际应用目录已隔离，才能调用包含数据代清理的真实依赖创建。
      final layout = await tester.runAsync(AppFileLayout.forApplication);
      expect(p.isWithin(support!.path, layout!.rootPath), isTrue);
      final dependencies = await tester.runAsync(
        () => MeetTraceDependencies.create(
          createMeeting: ({required storage, required runtime}) =>
              MeetingDependencies.create(
                storage: storage,
                runtime: runtime,
                riskMonitor: PortableAsrDeviceRiskMonitor(
                  processRssReader: () => 42,
                ),
              ),
        ),
      );
      expect(dependencies, isNotNull);
      addTearDown(() async {
        await tester.runAsync(() async {
          await tester.pumpWidget(const SizedBox());
          final disposal = dependencies!.dispose();
          expect(dependencies.dispose(), same(disposal));
          await disposal;
        });
        expect(tester.takeException(), isNull);
      });
      final weights = await tester.runAsync(
        () async =>
            Directory(layout.modelsRoot)
                .list(recursive: true)
                .where((entry) => entry is File)
                .toList(),
      );
      expect(weights, isEmpty);

      final routes = _RouteObserver();
      await tester.pumpWidget(
        Application(
          navigatorObservers: [routes],
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
      expect(find.byType(MeetTraceStartupView), findsNothing);
      expect(tester.takeException(), isNull);

      if (scenario.key != 'home') {
        await tester.runAsync(() async {
          final db = await dependencies!.storage.database.open();
          final l10n = tester.element(find.byType(MeetingListView)).l10n;
          File? fact;
          if (scenario.key == 'retranscribe') {
            final profile = TranscriptionProfile.local();
            fact = File(layout.meetingAudioPath('source-failure'));
            final meeting = Meeting(
              id: 'source-failure',
              title: 'Source failure',
              createdAt: DateTime(2026),
              status: MeetingState.failed,
              audioPath: fact.path,
              audioDurationMs: 1000,
              recordingModelId: profile.modelId,
              recordingModelVersion: profile.identityVersion,
              transcriptionProfile: profile,
            );
            await fact.parent.create(recursive: true);
            await fact.writeAsBytes([1, 2]);
            await dependencies.storage.meetings.save(meeting);
            tester
                .widget<MeetingListView>(find.byType(MeetingListView))
                .onOpenMeeting!(meeting);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            final detail = tester.widget<MeetingDetailView>(
              find.byType(MeetingDetailView),
            );
            await detail.viewModel.load();
            detail.onChooseTranscriptionSource!();
          } else {
            tester
                .widget<MeetingListView>(find.byType(MeetingListView))
                .onStartMeeting!();
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await db.execute('ALTER TABLE app_settings RENAME TO saved_settings');
          final failureRoute = Completer<void>();
          routes.onPush = () => failureRoute.complete();
          // 完成真实选择路由，随后分离偏好查询会因隔离库表缺失而失败。
          Navigator.of(tester.element(find.byType(TranscriptionSourcesView)))
              .pop(TranscriptionProfile.local());
          await failureRoute.future.timeout(const Duration(seconds: 5));
          routes.onPush = null;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(FDialog), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(FDialog),
              matching: find.text(l10n.sourceFailure),
            ),
            findsOneWidget,
          );
          expect(find.byType(RecordingBootstrapView), findsNothing);
          expect(tester.takeException(), isNull);
          await db.execute('ALTER TABLE saved_settings RENAME TO app_settings');
          Navigator.of(tester.element(find.byType(FDialog))).pop();
          await tester.pumpAndSettle();
          if (fact != null) {
            expect(await fact.readAsBytes(), [1, 2]);
            final unchanged = await dependencies.storage.meetings.getById(
              'source-failure',
            );
            expect(unchanged!.status, MeetingState.failed);
            expect(unchanged.activeTranscriptSnapshotId, isNull);
          } else {
            expect(
              tester
                  .widget<MeetingListView>(find.byType(MeetingListView))
                  .startingMeeting,
              isFalse,
            );
            expect(await dependencies.storage.meetings.listAll(), isEmpty);
          }
        });
      }
    });
  }

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

final class _RouteObserver extends NavigatorObserver {
  VoidCallback? onPush;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPush?.call();
  }
}
