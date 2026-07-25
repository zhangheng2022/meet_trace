import '../../domain/models/meeting.dart';
import '../../domain/models/model_installation.dart';
import '../../domain/models/model_usage_lease.dart';
import '../../domain/models/processing_task.dart';
import '../../domain/models/summary.dart';
import '../../domain/models/transcript.dart';

abstract interface class MeetingRepository {
  Future<Meeting?> getById(String meetingId);

  Stream<List<Meeting>> watchAll();

  Future<void> save(Meeting meeting);

  Future<void> delete(String meetingId);
}

abstract interface class TranscriptRepository {
  Future<TranscriptSnapshot?> getById(String snapshotId);

  Future<List<TranscriptSnapshot>> listByMeeting(String meetingId);

  Future<void> save(TranscriptSnapshot snapshot);

  Future<void> saveFinalAndActivate({
    required TranscriptSnapshot snapshot,
    required String? expectedActiveSnapshotId,
  });

  Future<TranscriptSnapshot> updateSpeakerLabels({
    required String snapshotId,
    required Map<String, String?> labelsBySegmentId,
  });
}

abstract interface class SummaryRepository {
  Future<Summary?> getById(String summaryId);

  Future<List<Summary>> listByMeeting(String meetingId);

  Future<void> save(Summary summary);
}

abstract interface class ModelInstallationRepository {
  Future<ModelInstallation?> get({
    required String modelId,
    required String version,
  });

  Stream<List<ModelInstallation>> watchAll();

  Future<void> save(ModelInstallation installation);
}

abstract interface class ActiveModelInstallationRepository
    implements ModelInstallationRepository {
  Future<String?> getActiveVersion(String modelId);

  Future<void> saveInstalledAndActivate(ModelInstallation installation);

  Future<void> deleteAndDeactivate({
    required String modelId,
    required String version,
  });
}

abstract interface class ModelUsageLeaseRepository {
  Future<void> save(ModelUsageLease lease);

  Future<void> release(String leaseId);

  Future<List<ModelUsageLease>> listActive({
    required String modelId,
    required String version,
    required DateTime now,
  });

  Future<int> deleteExpired(DateTime now);
}

abstract interface class ModelPreferenceRepository {
  Future<String> getDefaultModelId();

  Future<void> setDefaultModelId(String modelId);
}

abstract interface class DiarizationPreferenceRepository {
  Future<bool> getEnabled();

  Future<void> setEnabled(bool enabled);
}

abstract interface class ProcessingTaskRepository {
  Future<ProcessingTask?> getById(String taskId);

  Future<List<ProcessingTask>> listByMeeting(String meetingId);

  Future<void> save(ProcessingTask task);
}
