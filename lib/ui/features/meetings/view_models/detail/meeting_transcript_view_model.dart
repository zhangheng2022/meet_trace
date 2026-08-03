part of 'meeting_detail_view_model.dart';

final class MeetingTranscriptViewModel {
  const MeetingTranscriptViewModel._(this._owner);
  final MeetingDetailViewModel _owner;

  TranscriptSnapshot? get snapshot => _owner.snapshot;
  bool get isTranscribing => _owner.isTranscribing;
  bool get isDiarizing => _owner.isDiarizing;
  bool get canRetry => _owner.canRetry;
  bool get canRetranscribe => _owner.canRetranscribe;

  Future<void> retry() => _owner._retry();
  Future<void> retranscribe() => _owner._retranscribe();
  Future<void> setDiarizationEnabled(bool enabled) =>
      _owner._setDiarizationEnabled(enabled);
  Future<void> retryDiarization() => _owner._retryDiarization();
  Future<void> renameSpeaker(String? currentSpeakerId, String newLabel) =>
      _owner._renameSpeaker(currentSpeakerId, newLabel);
  Future<void> reviseTranscript(List<TranscriptSegmentRevision> revisions) =>
      _owner._reviseTranscript(revisions);
}

extension _MeetingTranscriptOperations on MeetingDetailViewModel {
  Future<void> _retry() {
    final failed = _failedAttempt;
    if (failed == null) {
      return Future.value();
    }
    return _run(retrySnapshotId: _lockedRetrySnapshotId(failed));
  }

  Future<void> _retranscribe() => _run();

  String? _lockedRetrySnapshotId(TranscriptSnapshot snapshot) {
    return snapshot.actualModelId == _meeting.recordingModelId &&
            snapshot.actualModelVersion == _meeting.recordingModelVersion
        ? snapshot.id
        : null;
  }

  Future<void> _setDiarizationEnabled(bool enabled) async {
    final preferences = diarizationPreferences;
    if (preferences == null ||
        (enabled && !diarizationAvailable) ||
        isProcessing) {
      return;
    }
    _diarizationEnabled = enabled;
    _diarizationStatus = SpeakerDiarizationStatus.disabled;
    _diarizationMessage = null;
    _notify();
    await preferences.setEnabled(enabled);
    if (enabled) {
      await _runDiarization();
    }
  }

  Future<void> _retryDiarization() => _runDiarization();

  Future<void> _renameSpeaker(String? currentSpeakerId, String newLabel) async {
    final snapshot = _snapshot;
    if (snapshot == null || isProcessing) {
      return;
    }
    final revision = transcriptRevision;
    if (revision != null) {
      return reviseTranscript([
        for (final segment in snapshot.segments)
          TranscriptSegmentRevision(
            segmentId: segment.id,
            text: segment.text,
            speakerLabel: segment.speakerId == currentSpeakerId
                ? newLabel
                : segment.speakerId,
          ),
      ]);
    }
    final runner = diarization;
    if (runner == null) {
      return;
    }
    try {
      _snapshot = await runner.renameSpeaker(
        meetingId: _meeting.id,
        snapshotId: snapshot.id,
        currentSpeakerId: currentSpeakerId,
        newLabel: newLabel,
      );
      _diarizationMessage = '说话人标签已保存';
    } on Object {
      _diarizationMessage = '说话人标签保存失败，请重试';
    } finally {
      _notify();
    }
  }

  Future<void> _reviseTranscript(List<TranscriptSegmentRevision> revisions) =>
      _runResultOperation(() async {
        final useCase = transcriptRevision;
        if (useCase == null) {
          return;
        }
        final previousSummaryId = _meeting.activeSummaryId;
        final result = await useCase.execute(
          meetingId: _meeting.id,
          revisions: revisions,
        );
        _meeting = result.meeting;
        _snapshot = result.snapshot;
        _summary = previousSummaryId == null
            ? null
            : await summaries?.getById(previousSummaryId);
        _resultMessage = '转录修订已保存为新版本；原 AI 总结已标记为过期';
      }, failureMessage: '转录修订保存失败，请检查内容后重试');

  Future<void> _run({String? retrySnapshotId}) {
    final current = _operation;
    if (current != null) {
      return current;
    }
    final operation = _transcribe(retrySnapshotId: retrySnapshotId);
    _operation = operation;
    _notify();
    return operation.whenComplete(() {
      _operation = null;
      _notify();
      if (_shouldAutoGenerateSummary) {
        unawaited(_runSummaryGeneration());
      }
    });
  }

