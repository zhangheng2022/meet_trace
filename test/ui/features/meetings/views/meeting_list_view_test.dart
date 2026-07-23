import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meetily_ai/app/application.dart';
import 'package:meetily_ai/ui/features/meetings/views/meeting_list_view.dart';

void main() {
  testWidgets('空会议列表使用 Forui 并触发开始会议操作', (WidgetTester tester) async {
    var startMeetingRequested = false;

    await tester.pumpWidget(
      Application(
        home: MeetingListView(
          onStartMeeting: () => startMeetingRequested = true,
        ),
      ),
    );

    expect(find.byType(FScaffold), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is FHeader),
      findsOneWidget,
    );
    expect(find.text('还没有会议'), findsOneWidget);
    expect(find.text('开始会议'), findsOneWidget);

    await tester.tap(find.text('开始会议'));
    await tester.pumpAndSettle();

    expect(startMeetingRequested, isTrue);
  });
}
