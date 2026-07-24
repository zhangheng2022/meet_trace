import 'domain_exception.dart';
import 'transcript.dart';
import 'workflow_states.dart';

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

  Meeting activateFinalTranscript(TranscriptSnapshot snapshot) {
    if (snapshot.meetingId != id) {
      throw const DomainInvariantViolation('不能激活其他会议的转录快照');
    }
    if (snapshot.kind != TranscriptSnapshotKind.finalTranscript ||
        snapshot.status != TranscriptSnapshotStatus.complete) {
      throw const DomainInvariantViolation('只能激活已完成的最终转录快照');
    }
    return _copyWith(
      activeTranscriptSnapshotId: snapshot.id,
      activeSummaryId: null,
    );
  }

  Meeting _copyWith({
    DateTime? startedAt,
    MeetingState? status,
    String? recordingModelId,
    String? recordingModelVersion,
    Object? modelFallbackReason = _notProvided,
    Object? activeTranscriptSnapshotId = _notProvided,
    Object? activeSummaryId = _notProvided,
  }) {
    return Meeting(
      id: id,
      title: title,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt,
      status: status ?? this.status,
      audioPath: audioPath,
      audioDurationMs: audioDurationMs,
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
      lastErrorCode: lastErrorCode,
    );
  }
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, '不能为空');
  }
}
