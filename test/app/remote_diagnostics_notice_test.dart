import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/app/meettrace_dependencies.dart';
import 'package:meettrace/app/meettrace_flow.dart';
import 'package:meettrace/domain/ports/repositories.dart';

void main() {
  testWidgets('首次首屏展示一次非阻断远程诊断告知并可关闭', (tester) async {
    final preferences = _RemoteDiagnosticsPreferences();
    final loading = Completer<MeetTraceDependencies>();

    await tester.pumpWidget(
      Application(
        home: MeetTraceBootstrap(
          loadDependencies: () => loading.future,
          preflight: () async {},
          remoteDiagnosticsPreferences: preferences,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('remote-diagnostics-notice')),
      findsOneWidget,
    );
    expect(find.text('正在准备会迹'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('dismiss-remote-diagnostics-notice')),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(preferences.noticeDismissed, isTrue);
    expect(
      find.byKey(const ValueKey('remote-diagnostics-notice')),
      findsNothing,
    );
  });

  testWidgets('已关闭告知或远程诊断时不再展示', (tester) async {
    for (final preferences in <_RemoteDiagnosticsPreferences>[
      _RemoteDiagnosticsPreferences(noticeDismissed: true),
      _RemoteDiagnosticsPreferences(enabled: false),
    ]) {
      await tester.pumpWidget(
        Application(
          home: MeetTraceBootstrap(
            key: ValueKey(
              '${preferences.enabled}-${preferences.noticeDismissed}',
            ),
            loadDependencies: () => Completer<MeetTraceDependencies>().future,
            preflight: () async {},
            remoteDiagnosticsPreferences: preferences,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('remote-diagnostics-notice')),
        findsNothing,
      );
    }
  });

  testWidgets('远程诊断开关读取失败时不展示告知', (tester) async {
    await tester.pumpWidget(
      Application(
        home: MeetTraceBootstrap(
          loadDependencies: () => Completer<MeetTraceDependencies>().future,
          preflight: () async {},
          remoteDiagnosticsPreferences: _RemoteDiagnosticsPreferences(
            failReading: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('remote-diagnostics-notice')),
      findsNothing,
    );
  });

  testWidgets('告知状态读取失败时仍展示告知', (tester) async {
    await tester.pumpWidget(
      Application(
        home: MeetTraceBootstrap(
          loadDependencies: () => Completer<MeetTraceDependencies>().future,
          preflight: () async {},
          remoteDiagnosticsPreferences: _RemoteDiagnosticsPreferences(
            failNoticeReading: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('remote-diagnostics-notice')),
      findsOneWidget,
    );
  });
}

final class _RemoteDiagnosticsPreferences
    implements RemoteDiagnosticsPreferenceRepository {
  _RemoteDiagnosticsPreferences({
    this.enabled = true,
    this.noticeDismissed = false,
    this.failReading = false,
    this.failNoticeReading = false,
  });

  bool enabled;
  bool noticeDismissed;
  final bool failReading;
  final bool failNoticeReading;

  @override
  Future<bool> getEnabled() async {
    if (failReading) {
      throw StateError('preferences unavailable');
    }
    return enabled;
  }

  @override
  Future<bool> getNoticeDismissed() async {
    if (failNoticeReading) {
      throw StateError('notice preference unavailable');
    }
    return noticeDismissed;
  }

  @override
  Future<void> setEnabled(bool enabled) async => this.enabled = enabled;

  @override
  Future<void> setNoticeDismissed() async => noticeDismissed = true;
}
