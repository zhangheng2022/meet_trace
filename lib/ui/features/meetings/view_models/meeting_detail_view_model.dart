import 'dart:async';

import 'package:flutter/foundation.dart' hide Summary;

import '../../../../data/repositories/repository_contracts.dart';
import '../../../../data/services/asr/asr_engine.dart';
import '../../../../data/services/asr/final_transcription_service.dart';
import '../../../../data/services/diarization/speaker_diarization_coordinator.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/model_installation.dart';
import '../../../../domain/models/processing_task.dart';
import '../../../../domain/models/speaker_diarization.dart';
import '../../../../domain/models/summary.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../domain/use_cases/generate_summary.dart';

final class MeetingDetailViewModel extends ChangeNotifier {
  MeetingDetailViewModel({
    required Meeting meeting,
    required this.meetings,
    required this.transcripts,
    required this.installations,
    required this.transcription,
    this.diarization,
    this.diarizationPreferences,
    this.processingTasks,
    this.summaries,
    this.summaryGeneration,
    AsrModelRegistry? registry,
  }) : _meeting = meeting,
       registry = registry ?? AsrModelRegistry.alpha,
       _selectedModelId = meeting.recordingModelId;

  final MeetingRepository meetings;
  final TranscriptRepository transcripts;
  final ModelInstallationRepository installations;
  final FinalTranscriptionRunner transcription;
  final SpeakerDiarizationRunner? diarization;
  final DiarizationPreferenceRepository? diarizationPreferences;
  final ProcessingTaskRepository? processingTasks;
  final SummaryRepository? summaries;
  final GenerateSummaryUseCase? summaryGeneration;
  final AsrModelRegistry registry;

  Meeting _meeting;
  TranscriptSnapshot? _snapshot;
  TranscriptSnapshot? _failedAttempt;
  TranscriptSnapshot? _processingAttempt;
  List<AsrModelDescriptor> _installedModels = const [];
  StreamSubscription<List<ModelInstallation>>? _installationSubscription;
  Future<void>? _loading;
  Future<void>? _operation;
  Future<void>? _diarizationOperation;
  Future<void>? _summaryOperation;
  double _progress = 0;
  String? _errorMessage;
  String _selectedModelId;
  String? _operationModelId;
  bool _isLoading = true;
  bool _diarizationEnabled = false;
  SpeakerDiarizationStatus _diarizationStatus =
      SpeakerDiarizationStatus.disabled;
  String? _diarizationMessage;
  Summary? _summary;
  String? _summaryMessage;
  bool _disposed = false;

  Meeting get meeting => _meeting;
  TranscriptSnapshot? get snapshot => _snapshot;
  List<AsrModelDescriptor> get installedModels =>
      List.unmodifiable(_installedModels);
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  String get selectedModelId => _selectedModelId;
  bool get isLoading => _isLoading;
  bool get isProcessing =>
      _operation != null ||
      _diarizationOperation != null ||
      _summaryOperation != null;
  bool get isTranscribing => _operation != null;
  bool get isDiarizing => _diarizationOperation != null;
  bool get diarizationEnabled => _diarizationEnabled;
  bool get diarizationAvailable => diarization?.capability.isAvailable == true;
  bool get canRetryDiarization =>
      _diarizationEnabled &&
      diarizationAvailable &&
      !isProcessing &&
      _snapshot?.status == TranscriptSnapshotStatus.complete;
  SpeakerDiarizationStatus get diarizationStatus => _diarizationStatus;
  String? get diarizationMessage => _diarizationMessage;
  Summary? get summary => _summary;
  String? get summaryMessage => _summaryMessage;
  bool get isGeneratingSummary => _summaryOperation != null;
  bool get summaryAvailable =>
      summaryGeneration?.capability.isAvailable == true;
  bool get canGenerateSummary {
    final snapshot = _snapshot;
    return summaryAvailable &&
        !isProcessing &&
        snapshot != null &&
        snapshot.isEligibleForSummary(
          activeSnapshotId: _meeting.activeTranscriptSnapshotId,
        );
  }

