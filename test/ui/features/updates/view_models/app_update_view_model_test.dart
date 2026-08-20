import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/app_update.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/app_update.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/use_cases/manage_app_update.dart';
import 'package:meettrace/ui/features/updates/view_models/app_update_view_model.dart';

void main() {
  test('录音和最终处理期间 deferred，回到空闲后自动续检并暂存', () async {
    final meetings = _MeetingRepository();
    final updates = _AppUpdatePort();
    final viewModel = AppUpdateViewModel(
      meetings: meetings,
      installedVersions: const _InstalledVersions(),
      checkForUpdate: CheckForAppUpdateUseCase(updates: updates),
      installUpdate: InstallAppUpdateUseCase(updates: updates),
    );
    addTearDown(() async {
      viewModel.dispose();
      await meetings.dispose();
    });

    viewModel.start();
    meetings.emit(<Meeting>[_meeting(MeetingState.recording)]);
    await _settle();
    expect(viewModel.decision.kind, AppUpdateDecisionKind.deferred);
    expect(updates.stageCount, 0);

    meetings.emit(<Meeting>[_meeting(MeetingState.processing)]);
    await _settle();
    expect(updates.stageCount, 0);

    meetings.emit(<Meeting>[_meeting(MeetingState.completed)]);
    await _settle();
    expect(viewModel.decision.kind, AppUpdateDecisionKind.readyToInstall);
    expect(updates.stageCount, 1);
  });

  test('安装交接失败收敛为状态且不抛给 UI', () async {
    final meetings = _MeetingRepository();
    final updates = _AppUpdatePort()..installError = StateError('system');
    final viewModel = AppUpdateViewModel(
      meetings: meetings,
      installedVersions: const _InstalledVersions(),
      checkForUpdate: CheckForAppUpdateUseCase(updates: updates),
      installUpdate: InstallAppUpdateUseCase(updates: updates),
    );
    addTearDown(() async {
      viewModel.dispose();
      await meetings.dispose();
    });
    viewModel.start();
    meetings.emit(<Meeting>[_meeting(MeetingState.completed)]);
    await _settle();

    final decision = await viewModel.install(dataResetAcknowledged: false);

    expect(decision.kind, AppUpdateDecisionKind.installHandoffFailed);
  });

  test('检查期间从处理转为空闲时使用最新状态继续暂存', () async {
    final meetings = _MeetingRepository();
    final updates = _AppUpdatePort()
      ..fetchGate = Completer<AppUpdateCandidate?>();
    final viewModel = AppUpdateViewModel(
      meetings: meetings,
      installedVersions: const _InstalledVersions(),
      checkForUpdate: CheckForAppUpdateUseCase(updates: updates),
      installUpdate: InstallAppUpdateUseCase(updates: updates),
    );
    addTearDown(() async {
      viewModel.dispose();
      await meetings.dispose();
    });
    viewModel.start();
    meetings.emit(<Meeting>[_meeting(MeetingState.processing)]);
    await _settle();
    meetings.emit(<Meeting>[_meeting(MeetingState.completed)]);
    updates.fetchGate!.complete(updates.candidate);
    updates.fetchGate = null;
    await _settle();

    expect(viewModel.decision.kind, AppUpdateDecisionKind.readyToInstall);
    expect(updates.fetchCount, 1);
    expect(updates.stageCount, 1);
  });

  test('空闲检查期间开始录音时最终状态强制回到 deferred', () async {
    final meetings = _MeetingRepository();
    final updates = _AppUpdatePort()
      ..fetchGate = Completer<AppUpdateCandidate?>();
    final viewModel = AppUpdateViewModel(
      meetings: meetings,
      installedVersions: const _InstalledVersions(),
      checkForUpdate: CheckForAppUpdateUseCase(updates: updates),
      installUpdate: InstallAppUpdateUseCase(updates: updates),
    );
    addTearDown(() async {
      viewModel.dispose();
      await meetings.dispose();
    });
    viewModel.start();
    meetings.emit(<Meeting>[_meeting(MeetingState.completed)]);
    await _settle();
    meetings.emit(<Meeting>[_meeting(MeetingState.recording)]);
    updates.fetchGate!.complete(updates.candidate);
    updates.fetchGate = null;
    await _settle();

    expect(viewModel.decision.kind, AppUpdateDecisionKind.deferred);
    expect(updates.stageCount, 0);
  });
}

Future<void> _settle() async {
  for (var index = 0; index < 4; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Meeting _meeting(MeetingState state) => Meeting(
  id: 'meeting-1',
  title: '会议',
  createdAt: DateTime.utc(2026, 8, 20),
  status: state,
  audioDurationMs: 1,
  recordingModelId: 'sensevoice',
  recordingModelVersion: '1',
);

final class _MeetingRepository implements MeetingRepository {
  final _controller = StreamController<List<Meeting>>.broadcast();

  void emit(List<Meeting> meetings) => _controller.add(meetings);

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

final class _InstalledVersions implements InstalledAppVersionPort {
  const _InstalledVersions();

  @override
  Future<InstalledAppVersion> read() async => InstalledAppVersion(
    versionName: '1.0.0',
    buildNumber: 1,
    dataGeneration: 3,
  );
}

final class _AppUpdatePort implements AppUpdatePort {
  int stageCount = 0;
  int fetchCount = 0;
  Object? installError;
  Completer<AppUpdateCandidate?>? fetchGate;

  final candidate = AppUpdateCandidate(
    releaseId: 'v1.1.0-alpha.1',
    versionName: '1.1.0',
    buildNumber: 2,
    dataGeneration: 3,
    status: AppUpdateCandidateStatus.publicApproved,
    sourceCommitSha: '0123456789abcdef0123456789abcdef01234567',
    artifactId: 'android-2',
    approvedAt: DateTime.utc(2026, 8, 20),
  );

  @override
  Future<AppUpdateCandidate?> fetchLatestCandidate() async {
    fetchCount += 1;
    return fetchGate?.future ?? candidate;
  }

  @override
  Future<void> requestInstall(AppUpdateCandidate candidate) async {
    if (installError case final Object error) throw error;
  }

  @override
  Future<void> stage(AppUpdateCandidate candidate) async {
    stageCount += 1;
  }
}