  Future<void> _transcribe({required String? retrySnapshotId}) async {
    _errorMessage = null;
    _progress = 0;
    _notify();
    try {
      final result = await transcription.transcribe(
        meetingId: _meeting.id,
        retrySnapshotId: retrySnapshotId,
        onProgress: _applyProgress,
      );
      _meeting = result.meeting;
      _snapshot = result.snapshot;
      _failedAttempt = null;
      _processingAttempt = null;
      _progress = 1;
      _summary = null;
      _summaryMessage = null;
      await _runDiarizationIfNeeded();
    } on Object {
      _errorMessage = '最终转录失败，事实音频和旧结果均已保留';
      await _refreshMeeting();
      await _refreshSnapshots();
    } finally {
      _notify();
    }
  }

  Future<void> _runDiarizationIfNeeded() {
    final snapshot = _snapshot;
    if (!_diarizationEnabled ||
        snapshot == null ||
        snapshot.status != TranscriptSnapshotStatus.complete ||
        snapshot.segments.any((segment) => segment.speakerId != null)) {
      return Future.value();
    }
    return _runDiarization();
  }

  Future<void> _runDiarization() {
    final current = _diarizationOperation;
    if (current != null) {
      return current;
    }
    final runner = diarization;
    final snapshot = _snapshot;
    if (runner == null ||
        snapshot == null ||
        snapshot.status != TranscriptSnapshotStatus.complete) {
      return Future.value();
    }
    final operation = _processDiarization(runner, snapshot);
    _diarizationOperation = operation;
    _notify();
    return operation.whenComplete(() {
      _diarizationOperation = null;
      _notify();
    });
  }

  Future<void> _processDiarization(
    SpeakerDiarizationRunner runner,
    TranscriptSnapshot snapshot,
  ) async {
    _diarizationMessage = null;
    _notify();
    try {
      final result = await runner.process(
        meetingId: _meeting.id,
        snapshotId: snapshot.id,
        enabled: _diarizationEnabled,
      );
      _snapshot = result.snapshot;
      _diarizationStatus = result.status;
      _diarizationMessage = switch (result.status) {
        SpeakerDiarizationStatus.disabled => null,
        SpeakerDiarizationStatus.completed => '说话人分离已完成',
        SpeakerDiarizationStatus.degraded => '说话人分离失败，已按单一说话人显示；最终转录不受影响',
      };
    } on Object {
      _diarizationStatus = SpeakerDiarizationStatus.degraded;
      _diarizationMessage = '说话人分离失败，最终转录仍可查看；可稍后重试';
    } finally {
      _notify();
    }
  }

  void _applyProgress(AsrFinalizationProgress progress) {
    _progress = progress.fraction;
    _notify();
  }

  Future<void> _refreshSnapshots() async {
    final snapshots = await transcripts.listByMeeting(_meeting.id);
    _snapshot = _meeting.activeTranscriptSnapshotId == null
        ? null
        : await transcripts.getById(_meeting.activeTranscriptSnapshotId!);
    final failed =
        snapshots
            .where(
              (snapshot) =>
                  snapshot.kind == TranscriptSnapshotKind.finalTranscript &&
                  snapshot.status == TranscriptSnapshotStatus.failed,
            )
            .toList()
          ..sort((left, right) {
            final byDate = right.createdAt.compareTo(left.createdAt);
            return byDate != 0 ? byDate : right.id.compareTo(left.id);
          });
    _failedAttempt = failed.isEmpty ? null : failed.first;
    final processing =
        snapshots
            .where(
              (snapshot) =>
                  snapshot.kind == TranscriptSnapshotKind.finalTranscript &&
                  snapshot.status == TranscriptSnapshotStatus.processing,
            )
            .toList()
          ..sort((left, right) {
            final byDate = right.createdAt.compareTo(left.createdAt);
            return byDate != 0 ? byDate : right.id.compareTo(left.id);
          });
    _processingAttempt = processing.isEmpty ? null : processing.first;
  }

  Future<void> _refreshDiarizationTask() async {
    final repository = processingTasks;
    final snapshot = _snapshot;
    if (repository == null || snapshot == null) {
      return;
    }
    final records = await repository.listByMeeting(_meeting.id);
    ProcessingTask? task;
    for (final record in records) {
      if (record.kind == ProcessingTaskKind.speakerDiarization &&
          record.id == 'speaker-diarization-${snapshot.id}') {
        task = record;
        break;
      }
    }
    if (task == null) {
      return;
    }
    switch (task.state) {
      case ProcessingState.completed:
        _diarizationStatus = SpeakerDiarizationStatus.completed;
        _diarizationMessage = '说话人分离已完成';
      case ProcessingState.failed:
        _diarizationStatus = SpeakerDiarizationStatus.degraded;
        _diarizationMessage = '说话人分离失败，已按单一说话人显示；最终转录不受影响';
      case ProcessingState.idle ||
          ProcessingState.queued ||
          ProcessingState.running ||
          ProcessingState.canceled:
        break;
    }
  }
}
