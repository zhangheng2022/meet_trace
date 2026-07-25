import 'dart:async';

import '../../data/repositories/repository_contracts.dart';
import '../../data/services/summary/summary_generation_service.dart';
import '../models/meeting.dart';
import '../models/processing_task.dart';
import '../models/summary.dart';
import '../models/transcript.dart';
import '../models/workflow_states.dart';

final class SummaryGenerationResult {
  const SummaryGenerationResult({required this.meeting, required this.summary});

  final Meeting meeting;
  final Summary summary;
}

final class SummaryGenerationException implements Exception {
  const SummaryGenerationException(this.code);

  final String code;

  @override
  String toString() => 'SummaryGenerationException: $code';
}

final class GenerateSummaryUseCase {
  GenerateSummaryUseCase({
    required this.meetings,
    required this.transcripts,
    required this.summaries,
    required this.tasks,
    required this.service,
    required this.now,
    this.timeout = const Duration(minutes: 1),
  });

  final MeetingRepository meetings;
  final TranscriptRepository transcripts;
  final SummaryRepository summaries;
  final ProcessingTaskRepository tasks;
  final SummaryGenerationService service;
  final DateTime Function() now;
  final Duration timeout;

  SummaryGenerationCapability get capability => service.capability;

  Future<SummaryGenerationResult> execute({required String meetingId}) async {
    final (meeting, snapshot) = await _loadEligible(meetingId);
    if (!capability.isAvailable) {
      throw SummaryGenerationException(
        capability.reasonCode ?? 'summary.gateway_unavailable',
      );
    }

    final createdAt = now().toUtc();
    final summaryId = 'summary-${snapshot.id}';
    final taskId = 'summary-generation-${snapshot.id}';
    final provider = capability.provider!;
    final model = capability.model!;
    await tasks.save(
      ProcessingTask(
        id: taskId,
        kind: ProcessingTaskKind.summary,
        meetingId: meeting.id,
        state: ProcessingState.running,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    await summaries.save(
      Summary(
        id: summaryId,
        meetingId: meeting.id,
        transcriptSnapshotId: snapshot.id,
        provider: provider,
        model: model,
        createdAt: createdAt,
        overview: '',
        keyPoints: const [],
        actionItems: const [],
        status: SummaryStatus.processing,
      ),
    );

    var activated = false;
    try {
      final draft = await service
          .generate(_buildRequest(snapshot))
          .timeout(timeout);
      final completed = _buildSummary(
        summaryId: summaryId,
        meeting: meeting,
        snapshot: snapshot,
        provider: provider,
        model: model,
        createdAt: createdAt,
        draft: draft,
      );
      await summaries.saveAndActivate(
        summary: completed,
        expectedTranscriptSnapshotId: snapshot.id,
      );
      activated = true;
      final refreshedMeeting = await meetings.getById(meeting.id);
      if (refreshedMeeting == null ||
          refreshedMeeting.activeSummaryId != completed.id) {
        throw const SummaryGenerationException(
          'summary.activation_not_visible',
        );
      }
      await _completeTaskBestEffort(
        taskId: taskId,
        meetingId: meeting.id,
        createdAt: createdAt,
      );
      return SummaryGenerationResult(
        meeting: refreshedMeeting,
        summary: completed,
      );
    } on Object catch (error) {
      final code = _errorCode(error);
      if (!activated) {
        await _recordFailure(
          summaryId: summaryId,
          meeting: meeting,
          snapshot: snapshot,
          provider: provider,
          model: model,
          createdAt: createdAt,
          taskId: taskId,
          errorCode: code,
        );
      }
      throw SummaryGenerationException(code);
    }
  }

  Future<void> _completeTaskBestEffort({
    required String taskId,
    required String meetingId,
    required DateTime createdAt,
  }) async {
    try {
      await tasks.save(
        ProcessingTask(
          id: taskId,
          kind: ProcessingTaskKind.summary,
          meetingId: meetingId,
          state: ProcessingState.completed,
          createdAt: createdAt,
          updatedAt: now().toUtc(),
        ),
      );
    } on Object {
      // 摘要与会议已在同一事务中激活，辅助任务状态失败不能反向污染事实数据。
    }
  }

  Future<(Meeting, TranscriptSnapshot)> _loadEligible(String meetingId) async {
    final meeting = await meetings.getById(meetingId);
    final activeSnapshotId = meeting?.activeTranscriptSnapshotId;
    final snapshot = activeSnapshotId == null
        ? null
        : await transcripts.getById(activeSnapshotId);
    if (meeting == null ||
        meeting.status != MeetingState.completed ||
        snapshot == null ||
        snapshot.meetingId != meeting.id ||
        !snapshot.isEligibleForSummary(
          activeSnapshotId: meeting.activeTranscriptSnapshotId,
        )) {
      throw const SummaryGenerationException('summary.snapshot_not_eligible');
    }
    return (meeting, snapshot);
  }

  SummaryGenerationRequest _buildRequest(TranscriptSnapshot snapshot) {
    return SummaryGenerationRequest(
      segments: [
        for (final segment in snapshot.segments)
          SummaryPromptSegment(
            id: segment.id,
            text: segment.text,
            speakerLabel: segment.speakerId,
          ),
      ],
    );
  }

  Summary _buildSummary({
    required String summaryId,
    required Meeting meeting,
    required TranscriptSnapshot snapshot,
    required String provider,
    required String model,
    required DateTime createdAt,
    required GeneratedSummaryDraft draft,
  }) {
    final segmentsById = {
      for (final segment in snapshot.segments) segment.id: segment,
    };
    return Summary(
      id: summaryId,
      meetingId: meeting.id,
      transcriptSnapshotId: snapshot.id,
      provider: provider,
      model: model,
      createdAt: createdAt,
      overview: draft.overview.trim(),
      keyPoints: _buildItems(
        summaryId: summaryId,
        kind: 'key-point',
        drafts: draft.keyPoints,
        segmentsById: segmentsById,
      ),
      actionItems: _buildItems(
        summaryId: summaryId,
        kind: 'action-item',
        drafts: draft.actionItems,
        segmentsById: segmentsById,
      ),
      status: SummaryStatus.complete,
    );
  }

  List<SummaryItem> _buildItems({
    required String summaryId,
    required String kind,
    required List<GeneratedSummaryItem> drafts,
    required Map<String, TranscriptSegment> segmentsById,
  }) {
    return [
      for (var index = 0; index < drafts.length; index++)
        SummaryItem(
          id: '$summaryId-$kind-${index + 1}',
          text: drafts[index].text.trim(),
          evidence: _buildEvidence(
            drafts[index].evidenceSegmentIds,
            segmentsById,
          ),
        ),
    ];
  }

  List<SummaryEvidence> _buildEvidence(
    List<String> requestedIds,
    Map<String, TranscriptSegment> segmentsById,
  ) {
    final seen = <String>{};
    final evidence = <SummaryEvidence>[];
    for (final segmentId in requestedIds) {
      final segment = segmentsById[segmentId];
      if (segment == null || !seen.add(segment.id)) {
        continue;
      }
      evidence.add(
        SummaryEvidence(
          segmentId: segment.id,
          startMs: segment.startMs,
          endMs: segment.endMs,
          quote: segment.text,
        ),
      );
    }
    return evidence;
  }

  Future<void> _recordFailure({
    required String summaryId,
    required Meeting meeting,
    required TranscriptSnapshot snapshot,
    required String provider,
    required String model,
    required DateTime createdAt,
    required String taskId,
    required String errorCode,
  }) async {
    await summaries.save(
      Summary(
        id: summaryId,
        meetingId: meeting.id,
        transcriptSnapshotId: snapshot.id,
        provider: provider,
        model: model,
        createdAt: createdAt,
        overview: '',
        keyPoints: const [],
        actionItems: const [],
        status: SummaryStatus.failed,
      ),
    );
    await tasks.save(
      ProcessingTask(
        id: taskId,
        kind: ProcessingTaskKind.summary,
        meetingId: meeting.id,
        state: ProcessingState.failed,
        createdAt: createdAt,
        updatedAt: now().toUtc(),
        lastErrorCode: errorCode,
      ),
    );
  }

  String _errorCode(Object error) {
    return switch (error) {
      TimeoutException() => 'summary.timeout',
      SummaryGenerationServiceException(:final code) => code,
      SummaryGenerationException(:final code) => code,
      ArgumentError() => 'summary.invalid_schema',
      _ => 'summary.generation_failed',
    };
  }
}
