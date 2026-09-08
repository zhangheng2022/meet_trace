import 'dart:convert';

import '../../domain/models/transcription_profile.dart';
import '../../domain/ports/transcription_profiles.dart';
import '../services/storage/app_database.dart';

final class SqfliteTranscriptionProfileRepository
    implements TranscriptionProfileRepository {
  SqfliteTranscriptionProfileRepository(this.database);

  static const _defaultKey = 'default_transcription_profile_id';
  final AppDatabase database;

  @override
  Future<List<TranscriptionProfile>> list() async {
    final db = await database.open();
    final rows = await db.query('transcription_profiles', orderBy: 'id');
    return [TranscriptionProfile.local(), for (final row in rows) _decode(row)];
  }

  @override
  Future<TranscriptionProfile?> getById(String id) async {
    if (id == TranscriptionProfile.localProfileId) {
      return TranscriptionProfile.local();
    }
    final db = await database.open();
    final rows = await db.query(
      'transcription_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _decode(rows.single);
  }

  @override
  Future<void> save(TranscriptionProfile profile) async {
    if (profile.isLocal || profile.id == TranscriptionProfile.localProfileId) {
      throw ArgumentError('固定本地配置不能写入用户在线配置表');
    }
    final db = await database.open();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'transcription_profiles',
        where: 'id = ?',
        whereArgs: [profile.id],
      );
      if (rows.isNotEmpty) {
        final previous = _decode(rows.single);
        if (previous.hasSameConfiguration(profile)) return;
        if (profile.revision <= previous.revision) {
          throw StateError('配置修订号必须递增，拒绝覆盖旧版本');
        }
      }
      final row = {
        'id': profile.id,
        'revision': profile.revision,
        'configuration_json': jsonEncode(profile.toJson()),
      };
      if (rows.isEmpty) {
        await txn.insert('transcription_profiles', row);
      } else {
        await txn.update(
          'transcription_profiles',
          row,
          where: 'id = ?',
          whereArgs: [profile.id],
        );
      }
    });
  }

  @override
  Future<void> delete(String id) async {
    if (id == TranscriptionProfile.localProfileId) {
      throw ArgumentError('不能删除固定本地配置');
    }
    final db = await database.open();
    await db.transaction((txn) async {
      await txn.delete(
        'transcription_profiles',
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'app_settings',
        where: 'key = ? AND value = ?',
        whereArgs: [_defaultKey, id],
      );
    });
  }

  @override
  Future<String> getDefaultProfileId() async {
    final db = await database.open();
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_defaultKey],
    );
    if (rows.isEmpty) return TranscriptionProfile.localProfileId;
    final id = rows.single['value']! as String;
    return await getById(id) == null ? TranscriptionProfile.localProfileId : id;
  }

  @override
  Future<void> setDefaultProfileId(String id) async {
    final db = await database.open();
    await db.transaction((txn) async {
      if (id != TranscriptionProfile.localProfileId) {
        final rows = await txn.query(
          'transcription_profiles',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows.isEmpty) throw StateError('所选转录配置不存在');
      }
      final row = {
        'value': id,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      };
      final updated = await txn.update(
        'app_settings',
        row,
        where: 'key = ?',
        whereArgs: [_defaultKey],
      );
      if (updated == 0) {
        await txn.insert('app_settings', {'key': _defaultKey, ...row});
      }
    });
  }
}

TranscriptionProfile _decode(Map<String, Object?> row) =>
    TranscriptionProfile.fromJson(
      jsonDecode(row['configuration_json']! as String) as Map<String, Object?>,
    );
