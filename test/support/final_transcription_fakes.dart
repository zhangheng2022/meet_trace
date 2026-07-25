import 'package:meetily_ai/data/repositories/repository_contracts.dart';
import 'package:meetily_ai/data/services/asr/asr_engine.dart';
import 'package:meetily_ai/data/services/asr/final_transcription_service.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
import 'package:meetily_ai/domain/models/processing_task.dart';
import 'package:meetily_ai/domain/models/summary.dart';
import 'package:meetily_ai/domain/models/transcript.dart';

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

final class DetailSummaryRepository implements SummaryRepository {
  DetailSummaryRepository(this.meetings);

  final DetailMeetingRepository meetings;
  final Map<String, Summary> records = {};

  @override
  Future<Summary?> getById(String summaryId) async => records[summaryId];

  @override
  Future<List<Summary>> listByMeeting(String meetingId) async => records.values
      .where((summary) => summary.meetingId == meetingId)
      .toList();

  @override
  Future<void> save(Summary summary) async {
    records[summary.id] = summary;
  }

  @override
  Future<void> saveAndActivate({
    required Summary summary,
    required String expectedTranscriptSnapshotId,
  }) async {
    final meeting = meetings.value;
    if (meeting == null ||
        meeting.activeTranscriptSnapshotId != expectedTranscriptSnapshotId) {
      throw StateError('最终转录已变化');
    }
    records[summary.id] = summary;
    meetings.value = Meeting(
      id: meeting.id,
      title: meeting.title,
      createdAt: meeting.createdAt,
      startedAt: meeting.startedAt,
      endedAt: meeting.endedAt,
      status: meeting.status,
      audioPath: meeting.audioPath,
      audioDurationMs: meeting.audioDurationMs,
      requestedModelId: meeting.requestedModelId,
      recordingModelId: meeting.recordingModelId,
      recordingModelVersion: meeting.recordingModelVersion,
      modelFallbackReason: meeting.modelFallbackReason,
      activeTranscriptSnapshotId: meeting.activeTranscriptSnapshotId,
      activeSummaryId: summary.id,
      lastErrorCode: meeting.lastErrorCode,
    );
  }
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

typedef DetailTranscriptionCall =
    Future<FinalTranscriptionResult> Function({
      required String meetingId,
      required String? modelId,
      required String? modelVersion,
      required String? retrySnapshotId,
      required FinalTranscriptionProgressCallback? onProgress,
    });

final class DetailTranscriptionRunner implements FinalTranscriptionRunner {
  DetailTranscriptionRunner(this.onCall);

  DetailTranscriptionCall onCall;
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
    String? modelId,
    String? modelVersion,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  }) {
    calls.add((
      meetingId: meetingId,
      modelId: modelId,
      modelVersion: modelVersion,
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
      modelId: modelId,
      modelVersion: modelVersion,
      retrySnapshotId: retrySnapshotId,
      onProgress: onProgress,
    );
  }
}
