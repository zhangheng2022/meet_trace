import 'dart:async';

import '../../../domain/models/audio_source.dart';
import '../../../domain/models/meeting.dart';
import '../../../domain/models/transcript.dart';
import '../../repositories/repository_contracts.dart';
import 'asr_engine.dart';

typedef FinalTranscriptionSnapshotIdFactory =
    String Function(String meetingId, DateTime createdAt);
typedef FinalTranscriptionProgressCallback =
    void Function(AsrFinalizationProgress progress);

final class FinalTranscriptionException implements Exception {
  const FinalTranscriptionException(this.code);

  final String code;

  @override
  String toString() => 'FinalTranscriptionException: $code';
}

final class FinalTranscriptionResult {
  const FinalTranscriptionResult({
    required this.meeting,
    required this.snapshot,
  });

  final Meeting meeting;
  final TranscriptSnapshot snapshot;
}

abstract interface class FinalTranscriptionRunner {
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? modelId,
    String? modelVersion,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  });
}

/// 只从已封存的事实音频创建最终快照，不接收或读取会中预览文本。
final class FinalTranscriptionService implements FinalTranscriptionRunner {
  FinalTranscriptionService({
    required this.meetings,
    required this.transcripts,
    required this.engineFactory,
    required this.now,
    FinalTranscriptionSnapshotIdFactory? snapshotIdFactory,
  }) : snapshotIdFactory =
           snapshotIdFactory ??
           ((meetingId, createdAt) =>
               'final-$meetingId-${createdAt.microsecondsSinceEpoch}');

  final MeetingRepository meetings;
  final TranscriptRepository transcripts;
  final AsrEngineFactory engineFactory;
  final DateTime Function() now;
  final FinalTranscriptionSnapshotIdFactory snapshotIdFactory;

