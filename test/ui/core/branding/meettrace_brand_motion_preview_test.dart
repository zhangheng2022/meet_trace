import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/ui/core/branding/meettrace_brand_mark.dart';
import 'package:meettrace/ui/core/branding/previews/meettrace_brand_motion_previews.dart';

void main() {
  testWidgets('动效实验台可拖动时间轴并切换节奏', (tester) async {
    await tester.pumpWidget(const MeetTraceBrandMotionLab(autoplay: false));

    expect(find.text('0 / 960 ms'), findsOneWidget);
    expect(
      tester
          .widget<MeetTraceRibbonRevealMark>(
            find.byType(MeetTraceRibbonRevealMark),
          )
          .progress,
      0,
    );

    await tester.drag(
      find.byKey(const ValueKey('brand-motion-progress-slider')),
      const Offset(120, 0),
    );
    await tester.pump();
    expect(
      tester
          .widget<MeetTraceRibbonRevealMark>(
            find.byType(MeetTraceRibbonRevealMark),
          )
          .progress,
      greaterThan(0),
    );

    await tester.tap(find.byKey(const ValueKey('brand-motion-duration-960')));
    await tester.pump();
    expect(find.textContaining('/ 960 ms'), findsOneWidget);
    expect(find.text('写入 0–640'), findsOneWidget);
    expect(find.text('归位 571–892'), findsOneWidget);
    expect(find.text('字标 743–960'), findsOneWidget);
  });

  testWidgets('动效实验台可在明暗主题间检查墨色对比', (tester) async {
    await tester.pumpWidget(const MeetTraceBrandMotionLab(autoplay: false));

    BuildContext markContext() =>
        tester.element(find.byType(MeetTraceRibbonRevealMark));
    expect(Theme.of(markContext()).brightness, Brightness.light);

    await tester.tap(find.byKey(const ValueKey('brand-motion-theme-switch')));
    await tester.pumpAndSettle();
    expect(Theme.of(markContext()).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
