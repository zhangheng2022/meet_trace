import '../../../../../domain/models/processing_task.dart';
import '../../../../../domain/models/speaker_diarization.dart';
import '../../../../../domain/models/transcript.dart';
import '../../../../../domain/models/workflow_states.dart';
import '../../../../../domain/ports/asr_engine.dart';
import '../../../../../domain/ports/speaker_diarization.dart';
import '../../../../../domain/use_cases/revise_final_transcript.dart';
import 'meeting_detail_view_model.dart';

final class MeetingTranscriptViewModel {
  const MeetingTranscriptViewModel.internal(this._owner);
  final MeetingDetailViewModel _owner;

  TranscriptSnapshot? get snapshot => _owner.snapshot;
  bool get isTranscribing => _owner.isTranscribing;
  bool get isDiarizing => _owner.isDiarizing;
  bool get canRetry => _owner.canRetry;
  bool get canRetranscribe => _owner.canRetranscribe;

  Future<void> retry() => _owner.internalRetry();
  Future<void> retranscribe() => _owner.internalRetranscribe();
  Future<void> setDiarizationEnabled(bool enabled) =>
      _owner.internalSetDiarizationEnabled(enabled);
  Future<void> retryDiarization() => _owner.internalRetryDiarization();
  Future<bool> renameSpeaker(String? currentSpeakerId, String newLabel) =>
      _owner.internalRenameSpeaker(currentSpeakerId, newLabel);
  Future<void> reviseTranscript(List<TranscriptSegmentRevision> revisions) =>
      _owner.internalReviseTranscript(revisions);
}

extension MeetingTranscriptOperations on MeetingDetailViewModel {
  Future<void> internalRetry() {
    final failed = internalFailedAttempt;
    if (failed == null) {
      return Future.value();
    }
    return internalRunTranscription(
      retrySnapshotId: internalLockedRetrySnapshotId(failed),
    );
  }

  Future<void> internalRetranscribe() => internalRunTranscription();

  String? internalLockedRetrySnapshotId(TranscriptSnapshot snapshot) {
    return snapshot.actualModelId == internalMeeting.recordingModelId &&
            snapshot.actualModelVersion == internalMeeting.recordingModelVersion
        ? snapshot.id
        : null;
  }

  Future<void> internalSetDiarizationEnabled(bool enabled) async {
    final preferences = diarizationPreferences;
    if (preferences == null ||
        (enabled && !diarizationAvailable) ||
        isProcessing) {
      return;
    }
    internalDiarizationEnabled = enabled;
    internalDiarizationStatus = SpeakerDiarizationStatus.disabled;
    internalDiarizationMessage = null;
    internalNotify();
    await preferences.setEnabled(enabled);
    if (enabled) {
      await _runDiarization();
    }
  }

  Future<void> internalRetryDiarization() => _runDiarization();

  Future<bool> internalRenameSpeaker(
    String? currentSpeakerId,
    String newLabel,
  ) async {
    final snapshot = internalSnapshot;
    if (snapshot == null || isProcessing) {
      return false;
    }
    final revision = transcriptRevision;
    if (revision != null) {
      await reviseTranscript([
        for (final segment in snapshot.segments)
          TranscriptSegmentRevision(
            segmentId: segment.id,
            text: segment.text,
            speakerLabel: segment.speakerId == currentSpeakerId
                ? newLabel
                : segment.speakerId,
          ),
      ]);
      return internalSnapshot?.id != snapshot.id;
    }
    final runner = diarization;
    if (runner == null) {
      return false;
    }
    try {
      internalSnapshot = await runner.renameSpeaker(
        meetingId: internalMeeting.id,
        snapshotId: snapshot.id,
        currentSpeakerId: currentSpeakerId,
        newLabel: newLabel,
      );
      internalDiarizationMessage = '说话人标签已保存';
      return true;
    } on Object {
      internalDiarizationMessage = '说话人标签保存失败，请重试';
      return false;
    } finally {
      internalNotify();
    }
  }

  Future<void> internalReviseTranscript(
    List<TranscriptSegmentRevision> revisions,
  ) => internalRunResultOperation(() async {
    final useCase = transcriptRevision;
    if (useCase == null) {
      return;
    }
    final result = await useCase.execute(
      meetingId: internalMeeting.id,
      revisions: revisions,
    );
    internalMeeting = result.meeting;
    internalSnapshot = result.snapshot;
    internalResultMessage = '转录修订已保存为新版本';
  }, failureMessage: '转录修订保存失败，请检查内容后重试');

  Future<void> internalRunTranscription({String? retrySnapshotId}) {
    final current = internalOperation;
    if (current != null) {
      return current;
    }
    final operation = _transcribe(retrySnapshotId: retrySnapshotId);
    internalOperation = operation;
    internalNotify();
    return operation.whenComplete(() {
      internalOperation = null;
      internalNotify();
    });
  }

