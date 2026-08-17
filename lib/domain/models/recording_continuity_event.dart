enum RecordingContinuityEventKind {
  interruptionStarted,
  switchedToSystemDefault,
  recordingInterrupted,
  systemSuspended,
  systemResumed,
  systemResumeFailed,
}

/// 录音输入中断的追加事实；同一 incidentId 的开始与结果可还原中断区间。
final class RecordingContinuityEvent {
  RecordingContinuityEvent({
    required this.meetingId,
    required this.incidentId,
    required this.kind,
    required this.at,
    required this.persistedBytes,
    required this.inputLabel,
  }) {
    if (meetingId.trim().isEmpty || incidentId.trim().isEmpty) {
      throw ArgumentError('meetingId 与 incidentId 不能为空');
    }
    if (persistedBytes < 0 || persistedBytes.isOdd) {
      throw ArgumentError.value(
        persistedBytes,
        'persistedBytes',
        '必须是非负且对齐 PCM16 样本边界',
      );
    }
    if (inputLabel.trim().isEmpty) {
      throw ArgumentError.value(inputLabel, 'inputLabel', '不能为空');
    }
  }

  final String meetingId;
  final String incidentId;
  final RecordingContinuityEventKind kind;
  final DateTime at;
  final int persistedBytes;
  final String inputLabel;

  Map<String, Object> toJson() => {
    'meetingId': meetingId,
    'incidentId': incidentId,
    'kind': kind.name,
    'at': at.toUtc().toIso8601String(),
    'persistedBytes': persistedBytes,
    'inputLabel': inputLabel,
  };

  factory RecordingContinuityEvent.fromJson(Map<String, Object?> json) =>
      RecordingContinuityEvent(
        meetingId: json['meetingId']! as String,
        incidentId: json['incidentId']! as String,
        kind: RecordingContinuityEventKind.values.byName(
          json['kind']! as String,
        ),
        at: DateTime.parse(json['at']! as String).toUtc(),
        persistedBytes: json['persistedBytes']! as int,
        inputLabel: json['inputLabel']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is RecordingContinuityEvent &&
      meetingId == other.meetingId &&
      incidentId == other.incidentId &&
      kind == other.kind &&
      at == other.at &&
      persistedBytes == other.persistedBytes &&
      inputLabel == other.inputLabel;

  @override
  int get hashCode =>
      Object.hash(meetingId, incidentId, kind, at, persistedBytes, inputLabel);
}
