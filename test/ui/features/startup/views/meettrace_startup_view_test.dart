import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/features/startup/views/meettrace_startup_view.dart';

void main() {
  testWidgets('启动页说明真实本地准备内容与数据边界', (tester) async {
    await tester.pumpWidget(const Application(home: MeetTraceStartupView()));

    expect(find.text('会迹'), findsOneWidget);
    expect(find.text('MeetTrace'), findsOneWidget);
    expect(find.text('正在准备本地数据与离线模型'), findsOneWidget);
    expect(find.text('恢复会议记录，并校验标准转录模型'), findsOneWidget);
    expect(find.text('无需登录 · 事实音频仅保存在本机'), findsOneWidget);
    expect(find.byType(FHeader), findsNothing);
    expect(find.byType(FProgress), findsOneWidget);
    expect(
      tester.widget<FProgress>(find.byType(FProgress)).semanticsLabel,
      '正在准备本地数据与离线模型',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('启动页适配紧凑手机与双倍字体', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(const Application(home: MeetTraceStartupView()));

    expect(
      find.byKey(const ValueKey('meettrace-startup-loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meettrace-startup-local-evidence')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('启动页在宽屏保持紧凑内容宽度', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const Application(home: MeetTraceStartupView()));

    expect(
      tester
          .getSize(find.byKey(const ValueKey('meettrace-startup-loading')))
          .width,
      lessThanOrEqualTo(520),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('启动失败页保留数据承诺并可重试', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      Application(home: MeetTraceStartupErrorView(onRetry: () => retries++)),
    );

    expect(find.text('本地能力准备未完成'), findsOneWidget);
    expect(find.text('请确认设备空间充足后重试。已有会议数据不会被删除。'), findsOneWidget);
    expect(find.text('无需登录 · 事实音频仅保存在本机'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
