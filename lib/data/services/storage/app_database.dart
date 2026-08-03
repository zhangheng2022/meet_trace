import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final class AppDatabase {
  AppDatabase({required this.databaseFactory, required this.path});

  static const schemaVersion = 6;

  final DatabaseFactory databaseFactory;
  final String path;

  Database? _database;

  Future<Database> open() async {
    final current = _database;
    if (current != null && current.isOpen) {
      return current;
    }

    if (path != inMemoryDatabasePath) {
      await Directory(p.dirname(path)).create(recursive: true);
    }
    final database = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    _database = database;
    return database;
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    if (current != null && current.isOpen) {
      await current.close();
    }
  }

  static Future<void> _createSchema(Database db, int version) async {
    await _createVersion1Schema(db);
    if (version >= 2) {
      await _createVersion2Schema(db);
    }
    if (version >= 3) {
      await _createVersion3Schema(db);
    }
    if (version >= 4) {
      await _createVersion4Schema(db);
    }
  }

  static Future<void> _createVersion1Schema(Database db) async {
    await db.execute('''
      CREATE TABLE meetings (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        started_at INTEGER,
        ended_at INTEGER,
        status TEXT NOT NULL,
        audio_path TEXT,
        audio_duration_ms INTEGER NOT NULL CHECK(audio_duration_ms >= 0),
        recording_model_id TEXT NOT NULL,
        recording_model_version TEXT NOT NULL,
        recording_model_language TEXT NOT NULL,
        recording_model_use_itn INTEGER NOT NULL
          CHECK(recording_model_use_itn IN (0, 1)),
        active_transcript_snapshot_id TEXT,
        active_summary_id TEXT,
        last_error_code TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE transcript_snapshots (
        id TEXT PRIMARY KEY,
        meeting_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        actual_model_id TEXT NOT NULL,
        actual_model_version TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE transcript_segments (
        id TEXT PRIMARY KEY,
        snapshot_id TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        text TEXT NOT NULL,
        speaker_id TEXT,
        confidence REAL,
        model_id TEXT NOT NULL,
        model_version TEXT NOT NULL,
        FOREIGN KEY(snapshot_id)
          REFERENCES transcript_snapshots(id) ON DELETE CASCADE,
        CHECK(start_ms >= 0 AND end_ms > start_ms)
      )
    ''');
    await db.execute('''
      CREATE TABLE summaries (
        id TEXT PRIMARY KEY,
        meeting_id TEXT NOT NULL,
        transcript_snapshot_id TEXT NOT NULL,
        provider TEXT NOT NULL,
        model TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        overview TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(meeting_id) REFERENCES meetings(id) ON DELETE CASCADE,
        FOREIGN KEY(transcript_snapshot_id)
          REFERENCES transcript_snapshots(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE summary_items (
        id TEXT PRIMARY KEY,
        summary_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        position INTEGER NOT NULL,
        text TEXT NOT NULL,
        FOREIGN KEY(summary_id) REFERENCES summaries(id) ON DELETE CASCADE,
        UNIQUE(summary_id, kind, position)
      )
    ''');
    await db.execute('''
      CREATE TABLE summary_evidence (
        item_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        segment_id TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        quote TEXT NOT NULL,
        PRIMARY KEY(item_id, position),
        FOREIGN KEY(item_id) REFERENCES summary_items(id) ON DELETE CASCADE,
        FOREIGN KEY(segment_id)
          REFERENCES transcript_segments(id) ON DELETE CASCADE,
        CHECK(start_ms >= 0 AND end_ms > start_ms)
      )
    ''');
    await db.execute('''
      CREATE TABLE model_installations (
        model_id TEXT NOT NULL,
        version TEXT NOT NULL,
        installation_type TEXT NOT NULL,
        state TEXT NOT NULL,
        installed_path TEXT,
        verified_at INTEGER,
        bytes INTEGER NOT NULL CHECK(bytes >= 0),
        last_error_code TEXT,
        PRIMARY KEY(model_id, version)
      )
    ''');
    await db.execute('''
      CREATE TABLE processing_tasks (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        meeting_id TEXT,
        model_id TEXT,
        state TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        lease_expires_at INTEGER,
        last_error_code TEXT,
        FOREIGN KEY(meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_snapshots_meeting '
      'ON transcript_snapshots(meeting_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_segments_snapshot '
      'ON transcript_segments(snapshot_id, start_ms, end_ms)',
    );
    await db.execute(
      'CREATE INDEX idx_tasks_state_lease '
      'ON processing_tasks(state, lease_expires_at)',
    );
  }

  static Future<void> _createVersion2Schema(Database db) async {
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createVersion3Schema(Database db) async {
    await db.execute('''
      CREATE TABLE active_model_versions (
        model_id TEXT PRIMARY KEY,
        version TEXT NOT NULL,
        FOREIGN KEY(model_id, version)
          REFERENCES model_installations(model_id, version) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE model_usage_leases (
        lease_id TEXT PRIMARY KEY,
        model_id TEXT NOT NULL,
        version TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        acquired_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        FOREIGN KEY(model_id, version)
          REFERENCES model_installations(model_id, version) ON DELETE CASCADE,
        CHECK(expires_at > acquired_at)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_model_usage_leases_active '
      'ON model_usage_leases(model_id, version, expires_at)',
    );
  }

  static Future<void> _createVersion4Schema(Database db) async {
    final summaries = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name = 'summaries'",
    );
    if (summaries.isNotEmpty) {
      await db.execute(
        "ALTER TABLE summaries ADD COLUMN title TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      await _createSchema(db, newVersion);
      return;
    }
    if (oldVersion < 6 && newVersion >= 6) {
      // 单模型基线已删除两个遗留模型选择列（见架构守卫 legacy_schema_guard_test）；
      // 旧数据库不做原地迁移，由数据代门在启动前全清。
      throw const UnsupportedAlphaInstallationException();
    }
    if (oldVersion < 2 && newVersion >= 2) {
      await _createVersion2Schema(db);
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await _createVersion3Schema(db);
    }
    if (oldVersion < 4 && newVersion >= 4) {
      await _createVersion4Schema(db);
    }
  }
}

final class UnsupportedAlphaInstallationException implements Exception {
  const UnsupportedAlphaInstallationException();

  @override
  String toString() => '当前 Alpha 数据基线不支持原地升级；请先导出重要内容，再卸载或清除应用数据。';
}
