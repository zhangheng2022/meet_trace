import 'dart:async';

import '../../domain/models/meeting.dart';
import '../../domain/models/domain_exception.dart';
import '../models/storage/storage_mappers.dart';
import '../services/storage/app_database.dart';
import '../../domain/ports/repositories.dart';

final class SqfliteMeetingRepository implements MeetingRepository {
  SqfliteMeetingRepository(this._appDatabase);

  final AppDatabase _appDatabase;
  final StreamController<void> _changes = StreamController.broadcast();

  @override
  Future<Meeting?> getById(String meetingId) async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'meetings',
      where: 'id = ?',
      whereArgs: [meetingId],
      limit: 1,
    );
    return rows.isEmpty ? null : meetingFromRow(rows.single);
  }

  Future<List<Meeting>> listAll() async {
    final db = await _appDatabase.open();
    final rows = await db.query('meetings', orderBy: 'created_at DESC, id');
    return List.unmodifiable(rows.map(meetingFromRow));
  }

  @override
  Stream<List<Meeting>> watchAll() async* {
    yield await listAll();
    await for (final _ in _changes.stream) {
      yield await listAll();
    }
  }

  @override
  Future<void> save(Meeting meeting) async {
    final db = await _appDatabase.open();
    await db.transaction((txn) => upsertMeeting(txn, meeting));
    _changes.add(null);
  }

  @override
  Future<Meeting> updateTitle({
    required String meetingId,
    required String title,
  }) async {
    final issue = meetingTitleIssue(title);
    if (issue != null) {
      throw const DomainInvariantViolation('会议标题不符合领域规则');
    }
    final normalizedTitle = normalizeMeetingTitle(title);
    final db = await _appDatabase.open();
    final updatedMeeting = await db.transaction((txn) async {
      final updated = await txn.update(
        'meetings',
        {'title': normalizedTitle},
        where: 'id = ?',
        whereArgs: [meetingId],
      );
      if (updated != 1) {
        throw const DomainInvariantViolation('要重命名的会议不存在');
      }
      final rows = await txn.query(
        'meetings',
        where: 'id = ?',
        whereArgs: [meetingId],
        limit: 1,
      );
      return meetingFromRow(rows.single);
    });
    _changes.add(null);
    return updatedMeeting;
  }

  @override
  Future<void> delete(String meetingId) async {
    final db = await _appDatabase.open();
    await db.delete('meetings', where: 'id = ?', whereArgs: [meetingId]);
    _changes.add(null);
  }

  void notifyChanged() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  Future<void> dispose() => _changes.close();
}
