import 'dart:async';

import '../models/audio_source.dart';
import '../models/meeting.dart';
import '../models/transcript.dart';
import '../models/workflow_states.dart';
import '../ports/asr_engine.dart';
import '../ports/final_transcription.dart';
import '../ports/repositories.dart';

export '../ports/final_transcription.dart';

typedef FinalTranscriptionSnapshotIdFactory =
    String Function(String meetingId, DateTime createdAt);

final class FinalTranscriptionException implements Exception {
  const FinalTranscriptionException(this.code);

  final String code;

  @override
  String toString() => 'FinalTranscriptionException: $code';
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
  final Map<String, Future<FinalTranscriptionResult>> _meetingOperations = {};

  @override
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? modelId,
    String? modelVersion,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  }) {
    final previous = _meetingOperations[meetingId];
    late final Future<FinalTranscriptionResult> operation;
    operation = _runAfter(
      previous,
      meetingId: meetingId,
      modelId: modelId,
      modelVersion: modelVersion,
      retrySnapshotId: retrySnapshotId,
      onProgress: onProgress,
    );
    _meetingOperations[meetingId] = operation;
    return operation.whenComplete(() {
      if (identical(_meetingOperations[meetingId], operation)) {
        _meetingOperations.remove(meetingId);
      }
    });
  }

  Future<FinalTranscriptionResult> _runAfter(
    Future<FinalTranscriptionResult>? previous, {
    required String meetingId,
    required String? modelId,
    required String? modelVersion,
    required String? retrySnapshotId,
    required FinalTranscriptionProgressCallback? onProgress,
  }) async {
    if (previous != null) {
      try {
        await previous;
      } on Object {
        // 前一次失败不阻止同一会议的显式重试。
      }
    }
    return _transcribe(
      meetingId: meetingId,
      modelId: modelId,
      modelVersion: modelVersion,
      retrySnapshotId: retrySnapshotId,
      onProgress: onProgress,
    );
  }

  Future<FinalTranscriptionResult> _transcribe({
    required String meetingId,
    required String? modelId,
    required String? modelVersion,
    required String? retrySnapshotId,
    required FinalTranscriptionProgressCallback? onProgress,
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
      await _saveFailureIfCurrent(
        originalMeeting: meeting,
        errorCode: _errorCode(error),
      );
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      try {
        await progressSubscription?.cancel();
      } on Object {
        // 监听器清理失败不得覆盖已经确定的最终转录结果。
      }
      try {
        await engine?.dispose();
      } on Object {
        // Engine 释放异常只影响诊断，不能把已原子激活的快照改判为失败。
      }
    }
  }

  Future<void> _saveFailureIfCurrent({
    required Meeting originalMeeting,
    required String errorCode,
  }) async {
    final current = await meetings.getById(originalMeeting.id);
    if (current == null ||
        current.status != MeetingState.processing ||
        current.activeTranscriptSnapshotId !=
            originalMeeting.activeTranscriptSnapshotId) {
      return;
    }
    await meetings.save(current.fail(errorCode: errorCode));
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
