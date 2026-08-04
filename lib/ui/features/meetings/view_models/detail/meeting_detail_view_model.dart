import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../domain/models/asr_model.dart';
import '../../../../../domain/models/asr_model_registry.dart';
import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/models/processing_task.dart';
import '../../../../../domain/models/speaker_diarization.dart';
import '../../../../../domain/models/transcript.dart';
import '../../../../../domain/models/workflow_states.dart';
import '../../../../../domain/ports/asr_engine.dart';
import '../../../../../domain/ports/audio_playback.dart';
import '../../../../../domain/ports/audio_share.dart';
import '../../../../../domain/ports/final_transcription.dart';
import '../../../../../domain/ports/repositories.dart';
import '../../../../../domain/ports/speaker_diarization.dart';
import '../../../../../domain/ports/text_share.dart';
import '../../../../../domain/use_cases/build_meeting_share.dart';
import '../../../../../domain/use_cases/delete_meeting.dart';
import '../../../../../domain/use_cases/revise_final_transcript.dart';
import '../../../../../domain/use_cases/share_meeting_audio.dart';

part 'meeting_detail_state.dart';
part 'meeting_transcript_view_model.dart';
part 'meeting_audio_view_model.dart';
part 'meeting_actions_view_model.dart';

final class MeetingDetailViewModel extends ChangeNotifier {
  // 保留公开构造参数名 `meeting`，避免把内部字段名泄漏给调用方。
  MeetingDetailViewModel({
    required Meeting meeting,
    required this.meetings,
    required this.transcripts,
    required this.transcription,
    this.diarization,
    this.diarizationPreferences,
    this.processingTasks,
    this.transcriptRevision,
    this.sharing,
    this.audioSharing,
    this.deletion,
    this.playback,
    this.shareBuilder = const BuildMeetingShareUseCase(),
    AsrModelRegistry? registry,
  })
    // ignore: prefer_initializing_formals
    : _meeting = meeting,
       registry = registry ?? AsrModelRegistry.alpha {
    transcriptSection = MeetingTranscriptViewModel._(this);
    audioSection = MeetingAudioViewModel._(this);
    actions = MeetingActionsViewModel._(this);
  }

  final MeetingRepository meetings;
  final TranscriptRepository transcripts;
  final FinalTranscriptionRunner transcription;
  final SpeakerDiarizationRunner? diarization;
  final DiarizationPreferenceRepository? diarizationPreferences;
  final ProcessingTaskRepository? processingTasks;
  final ReviseFinalTranscriptUseCase? transcriptRevision;
  final TextShareService? sharing;
  final ShareMeetingAudioUseCase? audioSharing;
  final DeleteMeetingUseCase? deletion;
  final AudioPlaybackService? playback;
  final BuildMeetingShareUseCase shareBuilder;
  final AsrModelRegistry registry;

  late final MeetingTranscriptViewModel transcriptSection;
  late final MeetingAudioViewModel audioSection;
  late final MeetingActionsViewModel actions;

  Meeting _meeting;
  TranscriptSnapshot? _snapshot;
  TranscriptSnapshot? _failedAttempt;
  TranscriptSnapshot? _processingAttempt;
  StreamSubscription<AudioPlaybackState>? _playbackSubscription;
  Future<void>? _loading;
  Future<void>? _operation;
  Future<void>? _diarizationOperation;
  Future<void>? _resultOperation;
  double _progress = 0;
  String? _errorMessage;
  bool _isLoading = true;
  bool _diarizationEnabled = false;
  SpeakerDiarizationStatus _diarizationStatus =
      SpeakerDiarizationStatus.disabled;
  String? _diarizationMessage;
  String? _resultMessage;
  AudioPlaybackState _playbackState = const AudioPlaybackState(
    status: AudioPlaybackStatus.idle,
  );
  bool _deleted = false;
  bool _disposed = false;

  MeetingDetailState get state => MeetingDetailState(
    meeting: _meeting,
    snapshot: _snapshot,
    isLoading: _isLoading,
    isProcessing: isProcessing,
    progress: _progress,
    errorMessage: _errorMessage,
    resultMessage: _resultMessage,
    diarizationMessage: _diarizationMessage,
    playbackState: _playbackState,
  );

  Meeting get meeting => _meeting;
  TranscriptSnapshot? get snapshot => _snapshot;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isProcessing =>
      _operation != null ||
      _diarizationOperation != null ||
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
  String? get resultMessage => _resultMessage;
  AudioPlaybackState get playbackState => _playbackState;
  bool get isDeleted => _deleted;
  bool get canShare =>
      sharing != null &&
      _snapshot?.isCurrentFinalTranscript(
            activeSnapshotId: _meeting.activeTranscriptSnapshotId,
          ) ==
          true;

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
      !isProcessing && _meeting.status == MeetingState.completed;

  AsrModelDescriptor get sourceModel => registry.requireById(
    _snapshot?.actualModelId ??
        _failedAttempt?.actualModelId ??
        _meeting.recordingModelId,
  );

  Future<void> load() => _loading ??= _load();

  Future<void> retry() => transcriptSection.retry();
  Future<void> retranscribe() => transcriptSection.retranscribe();
  Future<void> setDiarizationEnabled(bool enabled) =>
      transcriptSection.setDiarizationEnabled(enabled);
  Future<void> retryDiarization() => transcriptSection.retryDiarization();
  Future<void> renameSpeaker(String? currentSpeakerId, String newLabel) =>
      transcriptSection.renameSpeaker(currentSpeakerId, newLabel);
  Future<void> reviseTranscript(List<TranscriptSegmentRevision> revisions) =>
      transcriptSection.reviseTranscript(revisions);
  Future<void> playFullAudio() => audioSection.playFullAudio();
  Future<void> stopPlayback() => audioSection.stop();
  Future<void> share(MeetingShareFormat format) => actions.share(format);
  Future<AudioSharePreparation?> prepareAudioShare() =>
      actions.prepareAudioShare();
  Future<void> shareAudio(AudioSharePreparation preparation) =>
      actions.shareAudio(preparation);
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
      await _refreshSnapshots();
      await _refreshDiarizationTask();
      if (_meeting.status == MeetingState.processing &&
          _snapshot?.status != TranscriptSnapshotStatus.complete) {
        final pending = _processingAttempt;
        await _run(
          retrySnapshotId: pending == null
              ? null
              : _lockedRetrySnapshotId(pending),
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
    unawaited(_playbackSubscription?.cancel());
    unawaited(playback?.dispose());
    super.dispose();
  }
}
