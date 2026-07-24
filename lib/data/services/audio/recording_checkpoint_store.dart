import 'dart:convert';
import 'dart:io';

import '../storage/app_file_layout.dart';

enum RecordingCheckpointState { recording, paused, finalized, failed }

final class RecordingCheckpoint {
  RecordingCheckpoint({
    required this.meetingId,
    required this.state,
    required this.persistedBytes,
    required this.updatedAt,
  }) {
    if (meetingId.trim().isEmpty) {
      throw ArgumentError.value(meetingId, 'meetingId', '不能为空');
    }
    if (persistedBytes < 0 || persistedBytes.isOdd) {
      throw ArgumentError.value(
        persistedBytes,
        'persistedBytes',
        '必须是非负且对齐 PCM16 样本边界',
      );
    }
  }

  static const schemaVersion = 1;

  final String meetingId;
  final RecordingCheckpointState state;
  final int persistedBytes;
  final DateTime updatedAt;

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'meetingId': meetingId,
    'state': state.name,
    'persistedBytes': persistedBytes,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory RecordingCheckpoint.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('不支持的录音 checkpoint schema');
    }
    final stateName = json['state'];
    if (stateName is! String) {
      throw const FormatException('checkpoint state 缺失');
    }
    return RecordingCheckpoint(
      meetingId: json['meetingId']! as String,
      state: RecordingCheckpointState.values.byName(stateName),
      persistedBytes: json['persistedBytes']! as int,
      updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecordingCheckpoint &&
        meetingId == other.meetingId &&
        state == other.state &&
        persistedBytes == other.persistedBytes &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(meetingId, state, persistedBytes, updatedAt);
}

abstract interface class RecordingCheckpointStore {
  Future<void> save(RecordingCheckpoint checkpoint);

  Future<RecordingCheckpoint?> load(String meetingId);

  Future<void> delete(String meetingId);
}

final class JsonRecordingCheckpointStore implements RecordingCheckpointStore {
  const JsonRecordingCheckpointStore(this.layout);

  final AppFileLayout layout;

  @override
  Future<void> save(RecordingCheckpoint checkpoint) async {
    final current = File(
      layout.meetingAudioCheckpointPath(checkpoint.meetingId),
    );
    final next = File(
      layout.meetingAudioCheckpointNextPath(checkpoint.meetingId),
    );
    final previous = File(
      layout.meetingAudioCheckpointPreviousPath(checkpoint.meetingId),
    );
    await current.parent.create(recursive: true);

    if (await next.exists()) {
      await next.delete();
    }
    await next.writeAsString(jsonEncode(checkpoint.toJson()), flush: true);

    if (await previous.exists()) {
      await previous.delete();
    }
    if (await current.exists()) {
      await current.rename(previous.path);
    }
    await next.rename(current.path);
    if (await previous.exists()) {
      await previous.delete();
    }
  }

  @override
  Future<RecordingCheckpoint?> load(String meetingId) async {
    final candidates = [
      File(layout.meetingAudioCheckpointPath(meetingId)),
      File(layout.meetingAudioCheckpointNextPath(meetingId)),
      File(layout.meetingAudioCheckpointPreviousPath(meetingId)),
    ];
    final valid = <RecordingCheckpoint>[];
    for (final file in candidates) {
      if (!await file.exists()) {
        continue;
      }
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map<String, Object?>) {
          continue;
        }
        final checkpoint = RecordingCheckpoint.fromJson(decoded);
        if (checkpoint.meetingId == meetingId) {
          valid.add(checkpoint);
        }
      } on Object {
        // 另一代完整 checkpoint 仍可恢复，单个损坏候选不阻塞读取。
      }
    }
    if (valid.isEmpty) {
      return null;
    }
    valid.sort((left, right) {
      final bytes = left.persistedBytes.compareTo(right.persistedBytes);
      return bytes != 0 ? bytes : left.updatedAt.compareTo(right.updatedAt);
    });
    return valid.last;
  }

  @override
  Future<void> delete(String meetingId) async {
    for (final path in [
      layout.meetingAudioCheckpointPath(meetingId),
      layout.meetingAudioCheckpointNextPath(meetingId),
      layout.meetingAudioCheckpointPreviousPath(meetingId),
    ]) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
