part of 'meeting_detail_view_model.dart';

final class MeetingSummaryViewModel {
  const MeetingSummaryViewModel._(this._owner);
  final MeetingDetailViewModel _owner;
  Summary? get summary => _owner.summary;
  bool get isGenerating => _owner.isGeneratingSummary;
  bool get canGenerate => _owner.canGenerateSummary;
  String? get message => _owner.summaryMessage;
  Future<void> generate() => _owner._requestSummaryGeneration();
}

extension _MeetingSummaryOperations on MeetingDetailViewModel {
  Future<void> _requestSummaryGeneration() => _runSummaryGeneration();

  Future<void> _runSummaryGeneration() {
    final current = _summaryOperation;
    if (current != null) {
      return current;
    }
    final useCase = summaryGeneration;
    if (useCase == null || !canGenerateSummary) {
      return Future.value();
    }
    final operation = _generateSummary(useCase);
    _summaryOperation = operation;
    _notify();
    return operation.whenComplete(() {
      _summaryOperation = null;
      _notify();
    });
  }

  Future<void> _generateSummary(GenerateSummaryUseCase useCase) async {
    _summaryMessage = null;
    _notify();
    try {
      final result = await useCase.execute(meetingId: _meeting.id);
      _meeting = result.meeting;
      _summary = result.summary;
      _summaryMessage = 'AI 总结和会议标题已生成，结论均可查看原文证据';
    } on Object {
      await _refreshMeeting();
      await _refreshSummary();
      _summaryMessage = 'AI 总结生成失败，最终转录不受影响；可稍后重试';
    } finally {
      _notify();
    }
  }

  Future<void> _refreshSummary() async {
    final repository = summaries;
    final snapshot = _snapshot;
    if (repository == null || snapshot == null) {
      _summary = null;
      return;
    }
    final activeSummaryId = _meeting.activeSummaryId;
    if (activeSummaryId != null) {
      _summary = await repository.getById(activeSummaryId);
      return;
    }
    final records =
        (await repository.listByMeeting(_meeting.id))
            .where((summary) => summary.transcriptSnapshotId == snapshot.id)
            .toList()
          ..sort((left, right) {
            final byDate = right.createdAt.compareTo(left.createdAt);
            return byDate != 0 ? byDate : right.id.compareTo(left.id);
          });
    _summary = records.isEmpty ? null : records.first;
  }

  Future<void> _refreshSummaryTask() async {
    final repository = processingTasks;
    final snapshot = _snapshot;
    if (repository == null || snapshot == null) {
      return;
    }
    final task = await repository.getById('summary-generation-${snapshot.id}');
    if (task?.state == ProcessingState.failed) {
      _summaryMessage = 'AI 总结生成失败，最终转录不受影响；可稍后重试';
    }
  }
}
