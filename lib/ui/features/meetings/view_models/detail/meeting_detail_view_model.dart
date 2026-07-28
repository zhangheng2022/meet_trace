import 'dart:async';

import 'package:flutter/foundation.dart' hide Summary;

import '../../../../../domain/models/asr_model.dart';
import '../../../../../domain/models/asr_model_registry.dart';
import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/models/model_installation.dart';
import '../../../../../domain/models/processing_task.dart';
import '../../../../../domain/models/speaker_diarization.dart';
import '../../../../../domain/models/summary.dart';
import '../../../../../domain/models/transcript.dart';
import '../../../../../domain/models/workflow_states.dart';
import '../../../../../domain/ports/asr_engine.dart';
import '../../../../../domain/ports/evidence_playback.dart';
import '../../../../../domain/ports/final_transcription.dart';
import '../../../../../domain/ports/repositories.dart';
import '../../../../../domain/ports/speaker_diarization.dart';
import '../../../../../domain/ports/text_share.dart';
import '../../../../../domain/use_cases/generate_summary.dart';
import '../../../../../domain/use_cases/build_meeting_share.dart';
import '../../../../../domain/use_cases/delete_meeting.dart';
import '../../../../../domain/use_cases/revise_final_transcript.dart';

part 'meeting_detail_state.dart';
part 'meeting_transcript_view_model.dart';
part 'meeting_summary_view_model.dart';
part 'meeting_audio_view_model.dart';
part 'meeting_actions_view_model.dart';

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
    this.transcriptRevision,
    this.sharing,
    this.deletion,
    this.playback,
    this.shareBuilder = const BuildMeetingShareUseCase(),
    AsrModelRegistry? registry,
  }) : _meeting = meeting,
       registry = registry ?? AsrModelRegistry.alpha,
       _selectedModelId = meeting.recordingModelId {
    transcriptSection = MeetingTranscriptViewModel._(this);
    summarySection = MeetingSummaryViewModel._(this);
    audioSection = MeetingAudioViewModel._(this);
    actions = MeetingActionsViewModel._(this);
  }

  final MeetingRepository meetings;
  final TranscriptRepository transcripts;
  final ModelInstallationRepository installations;
  final FinalTranscriptionRunner transcription;
  final SpeakerDiarizationRunner? diarization;
  final DiarizationPreferenceRepository? diarizationPreferences;
  final ProcessingTaskRepository? processingTasks;
  final SummaryRepository? summaries;
  final GenerateSummaryUseCase? summaryGeneration;
  final ReviseFinalTranscriptUseCase? transcriptRevision;
  final TextShareService? sharing;
  final DeleteMeetingUseCase? deletion;
  final EvidencePlaybackService? playback;
  final BuildMeetingShareUseCase shareBuilder;
  final AsrModelRegistry registry;

  late final MeetingTranscriptViewModel transcriptSection;
  late final MeetingSummaryViewModel summarySection;
  late final MeetingAudioViewModel audioSection;
  late final MeetingActionsViewModel actions;

  Meeting _meeting;
  TranscriptSnapshot? _snapshot;
  TranscriptSnapshot? _failedAttempt;
  TranscriptSnapshot? _processingAttempt;
  List<AsrModelDescriptor> _installedModels = const [];
  StreamSubscription<List<ModelInstallation>>? _installationSubscription;
  StreamSubscription<EvidencePlaybackState>? _playbackSubscription;
  Future<void>? _loading;
  Future<void>? _operation;
  Future<void>? _diarizationOperation;
  Future<void>? _summaryOperation;
  Future<void>? _resultOperation;
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
  String? _resultMessage;
  EvidencePlaybackState _playbackState = const EvidencePlaybackState(
    status: EvidencePlaybackStatus.idle,
  );
  String? _selectedEvidenceSegmentId;
  bool _deleted = false;
  bool _disposed = false;

  MeetingDetailState get state => MeetingDetailState(
    meeting: _meeting,
    snapshot: _snapshot,
    summary: _summary,
    isLoading: _isLoading,
    isProcessing: isProcessing,
    progress: _progress,
    errorMessage: _errorMessage,
    resultMessage: _resultMessage,
    summaryMessage: _summaryMessage,
    diarizationMessage: _diarizationMessage,
    playbackState: _playbackState,
  );

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
      _summaryOperation != null ||
      _resultOperation != null;
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
  String? get resultMessage => _resultMessage;
  EvidencePlaybackState get playbackState => _playbackState;
  String? get selectedEvidenceSegmentId => _selectedEvidenceSegmentId;
  bool get isDeleted => _deleted;
  bool get canShare =>
      sharing != null &&
      _snapshot?.isEligibleForSummary(
            activeSnapshotId: _meeting.activeTranscriptSnapshotId,
          ) ==
          true;
  bool get canGenerateSummary {
    final snapshot = _snapshot;
    return summaryAvailable &&
        !isProcessing &&
        snapshot != null &&
        snapshot.isEligibleForSummary(
          activeSnapshotId: _meeting.activeTranscriptSnapshotId,
        );
  }

  bool get _shouldAutoGenerateSummary =>
      _meeting.title == pendingMeetingTitle &&
      _meeting.activeSummaryId == null &&
      _summary == null &&
      canGenerateSummary;

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

  void selectModel(String modelId) => transcriptSection.selectModel(modelId);
  Future<void> retry() => transcriptSection.retry();
  Future<void> retranscribe() => transcriptSection.retranscribe();
  Future<void> setDiarizationEnabled(bool enabled) =>
      transcriptSection.setDiarizationEnabled(enabled);
  Future<void> retryDiarization() => transcriptSection.retryDiarization();
  Future<void> renameSpeaker(String? currentSpeakerId, String newLabel) =>
      transcriptSection.renameSpeaker(currentSpeakerId, newLabel);
  Future<void> reviseTranscript(List<TranscriptSegmentRevision> revisions) =>
      transcriptSection.reviseTranscript(revisions);
  Future<void> generateSummary() => summarySection.generate();
  Future<void> playEvidence(SummaryEvidence evidence) =>
      audioSection.playEvidence(evidence);
  Future<void> playFullAudio() => audioSection.playFullAudio();
  Future<void> stopPlayback() => audioSection.stop();
  Future<void> renameMeeting(String title) => actions.renameMeeting(title);
  Future<void> share(MeetingShareFormat format) => actions.share(format);
  Future<void> deleteMeeting() => actions.deleteMeeting();

  Future<void> _load() async {
    _errorMessage = null;
    _notify();
    try {
      _playbackSubscription ??= playback?.states.listen((state) {
        _playbackState = state;
        _notify();
      });
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
        if (_shouldAutoGenerateSummary) {
          await _runSummaryGeneration();
        }
      }
    } on Object {
      _errorMessage ??= '最终转录状态加载失败，请重试';
      _notify();
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> _refreshMeeting() async {
    final refreshed = await meetings.getById(_meeting.id);
    if (refreshed != null) {
      _meeting = refreshed;
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
    unawaited(_playbackSubscription?.cancel());
    unawaited(playback?.dispose());
    super.dispose();
  }
}
