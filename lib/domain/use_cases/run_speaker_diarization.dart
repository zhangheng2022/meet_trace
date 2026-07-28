import 'dart:async';

import '../models/audio_source.dart';
import '../models/meeting.dart';
import '../models/processing_task.dart';
import '../models/speaker_diarization.dart';
import '../models/transcript.dart';
import '../models/workflow_states.dart';
import '../ports/repositories.dart';
import '../ports/speaker_diarization.dart';

export '../ports/speaker_diarization.dart' show SpeakerDiarizationRunner;

/// 在最终快照之上运行可降级的说话人增强。
///
/// 该编排只允许 Repository 更新 `speaker_id`，不会把服务输出用于重建文本、
/// 时间轴、片段 ID 或 ASR 模型身份。
final class SpeakerDiarizationCoordinator implements SpeakerDiarizationRunner {
  SpeakerDiarizationCoordinator({
    required this.meetings,
    required this.transcripts,
    required this.tasks,
    required this.service,
    required this.now,
    this.timeout = const Duration(minutes: 2),
  });

  static const fallbackSpeakerId = 'speaker-1';

  final MeetingRepository meetings;
  final TranscriptRepository transcripts;
  final ProcessingTaskRepository tasks;
  final SpeakerDiarizationService service;
  final DateTime Function() now;
  final Duration timeout;

  @override
  SpeakerDiarizationCapability get capability => service.capability;

  @override
  Future<SpeakerDiarizationResult> process({
    required String meetingId,
    required String snapshotId,
    required bool enabled,
  }) async {
    final eligible = await _loadEligible(
      meetingId: meetingId,
      snapshotId: snapshotId,
    );
    if (!enabled) {
      return SpeakerDiarizationResult(
        snapshot: eligible.$2,
        status: SpeakerDiarizationStatus.disabled,
      );
    }

    final startedAt = now().toUtc();
    final taskId = _taskId(snapshotId);
    await tasks.save(
      ProcessingTask(
        id: taskId,
        kind: ProcessingTaskKind.speakerDiarization,
        meetingId: meetingId,
        state: ProcessingState.running,
        createdAt: startedAt,
        updatedAt: startedAt,
      ),
    );

    if (!capability.isAvailable) {
      return _degrade(
        snapshot: eligible.$2,
        taskId: taskId,
        createdAt: startedAt,
        errorCode: capability.reasonCode ?? 'speaker_diarization.unavailable',
      );
    }

    try {
      final turns = await service
          .diarize(
            AudioSource(
              path: eligible.$1.audioPath!,
              durationMs: eligible.$1.audioDurationMs,
            ),
          )
          .timeout(timeout);
      _validateTurns(turns, eligible.$1.audioDurationMs);
      if (turns.isEmpty) {
        return _degrade(
          snapshot: eligible.$2,
          taskId: taskId,
          createdAt: startedAt,
          errorCode: 'speaker_diarization.empty_result',
        );
      }
      final updated = await transcripts.updateSpeakerLabels(
        snapshotId: snapshotId,
        labelsBySegmentId: _mapTurns(eligible.$2, turns),
      );
      final completedAt = now().toUtc();
      await tasks.save(
        ProcessingTask(
          id: taskId,
          kind: ProcessingTaskKind.speakerDiarization,
          meetingId: meetingId,
          state: ProcessingState.completed,
          createdAt: startedAt,
          updatedAt: completedAt,
        ),
      );
      return SpeakerDiarizationResult(
        snapshot: updated,
        status: SpeakerDiarizationStatus.completed,
      );
    } on TimeoutException {
      return _degrade(
        snapshot: eligible.$2,
        taskId: taskId,
        createdAt: startedAt,
        errorCode: 'speaker_diarization.timeout',
      );
    } on Object catch (error) {
      return _degrade(
        snapshot: eligible.$2,
        taskId: taskId,
        createdAt: startedAt,
        errorCode: switch (error) {
          SpeakerDiarizationException(:final code) => code,
          _ => 'speaker_diarization.unexpected',
        },
      );
    }
  }

  @override
  Future<TranscriptSnapshot> renameSpeaker({
    required String meetingId,
    required String snapshotId,
    required String? currentSpeakerId,
    required String newLabel,
  }) async {
    final (_, snapshot) = await _loadEligible(
      meetingId: meetingId,
      snapshotId: snapshotId,
    );
    final label = newLabel.trim();
    if (label.isEmpty || label.length > 80) {
      throw const SpeakerDiarizationException(
        'speaker_diarization.invalid_label',
      );
    }
    final matching = snapshot.segments
        .where((segment) => segment.speakerId == currentSpeakerId)
        .toList();
    if (matching.isEmpty) {
      throw const SpeakerDiarizationException(
        'speaker_diarization.speaker_not_found',
      );
    }
    return transcripts.updateSpeakerLabels(
      snapshotId: snapshotId,
      labelsBySegmentId: {for (final segment in matching) segment.id: label},
    );
  }

  Future<(Meeting, TranscriptSnapshot)> _loadEligible({
    required String meetingId,
    required String snapshotId,
  }) async {
    final meeting = await meetings.getById(meetingId);
    final snapshot = await transcripts.getById(snapshotId);
    if (meeting == null ||
        snapshot == null ||
        snapshot.meetingId != meeting.id ||
        snapshot.kind != TranscriptSnapshotKind.finalTranscript ||
        snapshot.status != TranscriptSnapshotStatus.complete ||
        meeting.status != MeetingState.completed ||
        meeting.activeTranscriptSnapshotId != snapshot.id ||
        meeting.audioPath?.trim().isEmpty != false ||
        meeting.audioDurationMs <= 0) {
      throw const SpeakerDiarizationException(
        'speaker_diarization.snapshot_not_eligible',
      );
    }
    return (meeting, snapshot);
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

  Map<String, String?> _mapTurns(
    TranscriptSnapshot snapshot,
    List<SpeakerTurn> turns,
  ) {
    return {
      for (final segment in snapshot.segments)
        segment.id: _bestSpeaker(segment, turns),
    };
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

  Future<SpeakerDiarizationResult> _degrade({
    required TranscriptSnapshot snapshot,
    required String taskId,
    required DateTime createdAt,
    required String errorCode,
  }) async {
    final updated = await transcripts.updateSpeakerLabels(
      snapshotId: snapshot.id,
      labelsBySegmentId: {
        for (final segment in snapshot.segments) segment.id: fallbackSpeakerId,
      },
    );
    await tasks.save(
      ProcessingTask(
        id: taskId,
        kind: ProcessingTaskKind.speakerDiarization,
        meetingId: snapshot.meetingId,
        state: ProcessingState.failed,
        createdAt: createdAt,
        updatedAt: now().toUtc(),
        lastErrorCode: errorCode,
      ),
    );
    return SpeakerDiarizationResult(
      snapshot: updated,
      status: SpeakerDiarizationStatus.degraded,
      errorCode: errorCode,
    );
  }

  String _taskId(String snapshotId) => 'speaker-diarization-$snapshotId';
}
