import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/app_update.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/ports/app_update.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/use_cases/manage_app_update.dart';
import 'package:meettrace/ui/features/meetings/views/list/meeting_list_view.dart';
import 'package:meettrace/ui/features/updates/view_models/app_update_view_model.dart';

void main() {
  testWidgets('提高数据代时明确警告清除范围并在确认后交给系统', (tester) async {
    final meetings = _Meetings();
    final updates = _Updates();
    final viewModel = AppUpdateViewModel(
      meetings: meetings,
      installedVersions: const _Installed(),
      checkForUpdate: CheckForAppUpdateUseCase(updates: updates),
      installUpdate: InstallAppUpdateUseCase(updates: updates),
    );
    addTearDown(() async {
      viewModel.dispose();
      await meetings.dispose();
    });
    await tester.pumpWidget(
      Application(home: MeetingListView(updateViewModel: viewModel)),
    );

    meetings.emit(const <Meeting>[]);
    await tester.pumpAndSettle();

    expect(find.text('更新前必须确认本地数据风险'), findsOneWidget);
    expect(find.textContaining('会议音频、转录、模型和设置'), findsOneWidget);
    expect(find.text('确认风险并继续'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-app-update')));
    await tester.pumpAndSettle();

    expect(updates.installRequests, 1);
    expect(find.text('已交给系统更新'), findsOneWidget);
  });
}

final class _Meetings implements MeetingRepository {
  final _controller = StreamController<List<Meeting>>.broadcast();

  void emit(List<Meeting> value) => _controller.add(value);

  Future<void> dispose() => _controller.close();

  @override
  Stream<List<Meeting>> watchAll() => _controller.stream;

  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<Meeting?> getById(String meetingId) async => null;

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Future<Meeting> updateTitle({
    required String meetingId,
    required String title,
  }) => throw UnimplementedError();
}

final class _Installed implements InstalledAppVersionPort {
  const _Installed();

  @override
  Future<InstalledAppVersion> read() async => InstalledAppVersion(
    versionName: '1.0.0',
    buildNumber: 1,
    dataGeneration: 3,
  );
}

final class _Updates implements AppUpdatePort {
  int installRequests = 0;

  final candidate = AppUpdateCandidate(
    releaseId: 'v1.1.0-alpha.1',
    versionName: '1.1.0',
    buildNumber: 2,
    dataGeneration: 4,
    status: AppUpdateCandidateStatus.publicApproved,
    sourceCommitSha: '0123456789abcdef0123456789abcdef01234567',
    artifactId: 'android-2',
    approvedAt: DateTime.utc(2026, 8, 20),
  );

  @override
  Future<AppUpdateCandidate?> fetchLatestCandidate() async => candidate;

  @override
  Future<void> requestInstall(AppUpdateCandidate candidate) async {
    installRequests += 1;
  }

  @override
  Future<void> stage(AppUpdateCandidate candidate) async {}
}
