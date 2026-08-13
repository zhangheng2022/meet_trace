import '../models/meeting.dart';
import '../models/transcript.dart';
import '../models/workflow_states.dart';
import '../ports/repositories.dart';

final class TranscriptSegmentRevision {
  const TranscriptSegmentRevision({
    required this.segmentId,
    required this.text,
    required this.speakerLabel,
  });

  final String segmentId;
  final String text;
  final String? speakerLabel;
}

final class TranscriptRevisionResult {
  const TranscriptRevisionResult({
    required this.meeting,
    required this.snapshot,
  });

  final Meeting meeting;
  final TranscriptSnapshot snapshot;
}

final class TranscriptRevisionException implements Exception {
  const TranscriptRevisionException(this.code);

  final String code;
}

typedef TranscriptRevisionSnapshotIdFactory = String Function(
  TranscriptSnapshot source,
  DateTime createdAt,
);

final class ReviseFinalTranscriptUseCase {
  ReviseFinalTranscriptUseCase({
    required this.meetings,
    required this.transcripts,
    required this.now,
    TranscriptRevisionSnapshotIdFactory? snapshotIdFactory,
  }) : snapshotIdFactory =
           snapshotIdFactory ??
           ((source, createdAt) =>
               'revision-${source.id}-${createdAt.microsecondsSinceEpoch}');

  final MeetingRepository meetings;
  final TranscriptRepository transcripts;
  final DateTime Function() now;
  final TranscriptRevisionSnapshotIdFactory snapshotIdFactory;

  Future<TranscriptRevisionResult> execute({
    required String meetingId,
    required List<TranscriptSegmentRevision> revisions,
  }) async {
    final meeting = await meetings.getById(meetingId);
    final activeSnapshotId = meeting?.activeTranscriptSnapshotId;
    final source = activeSnapshotId == null
        ? null
        : await transcripts.getById(activeSnapshotId);
    if (meeting == null ||
        source == null ||
        meeting.status != MeetingState.completed ||
        source.meetingId != meeting.id ||
        !source.isCurrentFinalTranscript(activeSnapshotId: activeSnapshotId)) {
      throw const TranscriptRevisionException(
        'transcript.revision.not_eligible',
      );
    }
    final revisionsById = <String, TranscriptSegmentRevision>{};
    for (final revision in revisions) {
      final segmentId = revision.segmentId.trim();
      final text = revision.text.trim();
      if (segmentId.isEmpty ||
          text.isEmpty ||
          revisionsById.containsKey(segmentId)) {
        throw const TranscriptRevisionException('transcript.revision.invalid');
      }
      revisionsById[segmentId] = TranscriptSegmentRevision(
        segmentId: segmentId,
        text: text,
        speakerLabel: _normalizedSpeaker(revision.speakerLabel),
      );
    }
    if (revisionsById.length != source.segments.length ||
        source.segments.any(
          (segment) => !revisionsById.containsKey(segment.id),
        )) {
      throw const TranscriptRevisionException('transcript.revision.incomplete');
    }

    final changed = source.segments.any((segment) {
      final revision = revisionsById[segment.id]!;
      return revision.text != segment.text ||
          revision.speakerLabel != segment.speakerId;
    });
    if (!changed) {
      throw const TranscriptRevisionException('transcript.revision.no_changes');
    }

    final createdAt = now().toUtc();
    final snapshotId = snapshotIdFactory(source, createdAt).trim();
    if (snapshotId.isEmpty || snapshotId == source.id) {
      throw const TranscriptRevisionException('transcript.revision.invalid_id');
    }
    final revised = TranscriptSnapshot(
      id: snapshotId,
      meetingId: source.meetingId,
      kind: TranscriptSnapshotKind.finalTranscript,
      actualModelId: source.actualModelId,
      actualModelVersion: source.actualModelVersion,
      createdAt: createdAt,
      status: TranscriptSnapshotStatus.complete,
      segments: [
        for (var index = 0; index < source.segments.length; index++)
          _revisedSegment(
            source.segments[index],
            revisionsById[source.segments[index].id]!,
            snapshotId,
            index,
          ),
      ],
    );
    await transcripts.saveFinalAndActivate(
      snapshot: revised,
      expectedActiveSnapshotId: source.id,
    );
    final refreshed = await meetings.getById(meeting.id);
    if (refreshed == null ||
        refreshed.activeTranscriptSnapshotId != revised.id) {
      throw const TranscriptRevisionException(
        'transcript.revision.activation_failed',
      );
    }
    return TranscriptRevisionResult(meeting: refreshed, snapshot: revised);
  }
}

TranscriptSegment _revisedSegment(
  TranscriptSegment source,
  TranscriptSegmentRevision revision,
  String snapshotId,
  int index,
) {
  return TranscriptSegment(
    id: '$snapshotId-segment-${index + 1}',
    snapshotId: snapshotId,
    startMs: source.startMs,
    endMs: source.endMs,
    text: revision.text,
    speakerId: revision.speakerLabel,
    confidence: source.confidence,
    modelId: source.modelId,
    modelVersion: source.modelVersion,
  );
}

String? _normalizedSpeaker(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