  List<SpeakerLabelGroup> get speakerGroups {
    final groups = <String?, int>{};
    for (final segment in _snapshot?.segments ?? const <TranscriptSegment>[]) {
      groups.update(segment.speakerId, (count) => count + 1, ifAbsent: () => 1);
    }
    return List.unmodifiable([
      for (final entry in groups.entries)
        SpeakerLabelGroup(
          speakerId: entry.key,
          displayLabel: displaySpeakerLabel(entry.key),
          segmentCount: entry.value,
        ),
    ]);
  }

  bool get canRetry => !isProcessing && _failedAttempt != null;
  bool get canRetranscribe =>
      !isProcessing &&
      _meeting.status == MeetingState.completed &&
      _installedModels.isNotEmpty;

  AsrModelDescriptor get sourceModel => registry.requireById(
    _operationModelId ??
        _snapshot?.actualModelId ??
        _failedAttempt?.actualModelId ??
        _meeting.recordingModelId,
  );

  Future<void> load() => _loading ??= _load();

  void selectModel(String modelId) {
    if (isProcessing ||
        !_installedModels.any((model) => model.modelId == modelId)) {
      return;
    }
    _selectedModelId = modelId;
    _notify();
  }

  Future<void> retry() {
    final failed = _failedAttempt;
    if (failed == null) {
      return Future.value();
    }
    return _run(
      modelId: failed.actualModelId,
      modelVersion: failed.actualModelVersion,
      retrySnapshotId: failed.id,
    );
  }

  Future<void> retranscribe() {
    final descriptor = registry.requireById(_selectedModelId);
    return _run(modelId: descriptor.modelId, modelVersion: descriptor.version);
  }

  Future<void> setDiarizationEnabled(bool enabled) async {
    final preferences = diarizationPreferences;
    if (preferences == null ||
        (enabled && !diarizationAvailable) ||
        isProcessing) {
      return;
    }
    _diarizationEnabled = enabled;
    _diarizationStatus = SpeakerDiarizationStatus.disabled;
    _diarizationMessage = null;
    _notify();
    await preferences.setEnabled(enabled);
    if (enabled) {
      await _runDiarization();
    }
  }

  Future<void> retryDiarization() => _runDiarization();

  Future<void> generateSummary() => _runSummaryGeneration();

  Future<void> renameSpeaker(String? currentSpeakerId, String newLabel) async {
    final runner = diarization;
    final snapshot = _snapshot;
    if (runner == null || snapshot == null || isProcessing) {
      return;
    }
    try {
      _snapshot = await runner.renameSpeaker(
        meetingId: _meeting.id,
        snapshotId: snapshot.id,
        currentSpeakerId: currentSpeakerId,
        newLabel: newLabel,
      );
      _diarizationMessage = '说话人标签已保存';
    } on Object {
      _diarizationMessage = '说话人标签保存失败，请重试';
    } finally {
      _notify();
    }
  }

