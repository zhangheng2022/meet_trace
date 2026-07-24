import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final class AppDatabase {
  AppDatabase({required this.databaseFactory, required this.path});

  static const schemaVersion = 2;

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
        requested_model_id TEXT NOT NULL,
        recording_model_id TEXT NOT NULL,
        recording_model_version TEXT NOT NULL,
        model_fallback_reason TEXT,
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

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      await _createSchema(db, newVersion);
      return;
    }
    if (oldVersion < 2 && newVersion >= 2) {
      await _createVersion2Schema(db);
    }
  }
}
