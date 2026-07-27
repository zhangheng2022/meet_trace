import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/features/meetings/views/meeting_list_view.dart';

void main() {
  testWidgets('使用真实主题显示会议列表首页', (WidgetTester tester) async {
    await tester.pumpWidget(const Application());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, '会迹');
    expect(find.byType(FTheme), findsOneWidget);
    expect(find.byType(MeetingListView), findsOneWidget);
    expect(find.text('会迹'), findsOneWidget);
    expect(find.byType(FButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
