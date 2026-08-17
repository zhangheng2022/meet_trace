import '../models/app_update.dart';
import '../ports/app_update.dart';

final class CheckForAppUpdateUseCase {
  const CheckForAppUpdateUseCase({required this.updates});

  final AppUpdatePort updates;

  /// 检查并在安全空闲期自动下载候选；所有外部失败都收敛为状态而不阻断应用。
  Future<AppUpdateDecision> execute({
    required InstalledAppVersion installed,
    required AppUpdateWorkload workload,
  }) async {
    AppUpdateCandidate? candidate;
    try {
      candidate = await updates.fetchLatestCandidate();
    } on Object {
      return const AppUpdateDecision(kind: AppUpdateDecisionKind.checkFailed);
    }
    if (candidate == null ||
        candidate.status != AppUpdateCandidateStatus.publicApproved ||
        !candidate.isNewerThan(installed)) {
      return const AppUpdateDecision(kind: AppUpdateDecisionKind.noUpdate);
    }
    if (workload != AppUpdateWorkload.idle) {
      return AppUpdateDecision(
        kind: AppUpdateDecisionKind.deferred,
        candidate: candidate,
      );
    }
    try {
      await updates.stage(candidate);
    } on Object {
      return AppUpdateDecision(
        kind: AppUpdateDecisionKind.downloadFailed,
        candidate: candidate,
      );
    }
    return AppUpdateDecision(
      kind: candidate.dataGeneration > installed.dataGeneration
          ? AppUpdateDecisionKind.dataResetWarningRequired
          : AppUpdateDecisionKind.readyToInstall,
      candidate: candidate,
    );
  }
}

final class InstallAppUpdateUseCase {
  const InstallAppUpdateUseCase({required this.updates});

  final AppUpdatePort updates;

  Future<AppUpdateDecision> execute({
    required AppUpdateCandidate candidate,
    required InstalledAppVersion installed,
    required AppUpdateWorkload workload,
    required bool dataResetAcknowledged,
  }) async {
    if (candidate.status != AppUpdateCandidateStatus.publicApproved ||
        !candidate.isNewerThan(installed)) {
      return const AppUpdateDecision(kind: AppUpdateDecisionKind.noUpdate);
    }
    if (workload != AppUpdateWorkload.idle) {
      return AppUpdateDecision(
        kind: AppUpdateDecisionKind.deferred,
        candidate: candidate,
      );
    }
    if (candidate.dataGeneration > installed.dataGeneration &&
        !dataResetAcknowledged) {
      return AppUpdateDecision(
        kind: AppUpdateDecisionKind.dataResetWarningRequired,
        candidate: candidate,
      );
    }
    try {
      await updates.requestInstall(candidate);
      return AppUpdateDecision(
        kind: AppUpdateDecisionKind.installHandedOff,
        candidate: candidate,
      );
    } on Object {
      return AppUpdateDecision(
        kind: AppUpdateDecisionKind.installHandoffFailed,
        candidate: candidate,
      );
    }
  }
}
