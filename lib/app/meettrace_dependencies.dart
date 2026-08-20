import '../domain/models/asr_model_registry.dart';
import 'meettrace_meeting_dependencies.dart';
import 'meettrace_runtime_dependencies.dart';
import 'meettrace_storage_dependencies.dart';
import 'meettrace_update_dependencies.dart';

final class MeetTraceDependencies {
  const MeetTraceDependencies._({
    required this.storage,
    required this.runtime,
    required this.meeting,
    required this.updates,
  });

  final StorageDependencies storage;
  final RuntimeAssetDependencies runtime;
  final MeetingDependencies meeting;
  final UpdateDependencies? updates;

  static Future<MeetTraceDependencies> create() async {
    StorageDependencies? storage;
    RuntimeAssetDependencies? runtime;
    MeetingDependencies? meeting;
    UpdateDependencies? updates;
    try {
      final registry = AsrModelRegistry.alpha;
      storage = await StorageDependencies.create(registry: registry);
      runtime = await RuntimeAssetDependencies.create(
        registry: registry,
        storage: storage,
      );
      meeting = MeetingDependencies.create(storage: storage, runtime: runtime);
      try {
        updates = UpdateDependencies.create(storage: storage);
      } on Object {
        // 更新能力不得阻断启动、事实录音或本地历史访问。
        updates = null;
      }
      return MeetTraceDependencies._(
        storage: storage,
        runtime: runtime,
        meeting: meeting,
        updates: updates,
      );
    } on Object catch (error, stackTrace) {
      await _disposeAll([
        if (meeting != null) meeting.dispose,
        if (updates != null) updates.dispose,
        if (runtime != null) runtime.dispose,
        if (storage != null) storage.dispose,
      ], preserveError: true);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> dispose() async {
    await _disposeAll([
      meeting.dispose,
      if (updates != null) updates!.dispose,
      runtime.dispose,
      storage.dispose,
    ]);
  }
}

Future<void> _disposeAll(
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