  @override
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? modelId,
    String? modelVersion,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  }) async {
    final meeting = await meetings.getById(meetingId);
    if (meeting == null) {
      throw const FinalTranscriptionException(
        'final_transcription.meeting_not_found',
      );
    }
    final selected = _selectedModel(
      meeting,
      modelId: modelId,
      modelVersion: modelVersion,
    );

    final retryId = retrySnapshotId?.trim();
    if (retryId != null && retryId.isNotEmpty) {
      final existing = await transcripts.getById(retryId);
      if (existing != null) {
        _validateRetry(existing, meeting: meeting, selected: selected);
        if (existing.status == TranscriptSnapshotStatus.complete &&
            meeting.activeTranscriptSnapshotId == existing.id) {
          return FinalTranscriptionResult(meeting: meeting, snapshot: existing);
        }
      }
    }

    final processingMeeting = meeting.beginFinalTranscription();
    if (processingMeeting.status != meeting.status ||
        processingMeeting.lastErrorCode != meeting.lastErrorCode) {
      await meetings.save(processingMeeting);
    }

    final createdAt = now();
    final snapshotId = retryId?.isNotEmpty == true
        ? retryId!
        : snapshotIdFactory(meeting.id, createdAt);
    final processingSnapshot = TranscriptSnapshot(
      id: snapshotId,
      meetingId: meeting.id,
      kind: TranscriptSnapshotKind.finalTranscript,
      actualModelId: selected.$1,
      actualModelVersion: selected.$2,
      createdAt: createdAt,
      status: TranscriptSnapshotStatus.processing,
      segments: const [],
    );
    await transcripts.save(processingSnapshot);

    AsrEngine? engine;
    StreamSubscription<AsrFinalizationProgress>? progressSubscription;
    try {
      engine = await engineFactory.create(
        modelId: selected.$1,
        modelVersion: selected.$2,
      );
      _validateEngine(engine, selected);
      if (onProgress != null) {
        progressSubscription = engine.finalizationProgress.listen(onProgress);
      }
      await engine.initialize();
      final completed = await engine.finalizeMeeting(
        AudioSource(
          path: processingMeeting.audioPath!,
          durationMs: processingMeeting.audioDurationMs,
        ),
        meetingId: processingMeeting.id,
        snapshotId: snapshotId,
      );
      _validateCompleted(
        completed,
        meeting: processingMeeting,
        selected: selected,
        snapshotId: snapshotId,
      );
      await transcripts.saveFinalAndActivate(
        snapshot: completed,
        expectedActiveSnapshotId: meeting.activeTranscriptSnapshotId,
      );
      return FinalTranscriptionResult(
        meeting: processingMeeting.activateFinalTranscript(completed),
        snapshot: completed,
      );
    } on Object catch (error, stackTrace) {
      final failed = TranscriptSnapshot(
        id: snapshotId,
        meetingId: meeting.id,
        kind: TranscriptSnapshotKind.finalTranscript,
        actualModelId: selected.$1,
        actualModelVersion: selected.$2,
        createdAt: createdAt,
        status: TranscriptSnapshotStatus.failed,
        segments: const [],
      );
      await transcripts.save(failed);
      await meetings.save(processingMeeting.fail(errorCode: _errorCode(error)));
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      await progressSubscription?.cancel();
      await engine?.dispose();
    }
  }

  (String, String) _selectedModel(
    Meeting meeting, {
    required String? modelId,
    required String? modelVersion,
  }) {
    final hasModelId = modelId?.trim().isNotEmpty == true;
    final hasVersion = modelVersion?.trim().isNotEmpty == true;
    if (hasModelId != hasVersion) {
      throw const FinalTranscriptionException(
        'final_transcription.incomplete_model_selection',
      );
    }
    return hasModelId
        ? (modelId!.trim(), modelVersion!.trim())
        : (meeting.recordingModelId, meeting.recordingModelVersion);
  }

  void _validateRetry(
    TranscriptSnapshot snapshot, {
    required Meeting meeting,
    required (String, String) selected,
  }) {
    if (snapshot.meetingId != meeting.id ||
        snapshot.kind != TranscriptSnapshotKind.finalTranscript ||
        snapshot.actualModelId != selected.$1 ||
        snapshot.actualModelVersion != selected.$2) {
      throw const FinalTranscriptionException(
        'final_transcription.retry_snapshot_mismatch',
      );
    }
  }

  void _validateEngine(AsrEngine engine, (String, String) selected) {
    if (engine.descriptor.modelId != selected.$1 ||
        engine.descriptor.version != selected.$2) {
      throw const FinalTranscriptionException(
        'final_transcription.engine_model_mismatch',
      );
    }
  }

  void _validateCompleted(
    TranscriptSnapshot snapshot, {
    required Meeting meeting,
    required (String, String) selected,
    required String snapshotId,
  }) {
    if (snapshot.id != snapshotId ||
        snapshot.meetingId != meeting.id ||
        snapshot.kind != TranscriptSnapshotKind.finalTranscript ||
        snapshot.status != TranscriptSnapshotStatus.complete ||
        snapshot.actualModelId != selected.$1 ||
        snapshot.actualModelVersion != selected.$2) {
      throw const FinalTranscriptionException(
        'final_transcription.snapshot_mismatch',
      );
    }

    TranscriptSegment? previous;
    for (final segment in snapshot.segments) {
      if (segment.startMs < 0 ||
          segment.endMs > meeting.audioDurationMs ||
          segment.endMs <= segment.startMs) {
        throw const FinalTranscriptionException(
          'final_transcription.segment_out_of_bounds',
        );
      }
      if (previous != null && segment.startMs < previous.endMs) {
        throw const FinalTranscriptionException(
          'final_transcription.segment_overlap',
        );
      }
      previous = segment;
    }
  }

  String _errorCode(Object error) {
    return switch (error) {
      AsrEngineException(:final failure) => failure.code,
      FinalTranscriptionException(:final code) => code,
      _ => 'final_transcription.unexpected',
    };
  }
}
