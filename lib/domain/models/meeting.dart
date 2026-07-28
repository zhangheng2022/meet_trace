import 'domain_exception.dart';
import 'transcript.dart';
import 'workflow_states.dart';

const pendingMeetingTitle = '待生成标题';
const _notProvided = Object();

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
    required this.requestedModelId,
    required this.recordingModelId,
    required this.recordingModelVersion,
    this.modelFallbackReason,
    this.activeTranscriptSnapshotId,
    this.activeSummaryId,
    this.lastErrorCode,
  }) {
    _requireText(id, 'id');
    _requireText(requestedModelId, 'requestedModelId');
    _requireText(recordingModelId, 'recordingModelId');
    _requireText(recordingModelVersion, 'recordingModelVersion');
    if (audioDurationMs < 0) {
      throw ArgumentError.value(audioDurationMs, 'audioDurationMs', '不能为负数');
    }
    final fallbackReason = modelFallbackReason?.trim();
    if (requestedModelId != recordingModelId &&
        (fallbackReason == null || fallbackReason.isEmpty)) {
      throw ArgumentError('requestedModelId 与 recordingModelId 不同时必须记录显式回退原因');
    }
    if (requestedModelId == recordingModelId &&
        fallbackReason != null &&
        fallbackReason.isNotEmpty) {
      throw ArgumentError('未发生模型回退时不能记录回退原因');
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
  final String requestedModelId;
  final String recordingModelId;
  final String recordingModelVersion;
  final String? modelFallbackReason;
  final String? activeTranscriptSnapshotId;
  final String? activeSummaryId;
  final String? lastErrorCode;

  bool get isRecordingModelLocked => status != MeetingState.created;

  Meeting rename(String value) {
    final normalized = value.trim();
    _requireText(normalized, 'title');
    return _copyWith(title: normalized);
  }

  Meeting changeRecordingModel({
    required String recordingModelId,
    required String recordingModelVersion,
    String? fallbackReason,
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
      modelFallbackReason: fallbackReason,
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
      activeSummaryId: null,
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
    Object? modelFallbackReason = _notProvided,
    Object? activeTranscriptSnapshotId = _notProvided,
    Object? activeSummaryId = _notProvided,
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
      requestedModelId: requestedModelId,
      recordingModelId: recordingModelId ?? this.recordingModelId,
      recordingModelVersion:
          recordingModelVersion ?? this.recordingModelVersion,
      modelFallbackReason: identical(modelFallbackReason, _notProvided)
          ? this.modelFallbackReason
          : modelFallbackReason as String?,
      activeTranscriptSnapshotId:
          identical(activeTranscriptSnapshotId, _notProvided)
          ? this.activeTranscriptSnapshotId
          : activeTranscriptSnapshotId as String?,
      activeSummaryId: identical(activeSummaryId, _notProvided)
          ? this.activeSummaryId
          : activeSummaryId as String?,
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
