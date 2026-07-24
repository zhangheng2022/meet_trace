import '../../domain/models/processing_task.dart';
import '../models/storage/storage_mappers.dart';
import '../services/storage/app_database.dart';
import 'repository_contracts.dart';

final class SqfliteProcessingTaskRepository
    implements ProcessingTaskRepository {
  SqfliteProcessingTaskRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<ProcessingTask?> getById(String taskId) async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'processing_tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    return rows.isEmpty ? null : processingTaskFromRow(rows.single);
  }

  @override
  Future<List<ProcessingTask>> listByMeeting(String meetingId) async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'processing_tasks',
      where: 'meeting_id = ?',
      whereArgs: [meetingId],
      orderBy: 'created_at, id',
    );
    return List.unmodifiable(rows.map(processingTaskFromRow));
  }

  @override
  Future<void> save(ProcessingTask task) async {
    final db = await _appDatabase.open();
    final row = processingTaskToRow(task);
    await db.transaction((txn) async {
      final updated = await txn.update(
        'processing_tasks',
        row,
        where: 'id = ?',
        whereArgs: [task.id],
      );
      if (updated == 0) {
        await txn.insert('processing_tasks', row);
      }
    });
  }
}
