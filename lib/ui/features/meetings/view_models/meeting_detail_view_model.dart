import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/repository_contracts.dart';
import '../../../../data/services/asr/asr_engine.dart';
import '../../../../data/services/asr/final_transcription_service.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/model_installation.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/models/workflow_states.dart';

final class MeetingDetailViewModel extends ChangeNotifier {
  MeetingDetailViewModel({
    required Meeting meeting,
    required this.meetings,
    required this.transcripts,
    required this.installations,
    required this.transcription,
    AsrModelRegistry? registry,
  }) : _meeting = meeting,
       registry = registry ?? AsrModelRegistry.alpha,
       _selectedModelId = meeting.recordingModelId;

  final MeetingRepository meetings;
  final TranscriptRepository transcripts;
  final ModelInstallationRepository installations;
  final FinalTranscriptionRunner transcription;
  final AsrModelRegistry registry;

  Meeting _meeting;
  TranscriptSnapshot? _snapshot;
  TranscriptSnapshot? _failedAttempt;
  TranscriptSnapshot? _processingAttempt;
  List<AsrModelDescriptor> _installedModels = const [];
  StreamSubscription<List<ModelInstallation>>? _installationSubscription;
  Future<void>? _loading;
  Future<void>? _operation;
  double _progress = 0;
  String? _errorMessage;
  String _selectedModelId;
  String? _operationModelId;
  bool _isLoading = true;
  bool _disposed = false;

  Meeting get meeting => _meeting;
  TranscriptSnapshot? get snapshot => _snapshot;
  List<AsrModelDescriptor> get installedModels =>
      List.unmodifiable(_installedModels);
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  String get selectedModelId => _selectedModelId;
  bool get isLoading => _isLoading;
  bool get isProcessing => _operation != null;
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

  Future<void> _load() async {
    _errorMessage = null;
    _notify();
    try {
      await _loadInstalledModels();
      await _refreshSnapshots();
      if (_meeting.status == MeetingState.processing &&
          _snapshot?.status != TranscriptSnapshotStatus.complete) {
        final pending = _processingAttempt;
        await _run(
          modelId: pending?.actualModelId,
          modelVersion: pending?.actualModelVersion,
          retrySnapshotId: pending?.id,
        );
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
    } on Object {
      _errorMessage = '最终转录失败，事实音频和旧结果均已保留';
      await _refreshMeeting();
      await _refreshSnapshots();
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
