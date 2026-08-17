import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/app_update.dart';
import 'package:meettrace/domain/ports/app_update.dart';
import 'package:meettrace/domain/use_cases/manage_app_update.dart';

void main() {
  final installed = InstalledAppVersion(
    versionName: '1.0.0',
    buildNumber: 10,
    dataGeneration: 3,
  );

  test('公开批准的更高构建在空闲期自动下载并可交给平台安装', () async {
    final port = _AppUpdatePort()..candidate = _candidate();
    final checked = await CheckForAppUpdateUseCase(updates: port)
        .execute(installed: installed, workload: AppUpdateWorkload.idle);

    expect(checked.kind, AppUpdateDecisionKind.readyToInstall);
    expect(port.staged, ['artifact-11']);

    final installedDecision = await InstallAppUpdateUseCase(updates: port)
        .execute(
          candidate: checked.candidate!,
          installed: installed,
          workload: AppUpdateWorkload.idle,
          dataResetAcknowledged: false,
        );
    expect(installedDecision.kind, AppUpdateDecisionKind.installHandedOff);
    expect(port.installRequests, ['artifact-11']);
  });

  test('录音与最终处理期间只返回 deferred 且不下载或安装', () async {
    for (final workload in [
      AppUpdateWorkload.recording,
      AppUpdateWorkload.finalProcessing,
    ]) {
      final port = _AppUpdatePort()..candidate = _candidate();
      final checked = await CheckForAppUpdateUseCase(updates: port)
          .execute(installed: installed, workload: workload);
      final installDecision = await InstallAppUpdateUseCase(updates: port)
          .execute(
            candidate: port.candidate!,
            installed: installed,
            workload: workload,
            dataResetAcknowledged: true,
          );

      expect(checked.kind, AppUpdateDecisionKind.deferred);
      expect(installDecision.kind, AppUpdateDecisionKind.deferred);
      expect(port.staged, isEmpty);
      expect(port.installRequests, isEmpty);
    }
  });

  test('撤回、相同或更低构建均不可被发现或安装', () async {
    for (final candidate in [
      _candidate(status: AppUpdateCandidateStatus.withdrawn),
      _candidate(buildNumber: 10),
      _candidate(buildNumber: 9),
      _candidate(versionName: '0.9.9', buildNumber: 12),
    ]) {
      final port = _AppUpdatePort()..candidate = candidate;
      final checked = await CheckForAppUpdateUseCase(updates: port)
          .execute(installed: installed, workload: AppUpdateWorkload.idle);
      final installDecision = await InstallAppUpdateUseCase(updates: port)
          .execute(
            candidate: candidate,
            installed: installed,
            workload: AppUpdateWorkload.idle,
            dataResetAcknowledged: true,
          );

      expect(checked.kind, AppUpdateDecisionKind.noUpdate);
      expect(installDecision.kind, AppUpdateDecisionKind.noUpdate);
      expect(port.staged, isEmpty);
      expect(port.installRequests, isEmpty);
    }
  });

  test('更高构建号也不能把正式版本降到预发布或更低语义版本', () async {
    final currentRelease = InstalledAppVersion(
      versionName: '1.1.0',
      buildNumber: 10,
      dataGeneration: 3,
    );
    for (final versionName in ['1.1.0-alpha.9', '1.0.9']) {
      final port = _AppUpdatePort()
        ..candidate = _candidate(versionName: versionName, buildNumber: 12);
      final decision = await CheckForAppUpdateUseCase(updates: port)
          .execute(installed: currentRelease, workload: AppUpdateWorkload.idle);

      expect(decision.kind, AppUpdateDecisionKind.noUpdate);
      expect(port.staged, isEmpty);
    }
  });

  test('提高数据代的候选下载后必须先取得明确清理确认', () async {
    final port = _AppUpdatePort()..candidate = _candidate(dataGeneration: 4);
    final checked = await CheckForAppUpdateUseCase(updates: port)
        .execute(installed: installed, workload: AppUpdateWorkload.idle);

    expect(checked.kind, AppUpdateDecisionKind.dataResetWarningRequired);
    expect(port.staged, ['artifact-11']);

    final blocked = await InstallAppUpdateUseCase(updates: port).execute(
      candidate: checked.candidate!,
      installed: installed,
      workload: AppUpdateWorkload.idle,
      dataResetAcknowledged: false,
    );
    expect(blocked.kind, AppUpdateDecisionKind.dataResetWarningRequired);
    expect(port.installRequests, isEmpty);

    final accepted = await InstallAppUpdateUseCase(updates: port).execute(
      candidate: checked.candidate!,
      installed: installed,
      workload: AppUpdateWorkload.idle,
      dataResetAcknowledged: true,
    );
    expect(accepted.kind, AppUpdateDecisionKind.installHandedOff);
  });

  test('检查、下载和平台安装异常分别收敛为非阻断状态', () async {
    final checkFailure = _AppUpdatePort()..fetchError = StateError('offline');
    expect(
      (await CheckForAppUpdateUseCase(
        updates: checkFailure,
      ).execute(installed: installed, workload: AppUpdateWorkload.idle)).kind,
      AppUpdateDecisionKind.checkFailed,
    );

    final downloadFailure = _AppUpdatePort()
      ..candidate = _candidate()
      ..stageError = StateError('hash mismatch');
    expect(
      (await CheckForAppUpdateUseCase(
        updates: downloadFailure,
      ).execute(installed: installed, workload: AppUpdateWorkload.idle)).kind,
      AppUpdateDecisionKind.downloadFailed,
    );

    final installFailure = _AppUpdatePort()
      ..candidate = _candidate()
      ..installError = StateError('installer unavailable');
    expect(
      (await InstallAppUpdateUseCase(updates: installFailure).execute(
        candidate: installFailure.candidate!,
        installed: installed,
        workload: AppUpdateWorkload.idle,
        dataResetAcknowledged: false,
      )).kind,
      AppUpdateDecisionKind.installHandoffFailed,
    );
  });
}

AppUpdateCandidate _candidate({
  String versionName = '1.1.0',
  int buildNumber = 11,
  int dataGeneration = 3,
  AppUpdateCandidateStatus status = AppUpdateCandidateStatus.publicApproved,
}) => AppUpdateCandidate(
  releaseId: 'v1.1.0-alpha.1',
  versionName: versionName,
  buildNumber: buildNumber,
  dataGeneration: dataGeneration,
  status: status,
  sourceCommitSha: '0123456789abcdef0123456789abcdef01234567',
  artifactId: 'artifact-11',
  approvedAt: DateTime.utc(2026, 8, 15),
);

final class _AppUpdatePort implements AppUpdatePort {
  AppUpdateCandidate? candidate;
  Object? fetchError;
  Object? stageError;
  Object? installError;
  final List<String> staged = [];
  final List<String> installRequests = [];

  @override
  Future<AppUpdateCandidate?> fetchLatestCandidate() async {
    if (fetchError case final Object error) {
      throw error;
    }
    return candidate;
  }

  @override
  Future<void> stage(AppUpdateCandidate candidate) async {
    if (stageError case final Object error) {
      throw error;
    }
    staged.add(candidate.artifactId);
  }

  @override
  Future<void> requestInstall(AppUpdateCandidate candidate) async {
    if (installError case final Object error) {
      throw error;
    }
    installRequests.add(candidate.artifactId);
  }
}
