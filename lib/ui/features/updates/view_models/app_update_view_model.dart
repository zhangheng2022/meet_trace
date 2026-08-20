import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../domain/models/app_update.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../domain/ports/app_update.dart';
import '../../../../domain/ports/repositories.dart';
import '../../../../domain/use_cases/manage_app_update.dart';

final class AppUpdateViewModel extends ChangeNotifier {
  AppUpdateViewModel({
    required this.meetings,
    required this.installedVersions,
    required this.checkForUpdate,
    required this.installUpdate,
  });

  final MeetingRepository meetings;
  final InstalledAppVersionPort installedVersions;
  final CheckForAppUpdateUseCase checkForUpdate;
  final InstallAppUpdateUseCase installUpdate;

  AppUpdateDecision _decision = const AppUpdateDecision(
    kind: AppUpdateDecisionKind.noUpdate,
  );
  AppUpdateWorkload? _workload;
  StreamSubscription<List<Meeting>>? _meetingsSubscription;
  Future<AppUpdateDecision>? _operation;
  bool _recheckAfterOperation = false;
  bool _disposed = false;

  AppUpdateDecision get decision => _decision;
  bool get busy => _operation != null;

  void start() {
    if (_meetingsSubscription != null) {
      return;
    }
    _meetingsSubscription = meetings.watchAll().listen(
      (items) {
        final previous = _workload;
        _workload = _workloadFor(items);
        if (previous == null ||
            (previous != AppUpdateWorkload.idle &&
                _workload == AppUpdateWorkload.idle)) {
          if (_operation == null) {
            unawaited(check());
          } else {
            _recheckAfterOperation = true;
          }
        }
      },
      onError: (Object _) {
        _workload = AppUpdateWorkload.finalProcessing;
      },
    );
  }

  Future<AppUpdateDecision> check() {
    final active = _operation;
    if (active != null) {
      return active;
    }
    final workload = _workload;
    if (workload == null) {
      return Future.value(_decision);
    }
    late final Future<AppUpdateDecision> operation;
    operation = _performCheck(workload).whenComplete(() {
      if (identical(_operation, operation)) {
        _operation = null;
        final shouldRecheck = _recheckAfterOperation;
        _recheckAfterOperation = false;
        _notify();
        if (shouldRecheck && !_disposed) {
          unawaited(Future<void>.microtask(check));
        }
      }
    });
    _operation = operation;
    _notify();
    return operation;
  }

  Future<AppUpdateDecision> install({required bool dataResetAcknowledged}) {
    final active = _operation;
    if (active != null) {
      return active;
    }
    final candidate = _decision.candidate;
    final workload = _workload;
    if (candidate == null || workload == null) {
      return Future.value(_decision);
    }
    late final Future<AppUpdateDecision> operation;
    operation =
        _performInstall(
          candidate: candidate,
          workload: workload,
          dataResetAcknowledged: dataResetAcknowledged,
        ).whenComplete(() {
          if (identical(_operation, operation)) {
            _operation = null;
            _notify();
          }
        });
    _operation = operation;
    _notify();
    return operation;
  }

  Future<AppUpdateDecision> _performCheck(AppUpdateWorkload workload) async {
    AppUpdateDecision decision;
    try {
      decision = await checkForUpdate.execute(
        installed: await installedVersions.read(),
        workload: workload,
        currentWorkload: () => _workload ?? AppUpdateWorkload.finalProcessing,
      );
    } on Object {
      decision = const AppUpdateDecision(
        kind: AppUpdateDecisionKind.checkFailed,
      );
    }
    final currentWorkload = _workload;
    if (currentWorkload != null && currentWorkload != workload) {
      final candidate = decision.candidate;
      if (currentWorkload != AppUpdateWorkload.idle && candidate != null) {
        decision = AppUpdateDecision(
          kind: AppUpdateDecisionKind.deferred,
          candidate: candidate,
        );
      } else if (currentWorkload == AppUpdateWorkload.idle &&
          (decision.kind == AppUpdateDecisionKind.deferred ||
              decision.kind == AppUpdateDecisionKind.checkFailed ||
              decision.kind == AppUpdateDecisionKind.downloadFailed)) {
        _recheckAfterOperation = true;
      } else if (currentWorkload == AppUpdateWorkload.idle) {
        _recheckAfterOperation = false;
      }
    }
    _setDecision(decision);
    return decision;
  }

  Future<AppUpdateDecision> _performInstall({
    required AppUpdateCandidate candidate,
    required AppUpdateWorkload workload,
    required bool dataResetAcknowledged,
  }) async {
    AppUpdateDecision decision;
    try {
      decision = await installUpdate.execute(
        candidate: candidate,
        installed: await installedVersions.read(),
        workload: workload,
        dataResetAcknowledged: dataResetAcknowledged,
      );
    } on Object {
      decision = AppUpdateDecision(
        kind: AppUpdateDecisionKind.installHandoffFailed,
        candidate: candidate,
      );
    }
    _setDecision(decision);
    return decision;
  }

  void _setDecision(AppUpdateDecision decision) {
    _decision = decision;
    _notify();
  }

  AppUpdateWorkload _workloadFor(List<Meeting> items) {
    var processing = false;
    for (final item in items) {
      final status = item.status;
      if (status == MeetingState.recording) {
        return AppUpdateWorkload.recording;
      }
      processing = processing || status == MeetingState.processing;
    }
    return processing
        ? AppUpdateWorkload.finalProcessing
        : AppUpdateWorkload.idle;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_meetingsSubscription?.cancel());
    super.dispose();
  }
}