  Future<void> _transcribe({required String? retrySnapshotId}) async {
    internalErrorMessage = null;
    internalProgress = 0;
    internalNotify();
    try {
      final result = await transcription.transcribe(
        meetingId: internalMeeting.id,
        retrySnapshotId: retrySnapshotId,
        onProgress: _applyProgress,
      );
      internalMeeting = result.meeting;
      internalSnapshot = result.snapshot;
      internalFailedAttempt = null;
      internalProcessingAttempt = null;
      internalProgress = 1;
      internalDiarizationStatus = result.diarizationStatus;
      internalDiarizationMessage = switch (result.diarizationStatus) {
        SpeakerDiarizationStatus.disabled => null,
        SpeakerDiarizationStatus.completed => '说话人分离已完成',
        SpeakerDiarizationStatus.degraded => '说话人分离失败，已按单一说话人显示；最终转录不受影响',
      };
    } on Object {
      internalErrorMessage = '最终转录失败，事实音频和旧结果均已保留';
      await internalRefreshMeeting();
      await internalRefreshSnapshots();
    } finally {
      internalNotify();
    }
  }

  Future<void> internalRunDiarizationIfNeeded() {
    final snapshot = internalSnapshot;
    if (!internalDiarizationEnabled ||
        snapshot == null ||
        snapshot.status != TranscriptSnapshotStatus.complete ||
        snapshot.segments.any((segment) => segment.speakerId != null)) {
      return Future.value();
    }
    return _runDiarization();
  }

  Future<void> _runDiarization() {
    final current = internalDiarizationOperation;
    if (current != null) {
      return current;
    }
    final runner = diarization;
    final snapshot = internalSnapshot;
    if (runner == null ||
        snapshot == null ||
        snapshot.status != TranscriptSnapshotStatus.complete) {
      return Future.value();
    }
    final operation = _processDiarization(runner, snapshot);
    internalDiarizationOperation = operation;
    internalNotify();
    return operation.whenComplete(() {
      internalDiarizationOperation = null;
      internalNotify();
    });
  }

  Future<void> _processDiarization(
    SpeakerDiarizationRunner runner,
    TranscriptSnapshot snapshot,
  ) async {
    internalDiarizationMessage = null;
    internalNotify();
    try {
      final result = await runner.process(
        meetingId: internalMeeting.id,
        snapshotId: snapshot.id,
        enabled: internalDiarizationEnabled,
      );
      internalSnapshot = result.snapshot;
      internalDiarizationStatus = result.status;
      internalDiarizationMessage = switch (result.status) {
        SpeakerDiarizationStatus.disabled => null,
        SpeakerDiarizationStatus.completed => '说话人分离已完成',
        SpeakerDiarizationStatus.degraded => '说话人分离失败，已按单一说话人显示；最终转录不受影响',
      };
    } on Object {
      internalDiarizationStatus = SpeakerDiarizationStatus.degraded;
      internalDiarizationMessage = '说话人分离失败，最终转录仍可查看；可稍后重试';
    } finally {
      internalNotify();
    }
  }

  void _applyProgress(AsrFinalizationProgress progress) {
    internalProgress = progress.fraction;
    internalNotify();
  }

  Future<void> internalRefreshSnapshots() async {
    final activeId = internalMeeting.activeTranscriptSnapshotId;
    final snapshots = await Future.wait<TranscriptSnapshot?>([
      activeId == null
          ? Future<TranscriptSnapshot?>.value()
          : transcripts.getById(activeId),
      transcripts.getLatestByMeeting(
        meetingId: internalMeeting.id,
        kind: TranscriptSnapshotKind.finalTranscript,
        status: TranscriptSnapshotStatus.failed,
      ),
      transcripts.getLatestByMeeting(
        meetingId: internalMeeting.id,
        kind: TranscriptSnapshotKind.finalTranscript,
        status: TranscriptSnapshotStatus.processing,
      ),
    ]);
    internalSnapshot = snapshots[0];
    internalFailedAttempt = snapshots[1];
    internalProcessingAttempt = snapshots[2];
  }

  Future<void> internalRefreshDiarizationTask() async {
    final repository = processingTasks;
    final snapshot = internalSnapshot;
    if (repository == null || snapshot == null) {
      return;
    }
    final records = await repository.listByMeeting(internalMeeting.id);
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
        internalDiarizationStatus = SpeakerDiarizationStatus.completed;
        internalDiarizationMessage = '说话人分离已完成';
      case ProcessingState.failed:
        internalDiarizationStatus = SpeakerDiarizationStatus.degraded;
        internalDiarizationMessage = '说话人分离失败，已按单一说话人显示；最终转录不受影响';
      case ProcessingState.idle ||
          ProcessingState.queued ||
          ProcessingState.running ||
          ProcessingState.canceled:
        break;
    }
  }
}
