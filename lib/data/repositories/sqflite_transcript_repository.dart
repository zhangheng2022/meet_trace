import 'package:sqflite/sqflite.dart';

import '../../domain/models/domain_exception.dart';
import '../../domain/models/summary.dart';
import '../../domain/models/transcript.dart';
import '../services/storage/app_database.dart';
import '../../domain/ports/repositories.dart';

final class SqfliteTranscriptRepository implements TranscriptRepository {
  SqfliteTranscriptRepository(this._appDatabase, {this.onMeetingChanged});

  final AppDatabase _appDatabase;
  final void Function()? onMeetingChanged;

  @override
  Future<TranscriptSnapshot?> getById(String snapshotId) async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'transcript_snapshots',
      where: 'id = ?',
      whereArgs: [snapshotId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _snapshotFromRow(db, rows.single);
  }

  @override
  Future<List<TranscriptSnapshot>> listByMeeting(String meetingId) async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'transcript_snapshots',
      where: 'meeting_id = ?',
      whereArgs: [meetingId],
      orderBy: 'created_at, id',
    );
    final snapshots = <TranscriptSnapshot>[];
    for (final row in rows) {
      snapshots.add(await _snapshotFromRow(db, row));
    }
    return List.unmodifiable(snapshots);
  }

  @override
  Future<void> save(TranscriptSnapshot snapshot) async {
    final db = await _appDatabase.open();
    await db.transaction((txn) => _saveSnapshot(txn, snapshot));
  }

  @override
  Future<void> saveFinalAndActivate({
    required TranscriptSnapshot snapshot,
    required String? expectedActiveSnapshotId,
  }) async {
    if (snapshot.kind != TranscriptSnapshotKind.finalTranscript ||
        snapshot.status != TranscriptSnapshotStatus.complete) {
      throw const DomainInvariantViolation('只能保存并激活已完成的最终转录快照');
    }

    final db = await _appDatabase.open();
    await db.transaction((txn) async {
      await _saveSnapshot(txn, snapshot);
      final updated = await txn.update(
        'meetings',
        {
          'active_transcript_snapshot_id': snapshot.id,
          'active_summary_id': null,
          'status': 'completed',
          'last_error_code': null,
        },
        where: expectedActiveSnapshotId == null
            ? 'id = ? AND active_transcript_snapshot_id IS NULL'
            : 'id = ? AND active_transcript_snapshot_id = ?',
        whereArgs: expectedActiveSnapshotId == null
            ? [snapshot.meetingId]
            : [snapshot.meetingId, expectedActiveSnapshotId],
      );
      if (updated != 1) {
        throw const DomainInvariantViolation('活动快照已变化，拒绝覆盖并回滚新快照');
      }
      await txn.update(
        'summaries',
        {'status': SummaryStatus.stale.name},
        where: 'meeting_id = ? AND transcript_snapshot_id <> ? AND status = ?',
        whereArgs: [
          snapshot.meetingId,
          snapshot.id,
          SummaryStatus.complete.name,
        ],
      );
    });
    onMeetingChanged?.call();
  }

  @override
  Future<TranscriptSnapshot> updateSpeakerLabels({
    required String snapshotId,
    required Map<String, String?> labelsBySegmentId,
  }) async {
    for (final label in labelsBySegmentId.values) {
      if (label != null && (label.trim().isEmpty || label.trim().length > 80)) {
        throw const DomainInvariantViolation('说话人标签必须为 1 到 80 个字符');
      }
    }
    final db = await _appDatabase.open();
    return db.transaction((txn) async {
      final snapshotRows = await txn.query(
        'transcript_snapshots',
        where: 'id = ?',
        whereArgs: [snapshotId],
        limit: 1,
      );
      if (snapshotRows.isEmpty ||
          snapshotRows.single['kind'] !=
              TranscriptSnapshotKind.finalTranscript.name ||
          snapshotRows.single['status'] !=
              TranscriptSnapshotStatus.complete.name) {
        throw const DomainInvariantViolation('只能更新已完成最终快照的说话人标签');
      }
      final segmentRows = await txn.query(
        'transcript_segments',
        columns: const ['id'],
        where: 'snapshot_id = ?',
        whereArgs: [snapshotId],
      );
      final segmentIds = segmentRows.map((row) => row['id']! as String).toSet();
      if (!segmentIds.containsAll(labelsBySegmentId.keys)) {
        throw const DomainInvariantViolation('说话人标签包含不属于目标快照的片段');
      }
      for (final entry in labelsBySegmentId.entries) {
        final updated = await txn.update(
          'transcript_segments',
          {'speaker_id': entry.value?.trim()},
          where: 'id = ? AND snapshot_id = ?',
          whereArgs: [entry.key, snapshotId],
        );
        if (updated != 1) {
          throw const DomainInvariantViolation('说话人标签更新失败');
        }
      }
      return _snapshotFromRow(txn, snapshotRows.single);
    });
  }
}

Future<void> _saveSnapshot(
  DatabaseExecutor executor,
  TranscriptSnapshot snapshot,
) async {
  final row = <String, Object?>{
    'id': snapshot.id,
    'meeting_id': snapshot.meetingId,
    'kind': snapshot.kind.name,
    'actual_model_id': snapshot.actualModelId,
    'actual_model_version': snapshot.actualModelVersion,
    'created_at': snapshot.createdAt.millisecondsSinceEpoch,
    'status': snapshot.status.name,
  };
  final updated = await executor.update(
    'transcript_snapshots',
    row,
    where: 'id = ?',
    whereArgs: [snapshot.id],
  );
  if (updated == 0) {
    await executor.insert('transcript_snapshots', row);
  }
  await executor.delete(
    'transcript_segments',
    where: 'snapshot_id = ?',
    whereArgs: [snapshot.id],
  );
  for (final segment in snapshot.segments) {
    await executor.insert('transcript_segments', {
      'id': segment.id,
      'snapshot_id': segment.snapshotId,
      'start_ms': segment.startMs,
      'end_ms': segment.endMs,
      'text': segment.text,
      'speaker_id': segment.speakerId,
      'confidence': segment.confidence,
      'model_id': segment.modelId,
      'model_version': segment.modelVersion,
    });
  }
}

Future<TranscriptSnapshot> _snapshotFromRow(
  DatabaseExecutor executor,
  Map<String, Object?> row,
) async {
  final segmentRows = await executor.query(
    'transcript_segments',
    where: 'snapshot_id = ?',
    whereArgs: [row['id']],
    orderBy: 'start_ms, end_ms, id',
  );
  return TranscriptSnapshot(
    id: row['id']! as String,
    meetingId: row['meeting_id']! as String,
    kind: TranscriptSnapshotKind.values.byName(row['kind']! as String),
    actualModelId: row['actual_model_id']! as String,
    actualModelVersion: row['actual_model_version']! as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at']! as int,
      isUtc: true,
    ),
    status: TranscriptSnapshotStatus.values.byName(row['status']! as String),
    segments: segmentRows
        .map(
          (segment) => TranscriptSegment(
            id: segment['id']! as String,
            snapshotId: segment['snapshot_id']! as String,
            startMs: segment['start_ms']! as int,
            endMs: segment['end_ms']! as int,
            text: segment['text']! as String,
            speakerId: segment['speaker_id'] as String?,
            confidence: segment['confidence'] as double?,
            modelId: segment['model_id']! as String,
            modelVersion: segment['model_version']! as String,
          ),
        )
        .toList(),
  );
}
