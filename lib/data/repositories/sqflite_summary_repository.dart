import 'package:sqflite/sqflite.dart';

import '../../domain/models/domain_exception.dart';
import '../../domain/models/summary.dart';
import '../services/storage/app_database.dart';
import 'repository_contracts.dart';

final class SqfliteSummaryRepository implements SummaryRepository {
  SqfliteSummaryRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<Summary?> getById(String summaryId) async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'summaries',
      where: 'id = ?',
      whereArgs: [summaryId],
      limit: 1,
    );
    return rows.isEmpty ? null : _summaryFromRow(db, rows.single);
  }

  @override
  Future<List<Summary>> listByMeeting(String meetingId) async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'summaries',
      where: 'meeting_id = ?',
      whereArgs: [meetingId],
      orderBy: 'created_at, id',
    );
    final summaries = <Summary>[];
    for (final row in rows) {
      summaries.add(await _summaryFromRow(db, row));
    }
    return List.unmodifiable(summaries);
  }

  @override
  Future<void> save(Summary summary) async {
    final db = await _appDatabase.open();
    await db.transaction((txn) async {
      await _saveSummary(txn, summary);
    });
  }

  @override
  Future<void> saveAndActivate({
    required Summary summary,
    required String expectedTranscriptSnapshotId,
  }) async {
    if (summary.status != SummaryStatus.complete ||
        summary.transcriptSnapshotId != expectedTranscriptSnapshotId) {
      throw const DomainInvariantViolation('只能激活当前最终快照的已完成摘要');
    }
    final db = await _appDatabase.open();
    await db.transaction((txn) async {
      final snapshots = await txn.query(
        'transcript_snapshots',
        columns: const ['id'],
        where: 'id = ? AND meeting_id = ? AND kind = ? AND status = ?',
        whereArgs: [
          expectedTranscriptSnapshotId,
          summary.meetingId,
          'finalTranscript',
          'complete',
        ],
        limit: 1,
      );
      if (snapshots.isEmpty) {
        throw const DomainInvariantViolation('摘要来源必须是已完成的最终转录快照');
      }
      await _validateEvidence(txn, summary);
      await _saveSummary(txn, summary);
      final updated = await txn.update(
        'meetings',
        {'active_summary_id': summary.id},
        where: 'id = ? AND status = ? AND active_transcript_snapshot_id = ?',
        whereArgs: [
          summary.meetingId,
          'completed',
          expectedTranscriptSnapshotId,
        ],
      );
      if (updated != 1) {
        throw const DomainInvariantViolation('最终转录已变化，摘要不能激活');
      }
    });
  }
}

Future<void> _validateEvidence(
  DatabaseExecutor executor,
  Summary summary,
) async {
  for (final item in [...summary.keyPoints, ...summary.actionItems]) {
    for (final evidence in item.evidence) {
      final segments = await executor.query(
        'transcript_segments',
        columns: const ['snapshot_id', 'start_ms', 'end_ms', 'text'],
        where: 'id = ?',
        whereArgs: [evidence.segmentId],
        limit: 1,
      );
      if (segments.isEmpty) {
        throw const DomainInvariantViolation('摘要证据必须引用本地最终转录片段');
      }
      final segment = segments.single;
      if (segment['snapshot_id'] != summary.transcriptSnapshotId ||
          segment['start_ms'] != evidence.startMs ||
          segment['end_ms'] != evidence.endMs ||
          segment['text'] != evidence.quote) {
        throw const DomainInvariantViolation('摘要证据必须与本地最终转录原文完全一致');
      }
    }
  }
}

Future<void> _saveSummary(DatabaseExecutor executor, Summary summary) async {
  final row = <String, Object?>{
    'id': summary.id,
    'meeting_id': summary.meetingId,
    'transcript_snapshot_id': summary.transcriptSnapshotId,
    'provider': summary.provider,
    'model': summary.model,
    'created_at': summary.createdAt.millisecondsSinceEpoch,
    'overview': summary.overview,
    'status': summary.status.name,
  };
  final updated = await executor.update(
    'summaries',
    row,
    where: 'id = ?',
    whereArgs: [summary.id],
  );
  if (updated == 0) {
    await executor.insert('summaries', row);
  }
  await executor.delete(
    'summary_items',
    where: 'summary_id = ?',
    whereArgs: [summary.id],
  );
  await _insertItems(executor, summary.id, 'keyPoint', summary.keyPoints);
  await _insertItems(executor, summary.id, 'actionItem', summary.actionItems);
}

Future<void> _insertItems(
  DatabaseExecutor executor,
  String summaryId,
  String kind,
  List<SummaryItem> items,
) async {
  for (var index = 0; index < items.length; index++) {
    final item = items[index];
    await executor.insert('summary_items', {
      'id': item.id,
      'summary_id': summaryId,
      'kind': kind,
      'position': index,
      'text': item.text,
    });
    for (
      var evidenceIndex = 0;
      evidenceIndex < item.evidence.length;
      evidenceIndex++
    ) {
      final evidence = item.evidence[evidenceIndex];
      await executor.insert('summary_evidence', {
        'item_id': item.id,
        'position': evidenceIndex,
        'segment_id': evidence.segmentId,
        'start_ms': evidence.startMs,
        'end_ms': evidence.endMs,
        'quote': evidence.quote,
      });
    }
  }
}

Future<Summary> _summaryFromRow(
  DatabaseExecutor executor,
  Map<String, Object?> row,
) async {
  final itemRows = await executor.query(
    'summary_items',
    where: 'summary_id = ?',
    whereArgs: [row['id']],
    orderBy: 'kind, position',
  );
  final keyPoints = <SummaryItem>[];
  final actionItems = <SummaryItem>[];
  for (final itemRow in itemRows) {
    final evidenceRows = await executor.query(
      'summary_evidence',
      where: 'item_id = ?',
      whereArgs: [itemRow['id']],
      orderBy: 'position',
    );
    final item = SummaryItem(
      id: itemRow['id']! as String,
      text: itemRow['text']! as String,
      evidence: evidenceRows
          .map(
            (evidence) => SummaryEvidence(
              segmentId: evidence['segment_id']! as String,
              startMs: evidence['start_ms']! as int,
              endMs: evidence['end_ms']! as int,
              quote: evidence['quote']! as String,
            ),
          )
          .toList(),
    );
    if (itemRow['kind'] == 'keyPoint') {
      keyPoints.add(item);
    } else {
      actionItems.add(item);
    }
  }

  return Summary(
    id: row['id']! as String,
    meetingId: row['meeting_id']! as String,
    transcriptSnapshotId: row['transcript_snapshot_id']! as String,
    provider: row['provider']! as String,
    model: row['model']! as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at']! as int,
      isUtc: true,
    ),
    overview: row['overview']! as String,
    keyPoints: keyPoints,
    actionItems: actionItems,
    status: SummaryStatus.values.byName(row['status']! as String),
  );
}