  Future<void> _load() async {
    _errorMessage = null;
    _notify();
    try {
      _diarizationEnabled = await diarizationPreferences?.getEnabled() ?? false;
      await _loadInstalledModels();
      await _refreshSnapshots();
      await _refreshDiarizationTask();
      await _refreshSummary();
      await _refreshSummaryTask();
      if (_meeting.status == MeetingState.processing &&
          _snapshot?.status != TranscriptSnapshotStatus.complete) {
        final pending = _processingAttempt;
        await _run(
          modelId: pending?.actualModelId,
          modelVersion: pending?.actualModelVersion,
          retrySnapshotId: pending?.id,
        );
      } else {
        await _runDiarizationIfNeeded();
      }
    } on Object {
      _errorMessage ??= '最终转录状态加载失败，请重试';
      _notify();
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> _loadInstalledModels() async {
    final initial = Completer<void>();
    _installationSubscription = installations.watchAll().listen(
      (items) {
        _applyInstallations(items);
        if (!initial.isCompleted) {
          initial.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!initial.isCompleted) {
          initial.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!initial.isCompleted) {
          initial.completeError(StateError('模型安装状态流未返回初始值'));
        }
      },
    );
    await initial.future;
  }

  void _applyInstallations(List<ModelInstallation> items) {
    final installed = <AsrModelDescriptor>[];
    for (final descriptor in registry.models) {
      final available = items.any(
        (installation) =>
            installation.modelId == descriptor.modelId &&
            installation.version == descriptor.version &&
            installation.state == ModelInstallationState.installed &&
            installation.verifiedAt != null,
      );
      if (available) {
        installed.add(descriptor);
      }
    }
    _installedModels = List.unmodifiable(installed);
    if (!_installedModels.any((model) => model.modelId == _selectedModelId) &&
        _installedModels.isNotEmpty) {
      _selectedModelId = _installedModels.first.modelId;
    }
    _notify();
  }

  Future<void> _run({
    String? modelId,
    String? modelVersion,
    String? retrySnapshotId,
  }) {
    final current = _operation;
    if (current != null) {
      return current;
    }
    final operation = _transcribe(
      modelId: modelId,
      modelVersion: modelVersion,
      retrySnapshotId: retrySnapshotId,
    );
    _operationModelId = modelId ?? _meeting.recordingModelId;
    _operation = operation;
    _notify();
    return operation.whenComplete(() {
      _operation = null;
      _operationModelId = null;
      _notify();
    });
  }

  Future<void> _transcribe({
    required String? modelId,
    required String? modelVersion,
    required String? retrySnapshotId,
  }) async {
    _errorMessage = null;
    _progress = 0;
    _notify();
    try {
      final result = await transcription.transcribe(
        meetingId: _meeting.id,
        modelId: modelId,
        modelVersion: modelVersion,
        retrySnapshotId: retrySnapshotId,
        onProgress: _applyProgress,
      );
      _meeting = result.meeting;
      _snapshot = result.snapshot;
      _failedAttempt = null;
      _processingAttempt = null;
      _progress = 1;
      _summary = null;
      _summaryMessage = null;
      await _runDiarizationIfNeeded();
    } on Object {
      _errorMessage = '最终转录失败，事实音频和旧结果均已保留';
      await _refreshMeeting();
      await _refreshSnapshots();
    } finally {
      _notify();
    }
  }

  Future<void> _runDiarizationIfNeeded() {
    final snapshot = _snapshot;
    if (!_diarizationEnabled ||
        snapshot == null ||
        snapshot.status != TranscriptSnapshotStatus.complete ||
        snapshot.segments.any((segment) => segment.speakerId != null)) {
      return Future.value();
    }
    return _runDiarization();
  }

  Future<void> _runDiarization() {
    final current = _diarizationOperation;
    if (current != null) {
      return current;
    }
    final runner = diarization;
    final snapshot = _snapshot;
    if (runner == null ||
        snapshot == null ||
        snapshot.status != TranscriptSnapshotStatus.complete) {
      return Future.value();
    }
    final operation = _processDiarization(runner, snapshot);
    _diarizationOperation = operation;
    _notify();
    return operation.whenComplete(() {
      _diarizationOperation = null;
      _notify();
    });
  }

  Future<void> _processDiarization(
    SpeakerDiarizationRunner runner,
    TranscriptSnapshot snapshot,
  ) async {
    _diarizationMessage = null;
    _notify();
    try {
      final result = await runner.process(
        meetingId: _meeting.id,
        snapshotId: snapshot.id,
        enabled: _diarizationEnabled,
      );
      _snapshot = result.snapshot;
      _diarizationStatus = result.status;
      _diarizationMessage = switch (result.status) {
        SpeakerDiarizationStatus.disabled => null,
        SpeakerDiarizationStatus.completed => '说话人分离已完成',
        SpeakerDiarizationStatus.degraded => '说话人分离失败，已按单一说话人显示；最终转录不受影响',
      };
    } on Object {
      _diarizationStatus = SpeakerDiarizationStatus.degraded;
      _diarizationMessage = '说话人分离失败，最终转录仍可查看；可稍后重试';
    } finally {
      _notify();
    }
  }

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
      _summaryMessage = 'AI 总结已生成，结论均可查看原文证据';
    } on Object {
      await _refreshMeeting();
      await _refreshSummary();
      _summaryMessage = 'AI 总结生成失败，最终转录不受影响；可稍后重试';
    } finally {
      _notify();
    }
  }

