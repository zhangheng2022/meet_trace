import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/ui/core/app_back_icon.dart';

void main() {
  testWidgets('返回图形随 Android 与 iOS 平台惯例变化', (tester) async {
    const androidKey = Key('android-back');
    const iosKey = Key('ios-back');
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Theme(
              data: ThemeData(platform: TargetPlatform.android),
              child: const AppBackIcon(
                key: androidKey,
                semanticsLabel: 'Android 返回',
              ),
            ),
            Theme(
              data: ThemeData(platform: TargetPlatform.iOS),
              child: const AppBackIcon(key: iosKey, semanticsLabel: 'iOS 返回'),
            ),
          ],
        ),
      ),
    );

    IconData? iconFor(Key key) => tester
        .widget<Icon>(
          find.descendant(of: find.byKey(key), matching: find.byType(Icon)),
        )
        .icon;

    final androidIcon = iconFor(androidKey);
    final iosIcon = iconFor(iosKey);

    expect(androidIcon, isNotNull);
    expect(iosIcon, isNotNull);
    expect(iosIcon, isNot(androidIcon));
    expect(find.bySemanticsLabel('Android 返回'), findsOneWidget);
    expect(find.bySemanticsLabel('iOS 返回'), findsOneWidget);
  });
}
