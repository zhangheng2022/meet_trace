import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/core/branding/meettrace_brand_mark.dart';

void main() {
  testWidgets('品牌标志按矢量路径完整渲染', (tester) async {
    await tester.pumpWidget(
      const Application(home: Center(child: MeetTraceBrandMark())),
    );

    final mark = tester.widget<MeetTraceBrandMark>(
      find.byType(MeetTraceBrandMark),
    );
    expect(mark.progress, 1);
    expect(
      tester.getSize(find.byKey(const ValueKey('meettrace-brand-mark'))),
      const Size.square(52),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('品牌动效从轨迹描画过渡到完整字标', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const Application(
        home: Center(
          child: MeetTraceAnimatedWordmark(
            disableAnimations: false,
            playOncePerProcess: false,
          ),
        ),
      ),
    );

    expect(_markProgress(tester), closeTo(0.03, 0.001));
    expect(_copyOpacity(tester), 0);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('meettrace-startup-wordmark')),
          )
          .label,
      '会迹，MeetTrace',
    );

    await tester.pump(const Duration(milliseconds: 340));
    expect(_markProgress(tester), inExclusiveRange(0.03, 1));
    expect(_copyOpacity(tester), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 340));
    expect(_markProgress(tester), 1);
    expect(_copyOpacity(tester), 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('减少动态效果时直接显示最终品牌状态', (tester) async {
    await tester.pumpWidget(
      const Application(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(
            child: MeetTraceAnimatedWordmark(playOncePerProcess: false),
          ),
        ),
      ),
    );

    expect(_markProgress(tester), 1);
    expect(_copyOpacity(tester), 1);
    await tester.pump(meetTraceBrandMotionDuration);
    expect(_markProgress(tester), 1);
    expect(_copyOpacity(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('父组件重建不会重新播放品牌动效', (tester) async {
    const wordmarkKey = ValueKey('persistent-brand-motion');
    Widget build() => const Application(
      home: Center(
        child: MeetTraceAnimatedWordmark(
          key: wordmarkKey,
          disableAnimations: false,
          playOncePerProcess: false,
        ),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump(meetTraceBrandMotionDuration);
    expect(_markProgress(tester), 1);

    await tester.pumpWidget(build());
    expect(_markProgress(tester), 1);
    expect(_copyOpacity(tester), 1);
  });
}

double _markProgress(WidgetTester tester) =>
    tester.widget<MeetTraceBrandMark>(find.byType(MeetTraceBrandMark)).progress;

double _copyOpacity(WidgetTester tester) => tester
    .widget<Opacity>(find.byKey(const ValueKey('meettrace-wordmark-copy')))
    .opacity;