  void _applyProgress(AsrFinalizationProgress progress) {
    _progress = progress.fraction;
    _notify();
  }

  Future<void> _refreshMeeting() async {
    final refreshed = await meetings.getById(_meeting.id);
    if (refreshed != null) {
      _meeting = refreshed;
    }
  }

  Future<void> _refreshSnapshots() async {
    final snapshots = await transcripts.listByMeeting(_meeting.id);
    _snapshot = _meeting.activeTranscriptSnapshotId == null
        ? null
        : await transcripts.getById(_meeting.activeTranscriptSnapshotId!);
    final failed =
        snapshots
            .where(
              (snapshot) =>
                  snapshot.kind == TranscriptSnapshotKind.finalTranscript &&
                  snapshot.status == TranscriptSnapshotStatus.failed,
            )
            .toList()
          ..sort((left, right) {
            final byDate = right.createdAt.compareTo(left.createdAt);
            return byDate != 0 ? byDate : right.id.compareTo(left.id);
          });
    _failedAttempt = failed.isEmpty ? null : failed.first;
    final processing =
        snapshots
            .where(
              (snapshot) =>
                  snapshot.kind == TranscriptSnapshotKind.finalTranscript &&
                  snapshot.status == TranscriptSnapshotStatus.processing,
            )
            .toList()
          ..sort((left, right) {
            final byDate = right.createdAt.compareTo(left.createdAt);
            return byDate != 0 ? byDate : right.id.compareTo(left.id);
          });
    _processingAttempt = processing.isEmpty ? null : processing.first;
  }

  Future<void> _refreshDiarizationTask() async {
    final repository = processingTasks;
    final snapshot = _snapshot;
    if (repository == null || snapshot == null) {
      return;
    }
    final records = await repository.listByMeeting(_meeting.id);
    ProcessingTask? task;
    for (final record in records) {
      if (record.kind == ProcessingTaskKind.speakerDiarization &&
          record.id == 'speaker-diarization-${snapshot.id}') {
        task = record;
        break;
      }
    }
    if (task == null) {
      return;
    }
    switch (task.state) {
      case ProcessingState.completed:
        _diarizationStatus = SpeakerDiarizationStatus.completed;
        _diarizationMessage = '说话人分离已完成';
      case ProcessingState.failed:
        _diarizationStatus = SpeakerDiarizationStatus.degraded;
        _diarizationMessage = '说话人分离失败，已按单一说话人显示；最终转录不受影响';
      case ProcessingState.idle ||
          ProcessingState.queued ||
          ProcessingState.running ||
          ProcessingState.canceled:
        break;
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

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_installationSubscription?.cancel());
    super.dispose();
  }
}

final class SpeakerLabelGroup {
  const SpeakerLabelGroup({
    required this.speakerId,
    required this.displayLabel,
    required this.segmentCount,
  });

  final String? speakerId;
  final String displayLabel;
  final int segmentCount;
}

String displaySpeakerLabel(String? speakerId) {
  if (speakerId == null || speakerId == 'speaker-1') {
    return '说话人 1';
  }
  final numeric = RegExp(r'^speaker-(\d+)$').firstMatch(speakerId);
  if (numeric != null) {
    return '说话人 ${numeric.group(1)}';
  }
  return speakerId;
}
