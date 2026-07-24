import 'package:sqflite/sqflite.dart';

import '../../../domain/models/asr_model.dart';
import '../../../domain/models/meeting.dart';
import '../../../domain/models/model_installation.dart';
import '../../../domain/models/processing_task.dart';
import '../../../domain/models/workflow_states.dart';

Map<String, Object?> meetingToRow(Meeting meeting) {
  return {
    'id': meeting.id,
    'title': meeting.title,
    'created_at': meeting.createdAt.millisecondsSinceEpoch,
    'started_at': meeting.startedAt?.millisecondsSinceEpoch,
    'ended_at': meeting.endedAt?.millisecondsSinceEpoch,
    'status': meeting.status.name,
    'audio_path': meeting.audioPath,
    'audio_duration_ms': meeting.audioDurationMs,
    'requested_model_id': meeting.requestedModelId,
    'recording_model_id': meeting.recordingModelId,
    'recording_model_version': meeting.recordingModelVersion,
    'model_fallback_reason': meeting.modelFallbackReason,
    'active_transcript_snapshot_id': meeting.activeTranscriptSnapshotId,
    'active_summary_id': meeting.activeSummaryId,
    'last_error_code': meeting.lastErrorCode,
  };
}

Meeting meetingFromRow(Map<String, Object?> row) {
  return Meeting(
    id: row['id']! as String,
    title: row['title']! as String,
    createdAt: _date(row['created_at']),
    startedAt: _nullableDate(row['started_at']),
    endedAt: _nullableDate(row['ended_at']),
    status: MeetingState.values.byName(row['status']! as String),
    audioPath: row['audio_path'] as String?,
    audioDurationMs: row['audio_duration_ms']! as int,
    requestedModelId: row['requested_model_id']! as String,
    recordingModelId: row['recording_model_id']! as String,
    recordingModelVersion: row['recording_model_version']! as String,
    modelFallbackReason: row['model_fallback_reason'] as String?,
    activeTranscriptSnapshotId: row['active_transcript_snapshot_id'] as String?,
    activeSummaryId: row['active_summary_id'] as String?,
    lastErrorCode: row['last_error_code'] as String?,
  );
}

Future<void> upsertMeeting(DatabaseExecutor executor, Meeting meeting) async {
  final row = meetingToRow(meeting);
  final updated = await executor.update(
    'meetings',
    row,
    where: 'id = ?',
    whereArgs: [meeting.id],
  );
  if (updated == 0) {
    await executor.insert('meetings', row);
  }
}

Map<String, Object?> processingTaskToRow(ProcessingTask task) {
  return {
    'id': task.id,
    'kind': task.kind.name,
    'meeting_id': task.meetingId,
    'model_id': task.modelId,
    'state': task.state.name,
    'created_at': task.createdAt.millisecondsSinceEpoch,
    'updated_at': task.updatedAt.millisecondsSinceEpoch,
    'lease_expires_at': task.leaseExpiresAt?.millisecondsSinceEpoch,
    'last_error_code': task.lastErrorCode,
  };
}

ProcessingTask processingTaskFromRow(Map<String, Object?> row) {
  return ProcessingTask(
    id: row['id']! as String,
    kind: ProcessingTaskKind.values.byName(row['kind']! as String),
    meetingId: row['meeting_id'] as String?,
    modelId: row['model_id'] as String?,
    state: ProcessingState.values.byName(row['state']! as String),
    createdAt: _date(row['created_at']),
    updatedAt: _date(row['updated_at']),
    leaseExpiresAt: _nullableDate(row['lease_expires_at']),
    lastErrorCode: row['last_error_code'] as String?,
  );
}

Map<String, Object?> modelInstallationToRow(ModelInstallation installation) {
  return {
    'model_id': installation.modelId,
    'version': installation.version,
    'installation_type': installation.installationType.name,
    'state': installation.state.name,
    'installed_path': installation.installedPath,
    'verified_at': installation.verifiedAt?.millisecondsSinceEpoch,
    'bytes': installation.bytes,
    'last_error_code': installation.lastErrorCode,
  };
}

ModelInstallation modelInstallationFromRow(Map<String, Object?> row) {
  return ModelInstallation(
    modelId: row['model_id']! as String,
    version: row['version']! as String,
    installationType: AsrInstallationType.values.byName(
      row['installation_type']! as String,
    ),
    state: ModelInstallationState.values.byName(row['state']! as String),
    installedPath: row['installed_path'] as String?,
    verifiedAt: _nullableDate(row['verified_at']),
    bytes: row['bytes']! as int,
    lastErrorCode: row['last_error_code'] as String?,
  );
}

DateTime _date(Object? value) {
  return DateTime.fromMillisecondsSinceEpoch(value! as int, isUtc: true);
}

DateTime? _nullableDate(Object? value) {
  return value == null ? null : _date(value);
}
