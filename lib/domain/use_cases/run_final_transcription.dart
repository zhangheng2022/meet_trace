import 'dart:async';

import '../models/audio_source.dart';
import '../models/meeting.dart';
import '../models/processing_task.dart';
import '../models/speaker_diarization.dart';
import '../models/transcript.dart';
import '../models/workflow_states.dart';
import '../ports/asr_engine.dart';
import '../ports/final_transcription.dart';
import '../ports/repositories.dart';
import '../ports/speaker_diarization.dart';

export '../ports/final_transcription.dart';

typedef FinalTranscriptionSnapshotIdFactory =
    String Function(String meetingId, DateTime createdAt);

final class FinalTranscriptionException implements Exception {
  const FinalTranscriptionException(this.code);

  final String code;

  @override
  String toString() => 'FinalTranscriptionException: $code';
}

/// 从同一份已封存事实音频并行生成 ASR 与说话人结果，并只发布一次快照。
///
/// 会中预览不参与最终结果。说话人分离失败会生成单一说话人标签；ASR 或
/// 最终 CAS 失败则保留事实音频与旧活动快照，不发布半成品。
final class FinalResultCoordinator implements FinalTranscriptionRunner {
  FinalResultCoordinator({
    required this.meetings,
    required this.transcripts,
    required this.tasks,
    required this.engineFactory,
    required this.diarization,
    required this.diarizationPreferences,
    required this.now,
    FinalTranscriptionSnapshotIdFactory? snapshotIdFactory,
    this.diarizationTimeout = const Duration(minutes: 2),
  }) : snapshotIdFactory =
           snapshotIdFactory ??
           ((meetingId, createdAt) =>
               'final-$meetingId-${createdAt.microsecondsSinceEpoch}');

  final MeetingRepository meetings;
  final TranscriptRepository transcripts;
  final ProcessingTaskRepository tasks;
  final AsrEngineFactory engineFactory;
  final SpeakerDiarizationService diarization;
  final DiarizationPreferenceRepository diarizationPreferences;
  final DateTime Function() now;
  final FinalTranscriptionSnapshotIdFactory snapshotIdFactory;
  final Duration diarizationTimeout;
  final Map<String, Future<FinalTranscriptionResult>> _meetingOperations = {};

  static const fallbackSpeakerId = 'speaker-1';

