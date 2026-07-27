import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/core/app_responsive.dart';

void main() {
  for (final testCase in <(double, AppWindowSizeClass)>[
    (320, AppWindowSizeClass.compact),
    (599, AppWindowSizeClass.compact),
    (600, AppWindowSizeClass.medium),
    (839, AppWindowSizeClass.medium),
    (840, AppWindowSizeClass.expanded),
    (1024, AppWindowSizeClass.expanded),
  ]) {
    testWidgets('${testCase.$1.toInt()} 宽度使用 ${testCase.$2.name} 布局', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(testCase.$1, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        Application(
          home: AppResponsiveBuilder(
            builder: (_, sizeClass, constraints) =>
                Text('${sizeClass.name}:${constraints.maxWidth.toInt()}'),
          ),
        ),
      );

      expect(
        find.text('${testCase.$2.name}:${testCase.$1.toInt()}'),
        findsOneWidget,
      );
    });
  }
}
