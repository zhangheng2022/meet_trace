import '../data/repositories/sqflite_diarization_preference_repository.dart';
import '../data/repositories/sqflite_meeting_repository.dart';
import '../data/repositories/sqflite_model_installation_repository.dart';
import '../data/repositories/sqflite_model_preference_repository.dart';
import '../data/repositories/sqflite_model_usage_lease_repository.dart';
import '../data/repositories/sqflite_processing_task_repository.dart';
import '../data/repositories/sqflite_recording_input_preference_repository.dart';
import '../data/repositories/sqflite_transcript_repository.dart';
import '../data/services/storage/app_database.dart';
import '../data/services/storage/app_file_layout.dart';
import '../data/services/storage/local_data_generation_gate.dart';
import '../data/services/storage/platform_database_factory.dart';
import '../data/services/storage/startup_recovery_service.dart';
import '../domain/models/asr_model_registry.dart';

final class StorageDependencies {
  const StorageDependencies._({
    required this.database,
    required this.fileLayout,
    required this.meetings,
    required this.transcripts,
    required this.installations,
    required this.preferences,
    required this.recordingInputPreferences,
    required this.diarizationPreferences,
    required this.processingTasks,
    required this.leases,
  });

  final AppDatabase database;
  final AppFileLayout fileLayout;
  final SqfliteMeetingRepository meetings;
  final SqfliteTranscriptRepository transcripts;
  final SqfliteModelInstallationRepository installations;
  final SqfliteModelPreferenceRepository preferences;
  final SqfliteRecordingInputPreferenceRepository recordingInputPreferences;
  final SqfliteDiarizationPreferenceRepository diarizationPreferences;
  final SqfliteProcessingTaskRepository processingTasks;
  final SqfliteModelUsageLeaseRepository leases;

  static Future<StorageDependencies> create({
    required AsrModelRegistry registry,
  }) async {
    final fileLayout = await AppFileLayout.forApplication();
    // 数据代门必须先于数据库打开与运行资源初始化：旧数据代一律全清。
    await LocalDataGenerationGate(layout: fileLayout).ensureCurrent();
    await fileLayout.createBaseDirectories();
    final database = AppDatabase(
      databaseFactory: createPlatformDatabaseFactory(),
      path: fileLayout.databasePath,
    );
    SqfliteMeetingRepository? meetings;
    SqfliteModelInstallationRepository? installations;
    try {
      await StartupRecoveryService(
        database: database,
        layout: fileLayout,
      ).recover(now: DateTime.now());
      meetings = SqfliteMeetingRepository(database);
      final transcripts = SqfliteTranscriptRepository(
        database,
        onMeetingChanged: meetings.notifyChanged,
      );
      installations = SqfliteModelInstallationRepository(database);
      return StorageDependencies._(
        database: database,
        fileLayout: fileLayout,
        meetings: meetings,
        transcripts: transcripts,
        installations: installations,
        preferences: SqfliteModelPreferenceRepository(
          database,
          registry: registry,
        ),
        recordingInputPreferences: SqfliteRecordingInputPreferenceRepository(
          database,
        ),
        diarizationPreferences: SqfliteDiarizationPreferenceRepository(
          database,
        ),
        processingTasks: SqfliteProcessingTaskRepository(database),
        leases: SqfliteModelUsageLeaseRepository(database),
      );
    } on Object catch (error, stackTrace) {
      await _disposeStorage([
        if (meetings != null) meetings.dispose,
        if (installations != null) installations.dispose,
        database.close,
      ], preserveError: true);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> dispose() async {
    await _disposeStorage([
      meetings.dispose,
      installations.dispose,
      database.close,
    ]);
  }
}

Future<void> _disposeStorage(
  List<Future<void> Function()> actions, {
  bool preserveError = false,
}) async {
  Object? firstError;
  StackTrace? firstStackTrace;
  for (final action in actions) {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
  }
  if (!preserveError && firstError != null) {
    Error.throwWithStackTrace(firstError, firstStackTrace!);
  }
}
