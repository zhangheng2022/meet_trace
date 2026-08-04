import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final class AppDatabase {
  AppDatabase({required this.databaseFactory, required this.path});

  static const schemaVersion = 7;

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
    final existingTables = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' "
      "AND name <> 'android_metadata'",
    );
    if (existingTables.isNotEmpty) {
      throw const UnsupportedAlphaInstallationException();
    }
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
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
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
    await db.execute(
      'CREATE INDEX idx_model_usage_leases_active '
      'ON model_usage_leases(model_id, version, expires_at)',
    );
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion != newVersion) {
      throw const UnsupportedAlphaInstallationException();
    }
  }
}

final class UnsupportedAlphaInstallationException implements Exception {
  const UnsupportedAlphaInstallationException();

  @override
  String toString() => '当前 Alpha 数据基线不支持原地升级；请先导出重要内容，再卸载或清除应用数据。';
}
