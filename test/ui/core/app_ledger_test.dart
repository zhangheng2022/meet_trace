import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/core/app_ledger.dart';

void main() {
  testWidgets('时间记录条显示事实层级并响应整行点击', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      Application(
        home: AppLedgerSurface(
          children: [
            AppLedgerRow(
              dateLabel: '07-27',
              timeLabel: '09:30',
              title: '产品评审会',
              metaLabel: '时长 01:12:48',
              statusLabel: '事实音频已保存',
              statusIcon: FLucideIcons.circleCheck,
              emphasized: true,
              showDivider: false,
              semanticsLabel: '打开产品评审会',
              onPress: () => tapped = true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('07-27'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('产品评审会'), findsOneWidget);
    expect(find.text('事实音频已保存'), findsOneWidget);
    expect(find.bySemanticsLabel('打开产品评审会'), findsOneWidget);

    await tester.tap(find.byType(AppLedgerRow));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
