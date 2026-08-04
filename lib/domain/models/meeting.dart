import 'domain_exception.dart';
import 'transcript.dart';
import 'workflow_states.dart';

const _notProvided = Object();

String meetingStartTimeLabel(DateTime startedAt) {
  final local = startedAt.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String meetingTitleForStartTime(DateTime startedAt) =>
    '${meetingStartTimeLabel(startedAt)} 会议';

final class Meeting {
  Meeting({
    required this.id,
    required this.title,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    required this.status,
    this.audioPath,
    required this.audioDurationMs,
    required this.recordingModelId,
    required this.recordingModelVersion,
    this.recordingModelLanguage = 'auto',
    this.recordingModelUseInverseTextNormalization = true,
    this.activeTranscriptSnapshotId,
    this.lastErrorCode,
  }) {
    _requireText(id, 'id');
    _requireText(title, 'title');
    _requireText(recordingModelId, 'recordingModelId');
    _requireText(recordingModelVersion, 'recordingModelVersion');
    _requireText(recordingModelLanguage, 'recordingModelLanguage');
    if (audioDurationMs < 0) {
      throw ArgumentError.value(audioDurationMs, 'audioDurationMs', '不能为负数');
    }
    if (startedAt != null && startedAt!.isBefore(createdAt)) {
      throw ArgumentError('startedAt 不能早于 createdAt');
    }
    if (endedAt != null &&
        (startedAt == null || endedAt!.isBefore(startedAt!))) {
      throw ArgumentError('endedAt 必须晚于 startedAt');
    }
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final MeetingState status;
  final String? audioPath;
  final int audioDurationMs;
  final String recordingModelId;
  final String recordingModelVersion;
  final String recordingModelLanguage;
  final bool recordingModelUseInverseTextNormalization;
  final String? activeTranscriptSnapshotId;
  final String? lastErrorCode;

  bool get isRecordingModelLocked => status != MeetingState.created;

  Meeting changeRecordingModel({
    required String recordingModelId,
    required String recordingModelVersion,
    String recordingModelLanguage = 'auto',
    bool recordingModelUseInverseTextNormalization = true,
  }) {
    if (isRecordingModelLocked) {
      throw InvalidStateTransitionException(
        machine: 'meetingModelSelection',
        from: status,
        to: status,
      );
    }
    return _copyWith(
      recordingModelId: recordingModelId,
      recordingModelVersion: recordingModelVersion,
      recordingModelLanguage: recordingModelLanguage,
      recordingModelUseInverseTextNormalization:
          recordingModelUseInverseTextNormalization,
    );
  }

  Meeting startRecording({required DateTime startedAt}) {
    return _copyWith(
      status: status.transitionTo(MeetingState.recording),
      startedAt: startedAt,
    );
  }

  Meeting finishRecording({
    required DateTime endedAt,
    required String audioPath,
    required int audioDurationMs,
  }) {
    if (audioPath.trim().isEmpty) {
      throw ArgumentError.value(audioPath, 'audioPath', '不能为空');
    }
    return _copyWith(
      status: status.transitionTo(MeetingState.processing),
      endedAt: endedAt,
      audioPath: audioPath,
      audioDurationMs: audioDurationMs,
    );
  }

  Meeting fail({required String errorCode, DateTime? endedAt}) {
    _requireText(errorCode, 'errorCode');
    return _copyWith(
      status: status.transitionTo(MeetingState.failed),
      endedAt: endedAt,
      lastErrorCode: errorCode,
    );
  }

  Meeting beginFinalTranscription() {
    final nextStatus = switch (status) {
      MeetingState.processing => MeetingState.processing,
      MeetingState.completed ||
      MeetingState.failed => status.transitionTo(MeetingState.processing),
      _ => throw InvalidStateTransitionException(
        machine: 'finalTranscription',
        from: status,
        to: MeetingState.processing,
      ),
    };
    if (audioPath?.trim().isEmpty != false || audioDurationMs <= 0) {
      throw const DomainInvariantViolation('最终转录必须基于已封存的完整事实音频');
    }
    return _copyWith(status: nextStatus, lastErrorCode: null);
  }

  Meeting activateFinalTranscript(TranscriptSnapshot snapshot) {
    if (status != MeetingState.processing) {
      throw InvalidStateTransitionException(
        machine: 'finalTranscription',
        from: status,
        to: MeetingState.completed,
      );
    }
    if (snapshot.meetingId != id) {
      throw const DomainInvariantViolation('不能激活其他会议的转录快照');
    }
    if (snapshot.kind != TranscriptSnapshotKind.finalTranscript ||
        snapshot.status != TranscriptSnapshotStatus.complete) {
      throw const DomainInvariantViolation('只能激活已完成的最终转录快照');
    }
    return _copyWith(
      status: status.transitionTo(MeetingState.completed),
      activeTranscriptSnapshotId: snapshot.id,
      lastErrorCode: null,
    );
  }

  Meeting _copyWith({
    String? title,
    DateTime? startedAt,
    DateTime? endedAt,
    MeetingState? status,
    String? audioPath,
    int? audioDurationMs,
    String? recordingModelId,
    String? recordingModelVersion,
    String? recordingModelLanguage,
    bool? recordingModelUseInverseTextNormalization,
    Object? activeTranscriptSnapshotId = _notProvided,
    Object? lastErrorCode = _notProvided,
  }) {
    return Meeting(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      audioPath: audioPath ?? this.audioPath,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      recordingModelId: recordingModelId ?? this.recordingModelId,
      recordingModelVersion:
          recordingModelVersion ?? this.recordingModelVersion,
      recordingModelLanguage:
          recordingModelLanguage ?? this.recordingModelLanguage,
      recordingModelUseInverseTextNormalization:
          recordingModelUseInverseTextNormalization ??
          this.recordingModelUseInverseTextNormalization,
      activeTranscriptSnapshotId:
          identical(activeTranscriptSnapshotId, _notProvided)
          ? this.activeTranscriptSnapshotId
          : activeTranscriptSnapshotId as String?,
      lastErrorCode: identical(lastErrorCode, _notProvided)
          ? this.lastErrorCode
          : lastErrorCode as String?,
    );
  }
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, '不能为空');
  }
}
