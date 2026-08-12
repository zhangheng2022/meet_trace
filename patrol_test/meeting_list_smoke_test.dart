import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/features/meetings/views/list/meeting_list_view.dart';

import 'common/test_app.dart';

void main() {
  testApp(
    '会迹首页在 Android 真机可见',
    ($, modules, system, apiClients) async {
      await modules.meetings.expectHomeVisible();
    },
    app: const Application(home: MeetingListView()),
    tags: const ['android', 'smoke'],
  );
}
