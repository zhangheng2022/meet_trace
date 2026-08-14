import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/models/meeting_readiness.dart';
import '../../../../../domain/models/workflow_states.dart';
import '../../../../../domain/ports/repositories.dart';
import '../../../../../domain/use_cases/check_meeting_readiness.dart';
import '../../../../../domain/use_cases/delete_meeting.dart';
import '../../../../../domain/use_cases/rename_meeting.dart';
import '../../../../core/view_state.dart';

enum MeetingReadinessStatus {
  unchecked,
  checking,
  ready,
  microphonePermissionRequired,
  storageInsufficient,
  defaultModelUnavailable,
  failed,
}

final class MeetingReadinessViewState {
  const MeetingReadinessViewState({
    required this.status,
    this.defaultModelName,
    this.issueCount = 0,
    this.microphonePermissionGranted,
    this.freeBytes,
    this.defaultModelAvailable,
  });

  const MeetingReadinessViewState.unchecked()
    : this(status: MeetingReadinessStatus.unchecked);

  const MeetingReadinessViewState.checking()
    : this(status: MeetingReadinessStatus.checking);

  final MeetingReadinessStatus status;
  final String? defaultModelName;
  final int issueCount;
  final bool? microphonePermissionGranted;
  final int? freeBytes;
  final bool? defaultModelAvailable;
}

final class MeetingListViewModel extends ChangeNotifier {
  MeetingListViewModel({
    required this.meetings,
    required this.readinessChecker,
    required this.deletion,
    RenameMeetingUseCase? renaming,
  }) : renaming = renaming ?? RenameMeetingUseCase(meetings: meetings);

  final MeetingRepository meetings;
  final MeetingReadinessChecker readinessChecker;
  final DeleteMeetingUseCase deletion;
  final RenameMeetingUseCase renaming;

  ViewState<List<Meeting>> _state = const ViewLoading();
  MeetingReadinessViewState _readiness =
      const MeetingReadinessViewState.checking();
  StreamSubscription<List<Meeting>>? _subscription;
  Future<void>? _readinessOperation;
  final Set<String> _deletingMeetingIds = {};
  final Set<String> _renamingMeetingIds = {};
  String? _deleteErrorMessage;
  String? _renameErrorMessage;
  bool _disposed = false;

  ViewState<List<Meeting>> get state => _state;
  MeetingReadinessViewState get readiness => _readiness;
  Set<String> get deletingMeetingIds => Set.unmodifiable(_deletingMeetingIds);
  String? get deleteErrorMessage => _deleteErrorMessage;
  Set<String> get renamingMeetingIds => Set.unmodifiable(_renamingMeetingIds);
  String? get renameErrorMessage => _renameErrorMessage;

  bool isDeletingMeeting(String meetingId) =>
      _deletingMeetingIds.contains(meetingId);

  bool isRenamingMeeting(String meetingId) =>
      _renamingMeetingIds.contains(meetingId);

  bool canRenameMeeting(Meeting meeting) =>
      !isDeletingMeeting(meeting.id) && !isRenamingMeeting(meeting.id);

  bool canDeleteMeeting(Meeting meeting) =>
      !isDeletingMeeting(meeting.id) &&
      !isRenamingMeeting(meeting.id) &&
      switch (meeting.status) {
        MeetingState.created ||
        MeetingState.completed ||
        MeetingState.failed => true,
        MeetingState.recording || MeetingState.processing => false,
      };

  void load() {
    if (_subscription != null) {
      return;
    }
    _state = const ViewLoading();
    notifyListeners();
    unawaited(refreshReadiness());
    _subscription = meetings.watchAll().listen(
      (items) {
        _state = ViewData(value: List.unmodifiable(items));
        _notify();
      },
      onError: (Object error) {
        _state = ViewError(error: error, retry: retry);
        _notify();
      },
    );
  }

  void retry() {
    final previous = _subscription;
    _subscription = null;
    _state = const ViewLoading();
    notifyListeners();
    if (previous == null) {
      load();
      return;
    }
    unawaited(previous.cancel().whenComplete(load));
  }

  Future<void> refreshReadiness() => _refreshReadiness();

  Future<void> requestMicrophonePermission() async {
    final current = _readinessOperation;
    if (current != null) {
      await current;
    }
    if (_disposed) {
      return;
    }
    await _refreshReadiness(requestMicrophonePermission: true);
  }

  Future<void> _refreshReadiness({bool requestMicrophonePermission = false}) {
    final current = _readinessOperation;
    if (current != null) {
      return current;
    }
    _readiness = const MeetingReadinessViewState.checking();
    _notify();
    late final Future<void> operation;
    operation =
        _checkReadiness(
          requestMicrophonePermission: requestMicrophonePermission,
        ).whenComplete(() {
          if (identical(_readinessOperation, operation)) {
            _readinessOperation = null;
          }
        });
    _readinessOperation = operation;
    return operation;
  }

  Future<bool> deleteMeeting(Meeting meeting) async {
    if (!canDeleteMeeting(meeting)) {
      return false;
    }
    _deleteErrorMessage = null;
    _deletingMeetingIds.add(meeting.id);
    _notify();
    try {
      await deletion.execute(meetingId: meeting.id);
      return true;
    } on Object {
      _deleteErrorMessage = '删除失败，会议数据仍保留';
      return false;
    } finally {
      _deletingMeetingIds.remove(meeting.id);
      _notify();
    }
  }

  Future<bool> renameMeeting(Meeting meeting, String title) async {
    if (!canRenameMeeting(meeting)) {
      return false;
    }
    _renameErrorMessage = null;
    _renamingMeetingIds.add(meeting.id);
    _notify();
    try {
      await renaming.execute(meetingId: meeting.id, title: title);
      return true;
    } on Object {
      _renameErrorMessage = '重命名失败，原会议标题仍保留';
      return false;
    } finally {
      _renamingMeetingIds.remove(meeting.id);
      _notify();
    }
  }

  Future<void> _checkReadiness({
    required bool requestMicrophonePermission,
  }) async {
    try {
      final result = await readinessChecker.check(
        requestMicrophonePermission: requestMicrophonePermission,
      );
      _readiness = _readinessState(result);
    } on Object {
      _readiness = const MeetingReadinessViewState(
        status: MeetingReadinessStatus.failed,
      );
    }
    _notify();
  }

  MeetingReadinessViewState _readinessState(MeetingReadiness result) {
    final issues = result.issues;
    final status = switch (issues.firstOrNull) {
      null => MeetingReadinessStatus.ready,
      MeetingReadinessIssue.microphonePermission =>
        MeetingReadinessStatus.microphonePermissionRequired,
      MeetingReadinessIssue.insufficientStorage =>
        MeetingReadinessStatus.storageInsufficient,
      MeetingReadinessIssue.defaultModelUnavailable =>
        MeetingReadinessStatus.defaultModelUnavailable,
    };
    return MeetingReadinessViewState(
      status: status,
      defaultModelName: result.defaultModelName,
      issueCount: issues.length,
      microphonePermissionGranted: result.microphonePermissionGranted,
      freeBytes: result.freeBytes,
      defaultModelAvailable: result.defaultModelAvailable,
    );
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
