import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meetily_ai/app/application.dart';
import 'package:meetily_ai/ui/features/meetings/views/meeting_list_view.dart';

void main() {
  testWidgets('使用真实主题显示会议列表首页', (WidgetTester tester) async {
    await tester.pumpWidget(const Application());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(FTheme), findsOneWidget);
    expect(find.byType(MeetingListView), findsOneWidget);
    expect(find.text('会议'), findsOneWidget);
    expect(tester.widget<FButton>(find.byType(FButton)).onPress, isNull);
    expect(tester.takeException(), isNull);
  });
}
