import 'dart:convert';
import 'dart:io';

import '../../../domain/models/recording_continuity_event.dart';
import '../../../domain/ports/recording_continuity.dart';
import '../storage/app_file_layout.dart';

final class JsonRecordingContinuityEventStore
    implements RecordingContinuityEventStore {
  const JsonRecordingContinuityEventStore(this.layout);

  static const schemaVersion = 1;
  final AppFileLayout layout;

  @override
  Future<void> append(RecordingContinuityEvent event) async {
    final events = await read(event.meetingId);
    if (events.any(
      (candidate) =>
          candidate.incidentId == event.incidentId &&
          candidate.kind == event.kind,
    )) {
      return;
    }
    await _write(event.meetingId, [...events, event]);
  }

  @override
  Future<List<RecordingContinuityEvent>> read(String meetingId) async {
    final candidates = [
      File(layout.meetingContinuityPath(meetingId)),
      File(layout.meetingContinuityNextPath(meetingId)),
      File(layout.meetingContinuityPreviousPath(meetingId)),
    ];
    final valid = <List<RecordingContinuityEvent>>[];
    for (final file in candidates) {
      if (!await file.exists()) {
        continue;
      }
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map<String, Object?> ||
            decoded['schemaVersion'] != schemaVersion ||
            decoded['meetingId'] != meetingId ||
            decoded['events'] is! List<Object?>) {
          continue;
        }
        final events = [
          for (final item in decoded['events']! as List<Object?>)
            RecordingContinuityEvent.fromJson(item! as Map<String, Object?>),
        ];
        if (events.every((event) => event.meetingId == meetingId)) {
          valid.add(events);
        }
      } on Object {
        // 原子替换保留的另一代完整文件仍可恢复。
      }
    }
    if (valid.isEmpty) {
      return const [];
    }
    valid.sort((left, right) {
      final length = left.length.compareTo(right.length);
      if (length != 0 || left.isEmpty || right.isEmpty) {
        return length;
      }
      return left.last.at.compareTo(right.last.at);
    });
    return List.unmodifiable(valid.last);
  }

  Future<void> _write(
    String meetingId,
    List<RecordingContinuityEvent> events,
  ) async {
    final current = File(layout.meetingContinuityPath(meetingId));
    final next = File(layout.meetingContinuityNextPath(meetingId));
    final previous = File(layout.meetingContinuityPreviousPath(meetingId));
    await current.parent.create(recursive: true);
    if (await next.exists()) {
      await next.delete();
    }
    await next.writeAsString(
      jsonEncode({
        'schemaVersion': schemaVersion,
        'meetingId': meetingId,
        'events': [for (final event in events) event.toJson()],
      }),
      flush: true,
    );
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
}
