import 'package:meetily_ai/data/repositories/repository_contracts.dart';
import 'package:meetily_ai/data/services/asr/asr_engine.dart';
import 'package:meetily_ai/data/services/asr/final_transcription_service.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
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
