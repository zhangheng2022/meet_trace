import 'workflow_states.dart';

enum ProcessingTaskKind {
  finalTranscription,
  modelInstallation,
  speakerDiarization,
  summary,
}

final class ProcessingTask {
  ProcessingTask({
    required this.id,
    required this.kind,
    this.meetingId,
    this.modelId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.leaseExpiresAt,
    this.lastErrorCode,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', '不能为空');
    }
    if (leaseExpiresAt != null && state != ProcessingState.running) {
      throw ArgumentError('只有 running 任务可以持有处理租约');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt 不能早于 createdAt');
    }
  }

  final String id;
  final ProcessingTaskKind kind;
  final String? meetingId;
  final String? modelId;
  final ProcessingState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? leaseExpiresAt;
  final String? lastErrorCode;

  ProcessingTask transitionTo(
    ProcessingState next, {
    required DateTime updatedAt,
    DateTime? leaseExpiresAt,
    String? errorCode,
  }) {
    return ProcessingTask(
      id: id,
      kind: kind,
      meetingId: meetingId,
      modelId: modelId,
      state: state.transitionTo(next),
      createdAt: createdAt,
      updatedAt: updatedAt,
      leaseExpiresAt: leaseExpiresAt,
      lastErrorCode: errorCode,
    );
  }
}
