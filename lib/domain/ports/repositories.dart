import '../models/app_theme.dart';
import '../models/app_language.dart';
import '../models/meeting.dart';
import '../models/model_installation.dart';
import '../models/model_usage_lease.dart';
import '../models/processing_task.dart';
import '../models/transcript.dart';

abstract interface class MeetingRepository {
  Future<Meeting?> getById(String meetingId);

  Stream<List<Meeting>> watchAll();

  /// 保存会议生命周期数据；现有会议标题只能通过 [updateTitle] 修改。
  Future<void> save(Meeting meeting);

  Future<Meeting> updateTitle({
    required String meetingId,
    required String title,
  });

  Future<void> delete(String meetingId);
}

abstract interface class TranscriptRepository {
  Future<TranscriptSnapshot?> getById(String snapshotId);

  Future<List<TranscriptSnapshot>> listByMeeting(String meetingId);

  Future<TranscriptSnapshot?> getLatestByMeeting({
    required String meetingId,
    required TranscriptSnapshotKind kind,
    required TranscriptSnapshotStatus status,
  });

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

abstract interface class ThemePreferenceRepository {
  Future<AppThemeMode> getThemeMode();

  Future<void> setThemeMode(AppThemeMode mode);
}

abstract interface class LanguagePreferenceRepository {
  Future<AppLanguageMode> getLanguageMode();

  Future<void> setLanguageMode(AppLanguageMode mode);
}

/// 本机诊断偏好端口。
///
/// 平台存储异常由实现原样传播；调用方必须设置超时，并将读取失败按 `false` 处理。
abstract interface class RemoteDiagnosticsPreferenceRepository {
  Future<bool> getEnabled();

  Future<void> setEnabled(bool enabled);
}

abstract interface class RemoteDiagnosticsController {
  /// 请求当前构建应用诊断偏好；返回该请求是否被接受。
  ///
  /// 编译期未包含诊断能力的构建应将开启视为成功的无操作，避免覆盖用户偏好。
  /// 实现必须在有界时间内完成，并将 SDK 故障转换为 `false`。
  Future<bool> setEnabled(bool enabled);
}

abstract interface class ProcessingTaskRepository {
  Future<ProcessingTask?> getById(String taskId);

  Future<List<ProcessingTask>> listByMeeting(String meetingId);

  Future<void> save(ProcessingTask task);
}
