import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/processing_task.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/use_cases/run_final_transcription.dart';

final class DetailMeetingRepository implements MeetingRepository {
  DetailMeetingRepository(this.value);

  Meeting? value;

  @override
  Future<Meeting?> getById(String meetingId) async =>
      value?.id == meetingId ? value : null;

  @override
  Stream<List<Meeting>> watchAll() => Stream.value([?value]);

  @override
  Future<void> save(Meeting meeting) async {
    value = meeting;
  }

  @override
  Future<Meeting> updateTitle({
    required String meetingId,
    required String title,
  }) async {
    final current = await getById(meetingId);
    if (current == null) throw StateError('meeting not found');
    return value = current.rename(title);
  }

  @override
  Future<void> delete(String meetingId) async {
    if (value?.id == meetingId) {
      value = null;
    }
  }
}

final class DetailTranscriptRepository implements TranscriptRepository {
  final Map<String, TranscriptSnapshot> records = {};

  @override
  Future<TranscriptSnapshot?> getById(String snapshotId) async =>
      records[snapshotId];

  @override
  Future<List<TranscriptSnapshot>> listByMeeting(String meetingId) async {
    return records.values
        .where((snapshot) => snapshot.meetingId == meetingId)
        .toList();
  }

  @override
  Future<TranscriptSnapshot?> getLatestByMeeting({
    required String meetingId,
    required TranscriptSnapshotKind kind,
    required TranscriptSnapshotStatus status,
  }) async => _latestSnapshot(
    records.values,
    meetingId: meetingId,
    kind: kind,
    status: status,
  );

  @override
  Future<void> save(TranscriptSnapshot snapshot) async {
    records[snapshot.id] = snapshot;
  }

  @override
  Future<void> saveFinalAndActivate({
    required TranscriptSnapshot snapshot,
    required String? expectedActiveSnapshotId,
  }) async {
    records[snapshot.id] = snapshot;
  }

  @override
  Future<TranscriptSnapshot> updateSpeakerLabels({
    required String snapshotId,
    required Map<String, String?> labelsBySegmentId,
  }) async {
    final snapshot = records[snapshotId]!;
    final updated = TranscriptSnapshot(
      id: snapshot.id,
      meetingId: snapshot.meetingId,
      kind: snapshot.kind,
      actualModelId: snapshot.actualModelId,
      actualModelVersion: snapshot.actualModelVersion,
      createdAt: snapshot.createdAt,
      status: snapshot.status,
      segments: [
        for (final segment in snapshot.segments)
          TranscriptSegment(
            id: segment.id,
            snapshotId: segment.snapshotId,
            startMs: segment.startMs,
            endMs: segment.endMs,
            text: segment.text,
            speakerId: labelsBySegmentId.containsKey(segment.id)
                ? labelsBySegmentId[segment.id]
                : segment.speakerId,
            confidence: segment.confidence,
            modelId: segment.modelId,
            modelVersion: segment.modelVersion,
          ),
      ],
    );
    records[snapshotId] = updated;
    return updated;
  }
}

TranscriptSnapshot? _latestSnapshot(
  Iterable<TranscriptSnapshot> snapshots, {
  required String meetingId,
  required TranscriptSnapshotKind kind,
  required TranscriptSnapshotStatus status,
}) {
  final matches =
      snapshots
          .where(
            (snapshot) =>
                snapshot.meetingId == meetingId &&
                snapshot.kind == kind &&
                snapshot.status == status,
          )
          .toList()
        ..sort((left, right) {
          final byDate = right.createdAt.compareTo(left.createdAt);
          return byDate != 0 ? byDate : right.id.compareTo(left.id);
        });
  return matches.firstOrNull;
}

final class DetailProcessingTaskRepository implements ProcessingTaskRepository {
  final Map<String, ProcessingTask> records = {};

  @override
  Future<ProcessingTask?> getById(String taskId) async => records[taskId];

  @override
  Future<List<ProcessingTask>> listByMeeting(String meetingId) async =>
      records.values.where((task) => task.meetingId == meetingId).toList();

  @override
  Future<void> save(ProcessingTask task) async {
    records[task.id] = task;
  }
}

typedef DetailTranscriptionCall = Future<FinalTranscriptionResult> Function({
  required String meetingId,
  required String? modelId,
  required String? modelVersion,
  required String? retrySnapshotId,
  required FinalTranscriptionProgressCallback? onProgress,
});

final class DetailTranscriptionRunner implements FinalTranscriptionRunner {
  DetailTranscriptionRunner(
    this.onCall, {
    this.lockedModelId = senseVoiceDefaultModelId,
    this.lockedModelVersion = '2024-07-17',
  });

  DetailTranscriptionCall onCall;
  final String lockedModelId;
  final String lockedModelVersion;
  final List<
    ({
      String meetingId,
      String? modelId,
      String? modelVersion,
      String? retrySnapshotId,
    })
  >
  calls = [];

  @override
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  }) {
    calls.add((
      meetingId: meetingId,
      modelId: lockedModelId,
      modelVersion: lockedModelVersion,
      retrySnapshotId: retrySnapshotId,
    ));
    onProgress?.call(
      const AsrFinalizationProgress(
        phase: AsrFinalizationPhase.processing,
        completedSamples: 1,
        totalSamples: 2,
      ),
    );
    return onCall(
      meetingId: meetingId,
      modelId: lockedModelId,
      modelVersion: lockedModelVersion,
      retrySnapshotId: retrySnapshotId,
      onProgress: onProgress,
    );
  }
}
