import 'dart:async';

import '../../domain/models/meeting.dart';
import '../models/storage/storage_mappers.dart';
import '../services/storage/app_database.dart';
import 'repository_contracts.dart';

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
  Future<void> delete(String meetingId) async {
    final db = await _appDatabase.open();
    await db.delete('meetings', where: 'id = ?', whereArgs: [meetingId]);
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