  @override
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  }) {
    final previous = _meetingOperations[meetingId];
    late final Future<FinalTranscriptionResult> operation;
    operation = _runAfter(
      previous,
      meetingId: meetingId,
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
      retrySnapshotId: retrySnapshotId,
      onProgress: onProgress,
    );
  }

  Future<FinalTranscriptionResult> _transcribe({
    required String meetingId,
    required String? retrySnapshotId,
    required FinalTranscriptionProgressCallback? onProgress,
  }) async {
    final meeting = await meetings.getById(meetingId);
    if (meeting == null) {
      throw const FinalTranscriptionException(
        'final_transcription.meeting_not_found',
      );
    }
    final selected = (meeting.recordingModelId, meeting.recordingModelVersion);

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

    final source = AudioSource(
      path: processingMeeting.audioPath!,
      durationMs: processingMeeting.audioDurationMs,
    );
    final diarizationOperation = _runDiarization(
      meetingId: meeting.id,
      snapshotId: snapshotId,
      source: source,
      audioDurationMs: processingMeeting.audioDurationMs,
    );
    final transcriptionOperation = _finalizeTranscript(
      meeting: processingMeeting,
      selected: selected,
      source: source,
      snapshotId: snapshotId,
      onProgress: onProgress,
    );

    try {
      final completed = await transcriptionOperation;
      _validateCompleted(
        completed,
        meeting: processingMeeting,
        selected: selected,
        snapshotId: snapshotId,
      );
      final diarizationResult = await diarizationOperation;
      final publishable = _applyDiarization(completed, diarizationResult);
      await transcripts.saveFinalAndActivate(
        snapshot: publishable,
        expectedActiveSnapshotId: meeting.activeTranscriptSnapshotId,
      );
      return FinalTranscriptionResult(
        meeting: processingMeeting.activateFinalTranscript(publishable),
        snapshot: publishable,
        diarizationStatus: diarizationResult.status,
        diarizationErrorCode: diarizationResult.errorCode,
      );
    } on Object catch (error, stackTrace) {
      await _cancelDiarization();
      await diarizationOperation;
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
    }
  }

  Future<TranscriptSnapshot> _finalizeTranscript({
    required Meeting meeting,
    required (String, String) selected,
    required AudioSource source,
    required String snapshotId,
    required FinalTranscriptionProgressCallback? onProgress,
  }) async {
    AsrEngine? engine;
    StreamSubscription<AsrFinalizationProgress>? progressSubscription;
    try {
      engine = await engineFactory.create(
        modelId: selected.$1,
        modelVersion: selected.$2,
        language: meeting.recordingModelLanguage,
        useInverseTextNormalization:
            meeting.recordingModelUseInverseTextNormalization,
      );
      _validateEngine(engine, selected);
      if (onProgress != null) {
        progressSubscription = engine.finalizationProgress.listen(onProgress);
      }
      await engine.initialize();
      return await engine.finalizeMeeting(
        source,
        meetingId: meeting.id,
        snapshotId: snapshotId,
      );
    } finally {
      try {
        await progressSubscription?.cancel();
      } on Object {
        // 监听器清理失败不得覆盖已经确定的最终转录结果。
      }
      try {
        await engine?.dispose();
      } on Object {
        // Engine 释放异常只影响诊断，不能把已确定的最终转录结果改判为失败。
      }
    }
  }

  Future<_DiarizationAttempt> _runDiarization({
    required String meetingId,
    required String snapshotId,
    required AudioSource source,
    required int audioDurationMs,
  }) async {
    var enabled = true;
    try {
      enabled = await diarizationPreferences.getEnabled();
    } on Object {
      // 偏好读取失败不得阻断最终文本；无可靠关闭记录时沿用默认开启。
    }
    if (!enabled) {
      return const _DiarizationAttempt(
        status: SpeakerDiarizationStatus.disabled,
      );
    }

    final startedAt = now().toUtc();
    final taskId = 'speaker-diarization-$snapshotId';
    await _saveDiarizationTask(
      ProcessingTask(
        id: taskId,
        kind: ProcessingTaskKind.speakerDiarization,
        meetingId: meetingId,
        state: ProcessingState.running,
        createdAt: startedAt,
        updatedAt: startedAt,
      ),
    );

    if (!diarization.capability.isAvailable) {
      return _degradedDiarization(
        taskId: taskId,
        meetingId: meetingId,
        createdAt: startedAt,
        errorCode:
            diarization.capability.reasonCode ??
            'speaker_diarization.unavailable',
      );
    }
    if (diarization is! SpeakerDiarizationServiceLifecycle) {
      return _degradedDiarization(
        taskId: taskId,
        meetingId: meetingId,
        createdAt: startedAt,
        errorCode: 'speaker_diarization.lifecycle_unavailable',
      );
    }

    try {
      final turns = await diarization
          .diarize(source)
          .timeout(
            diarizationTimeout,
            onTimeout: () async {
              await _cancelDiarization();
              throw TimeoutException('说话人分离超时', diarizationTimeout);
            },
          );
      _validateTurns(turns, audioDurationMs);
      if (turns.isEmpty) {
        return _degradedDiarization(
          taskId: taskId,
          meetingId: meetingId,
          createdAt: startedAt,
          errorCode: 'speaker_diarization.empty_result',
        );
      }
      await _saveDiarizationTask(
        ProcessingTask(
          id: taskId,
          kind: ProcessingTaskKind.speakerDiarization,
          meetingId: meetingId,
          state: ProcessingState.completed,
          createdAt: startedAt,
          updatedAt: now().toUtc(),
        ),
      );
      return _DiarizationAttempt(
        status: SpeakerDiarizationStatus.completed,
        turns: turns,
      );
    } on TimeoutException {
      return _degradedDiarization(
        taskId: taskId,
        meetingId: meetingId,
        createdAt: startedAt,
        errorCode: 'speaker_diarization.timeout',
      );
    } on Object catch (error) {
      return _degradedDiarization(
        taskId: taskId,
        meetingId: meetingId,
        createdAt: startedAt,
        errorCode: switch (error) {
          SpeakerDiarizationException(:final code) => code,
          _ => 'speaker_diarization.unexpected',
        },
      );
    }
  }

  Future<_DiarizationAttempt> _degradedDiarization({
    required String taskId,
    required String meetingId,
    required DateTime createdAt,
    required String errorCode,
  }) async {
    await _saveDiarizationTask(
      ProcessingTask(
        id: taskId,
        kind: ProcessingTaskKind.speakerDiarization,
        meetingId: meetingId,
        state: ProcessingState.failed,
        createdAt: createdAt,
        updatedAt: now().toUtc(),
        lastErrorCode: errorCode,
      ),
    );
    return _DiarizationAttempt(
      status: SpeakerDiarizationStatus.degraded,
      errorCode: errorCode,
    );
  }

  Future<void> _saveDiarizationTask(ProcessingTask task) async {
    try {
      await tasks.save(task);
    } on Object {
      // 任务诊断持久化失败不能阻止最终文本以单一说话人降级发布。
    }
  }

  Future<void> _cancelDiarization() async {
    if (diarization case final SpeakerDiarizationServiceLifecycle lifecycle) {
      try {
        await lifecycle.cancelActive();
      } on Object {
        // 取消失败不能覆盖 ASR 或 CAS 的原始失败。
      }
    }
  }

  void _validateTurns(List<SpeakerTurn> turns, int audioDurationMs) {
    for (final turn in turns) {
      if (turn.startMs < 0 ||
          turn.endMs <= turn.startMs ||
          turn.endMs > audioDurationMs ||
          turn.speakerId.trim().isEmpty) {
        throw const SpeakerDiarizationException(
          'speaker_diarization.invalid_result',
        );
      }
    }
  }

  TranscriptSnapshot _applyDiarization(
    TranscriptSnapshot snapshot,
    _DiarizationAttempt result,
  ) {
    return TranscriptSnapshot(
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
            speakerId: result.status == SpeakerDiarizationStatus.completed
                ? _bestSpeaker(segment, result.turns)
                : fallbackSpeakerId,
            confidence: segment.confidence,
            modelId: segment.modelId,
            modelVersion: segment.modelVersion,
          ),
      ],
    );
  }

  String _bestSpeaker(TranscriptSegment segment, List<SpeakerTurn> turns) {
    SpeakerTurn? best;
    var bestOverlap = 0;
    for (final turn in turns) {
      final start = segment.startMs > turn.startMs
          ? segment.startMs
          : turn.startMs;
      final end = segment.endMs < turn.endMs ? segment.endMs : turn.endMs;
      final overlap = end > start ? end - start : 0;
      if (overlap > bestOverlap ||
          (overlap == bestOverlap &&
              overlap > 0 &&
              _comesBefore(turn, best!))) {
        best = turn;
        bestOverlap = overlap;
      }
    }
    return bestOverlap == 0 ? fallbackSpeakerId : best!.speakerId.trim();
  }

  bool _comesBefore(SpeakerTurn candidate, SpeakerTurn current) {
    final byStart = candidate.startMs.compareTo(current.startMs);
    if (byStart != 0) {
      return byStart < 0;
    }
    return candidate.speakerId.compareTo(current.speakerId) < 0;
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

final class _DiarizationAttempt {
  const _DiarizationAttempt({
    required this.status,
    this.turns = const [],
    this.errorCode,
  });

  final SpeakerDiarizationStatus status;
  final List<SpeakerTurn> turns;
  final String? errorCode;
}
