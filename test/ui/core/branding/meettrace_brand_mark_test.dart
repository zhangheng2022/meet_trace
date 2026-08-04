import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/core/branding/meettrace_brand_mark.dart';

void main() {
  testWidgets('品牌标志按矢量路径完整渲染', (tester) async {
    await tester.pumpWidget(
      const Application(home: Center(child: MeetTraceBrandMark())),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('meettrace-brand-mark'))),
      const Size.square(52),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('墨带描写始终裁切在官方标志轮廓内', (tester) async {
    await tester.pumpWidget(
      const Application(
        home: Center(child: MeetTraceRibbonRevealMark(progress: 0.48)),
      ),
    );

    final mark = tester.widget<MeetTraceRibbonRevealMark>(
      find.byType(MeetTraceRibbonRevealMark),
    );
    expect(mark.progress, 0.48);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('meettrace-ribbon-reveal-mark')),
      ),
      const Size.square(72),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const Application(
        home: Center(child: MeetTraceRibbonRevealMark(progress: 1)),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('960ms 品牌动效依次完成墨带写入、归位和字标揭示', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const Application(
        home: Center(
          child: MeetTraceAnimatedWordmark(disableAnimations: false),
        ),
      ),
    );

    expect(meetTraceBrandMotionDuration, const Duration(milliseconds: 960));
    expect(_ribbonProgress(tester), 0);
    expect(_chineseReveal(tester), 0);
    expect(_englishReveal(tester), 0);
    final centeredLeft = _markStage(tester).left!;
    expect(_markStage(tester).width, 72);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('meettrace-startup-wordmark')),
          )
          .label,
      '会迹，MeetTrace',
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 480));
    expect(_ribbonProgress(tester), inExclusiveRange(0, 1));
    expect(_markStage(tester).left, centeredLeft);
    expect(_chineseReveal(tester), 0);
    expect(_englishReveal(tester), 0);

    await tester.pump(const Duration(milliseconds: 240));
    expect(_ribbonProgress(tester), 1);
    expect(_markStage(tester).left!, lessThan(centeredLeft));
    expect(_markStage(tester).width!, inExclusiveRange(52, 72));
    expect(_chineseReveal(tester), 0);

    await tester.pump(const Duration(milliseconds: 120));
    expect(_chineseReveal(tester), inExclusiveRange(0, 1));
    expect(_englishReveal(tester), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 120));
    expect(_ribbonProgress(tester), 1);
    expect(_markStage(tester).left, 0);
    expect(_markStage(tester).top, 10);
    expect(_markStage(tester).width, 52);
    expect(_chineseReveal(tester), 1);
    expect(_englishReveal(tester), 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('减少动态效果时直接显示最终品牌状态', (tester) async {
    await tester.pumpWidget(
      const Application(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: MeetTraceAnimatedWordmark()),
        ),
      ),
    );

    expect(_ribbonProgress(tester), 1);
    expect(_markStage(tester).left, 0);
    expect(_markStage(tester).width, 52);
    expect(_chineseReveal(tester), 1);
    expect(_englishReveal(tester), 1);
    await tester.pump(meetTraceBrandMotionDuration);
    expect(_ribbonProgress(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('品牌动效同时使用亮色与暗色主题', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      const Application(home: Center(child: MeetTraceAnimatedWordmark())),
    );
    BuildContext markContext() =>
        tester.element(find.byType(MeetTraceRibbonRevealMark));
    expect(Theme.of(markContext()).brightness, Brightness.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(markContext()).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('父组件重建不会重新播放品牌动效', (tester) async {
    const wordmarkKey = ValueKey('persistent-brand-motion');
    Widget build() => const Application(
      home: Center(
        child: MeetTraceAnimatedWordmark(
          key: wordmarkKey,
          disableAnimations: false,
        ),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump(meetTraceBrandMotionDuration);
    expect(_ribbonProgress(tester), 1);

    await tester.pumpWidget(build());
    expect(_ribbonProgress(tester), 1);
    expect(_chineseReveal(tester), 1);
    expect(_englishReveal(tester), 1);
  });

  testWidgets('重新进入启动页时会再次播放品牌动效', (tester) async {
    Widget build(Key key) => Application(
      home: Center(
        child: MeetTraceAnimatedWordmark(key: key, disableAnimations: false),
      ),
    );

    await tester.pumpWidget(build(const ValueKey('first-startup')));
    await tester.pump();
    await tester.pump(meetTraceBrandMotionDuration);
    expect(_ribbonProgress(tester), 1);
    expect(_chineseReveal(tester), 1);

    await tester.pumpWidget(const Application(home: SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(build(const ValueKey('second-startup')));

    expect(_ribbonProgress(tester), 0);
    expect(_chineseReveal(tester), 0);
    expect(_englishReveal(tester), 0);
    await tester.pump();
    await tester.pump(meetTraceBrandMotionDuration);
    expect(_ribbonProgress(tester), 1);
    expect(_chineseReveal(tester), 1);
    expect(_englishReveal(tester), 1);
  });
}

double _ribbonProgress(WidgetTester tester) => tester
    .widget<MeetTraceRibbonRevealMark>(find.byType(MeetTraceRibbonRevealMark))
    .progress;

Positioned _markStage(WidgetTester tester) => tester.widget<Positioned>(
  find.byKey(const ValueKey('meettrace-startup-brand-mark-stage')),
);

double _chineseReveal(WidgetTester tester) => tester
    .widget<Align>(
      find.byKey(const ValueKey('meettrace-wordmark-chinese-reveal')),
    )
    .widthFactor!;

double _englishReveal(WidgetTester tester) => tester
    .widget<Align>(
      find.byKey(const ValueKey('meettrace-wordmark-english-reveal')),
    )
    .widthFactor!;
