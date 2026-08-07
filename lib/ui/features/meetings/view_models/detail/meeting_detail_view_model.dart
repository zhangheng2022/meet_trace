import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../domain/models/asr_model.dart';
import '../../../../../domain/models/asr_model_registry.dart';
import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/models/speaker_diarization.dart';
import '../../../../../domain/models/transcript.dart';
import '../../../../../domain/models/workflow_states.dart';
import '../../../../../domain/ports/audio_playback.dart';
import '../../../../../domain/ports/final_transcription.dart';
import '../../../../../domain/ports/repositories.dart';
import '../../../../../domain/ports/speaker_diarization.dart';
import '../../../../../domain/ports/text_share.dart';
import '../../../../../domain/use_cases/build_meeting_share.dart';
import '../../../../../domain/use_cases/delete_meeting.dart';
import '../../../../../domain/use_cases/revise_final_transcript.dart';
import '../../../../../domain/use_cases/share_meeting_audio.dart';
import 'meeting_actions_view_model.dart';
import 'meeting_audio_view_model.dart';
import 'meeting_detail_state.dart';
import 'meeting_transcript_view_model.dart';

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
    : internalMeeting = meeting,
       registry = registry ?? AsrModelRegistry.alpha {
    transcriptSection = MeetingTranscriptViewModel.internal(this);
    audioSection = MeetingAudioViewModel.internal(this);
    actions = MeetingActionsViewModel.internal(this);
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

  @internal
  Meeting internalMeeting;
  @internal
  TranscriptSnapshot? internalSnapshot;
  @internal
  TranscriptSnapshot? internalFailedAttempt;
  @internal
  TranscriptSnapshot? internalProcessingAttempt;
  StreamSubscription<AudioPlaybackState>? _playbackSubscription;
  Future<void>? _loading;
  @internal
  Future<void>? internalOperation;
  @internal
  Future<void>? internalDiarizationOperation;
  @internal
  Future<void>? internalResultOperation;
  @internal
  double internalProgress = 0;
  @internal
  String? internalErrorMessage;
  bool _isLoading = true;
  @internal
  bool internalDiarizationEnabled = true;
  @internal
  SpeakerDiarizationStatus internalDiarizationStatus =
      SpeakerDiarizationStatus.disabled;
  @internal
  String? internalDiarizationMessage;
  @internal
  String? internalResultMessage;
  AudioPlaybackState _playbackState = const AudioPlaybackState(
    status: AudioPlaybackStatus.idle,
  );
  @internal
  bool internalDeleted = false;
  bool _disposed = false;

  MeetingDetailState get state => MeetingDetailState(
    meeting: internalMeeting,
    snapshot: internalSnapshot,
    isLoading: _isLoading,
    isProcessing: isProcessing,
    progress: internalProgress,
    errorMessage: internalErrorMessage,
    resultMessage: internalResultMessage,
    diarizationMessage: internalDiarizationMessage,
    playbackState: _playbackState,
  );

  Meeting get meeting => internalMeeting;
  TranscriptSnapshot? get snapshot => internalSnapshot;
  double get progress => internalProgress;
  String? get errorMessage => internalErrorMessage;
  bool get isLoading => _isLoading;
  bool get isProcessing =>
      internalOperation != null ||
      internalDiarizationOperation != null ||
      internalResultOperation != null;
  bool get isTranscribing => internalOperation != null;
  bool get isDiarizing => internalDiarizationOperation != null;
  bool get diarizationEnabled => internalDiarizationEnabled;
  bool get diarizationAvailable => diarization?.capability.isAvailable == true;
  bool get canRetryDiarization =>
      internalDiarizationEnabled &&
      diarizationAvailable &&
      !isProcessing &&
      internalSnapshot?.status == TranscriptSnapshotStatus.complete;
  SpeakerDiarizationStatus get diarizationStatus => internalDiarizationStatus;
  String? get diarizationMessage => internalDiarizationMessage;
  String? get resultMessage => internalResultMessage;
  AudioPlaybackState get playbackState => _playbackState;
  bool get isDeleted => internalDeleted;
  bool get canShare =>
      sharing != null &&
      internalSnapshot?.isCurrentFinalTranscript(
            activeSnapshotId: internalMeeting.activeTranscriptSnapshotId,
          ) ==
          true;

  List<SpeakerLabelGroup> get speakerGroups {
    final groups = <String?, int>{};
    for (final segment
        in internalSnapshot?.segments ?? const <TranscriptSegment>[]) {
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

  bool get canRetry => !isProcessing && internalFailedAttempt != null;
  bool get canRetranscribe =>
      !isProcessing && internalMeeting.status == MeetingState.completed;

  AsrModelDescriptor get sourceModel => registry.requireById(
    internalSnapshot?.actualModelId ??
        internalFailedAttempt?.actualModelId ??
        internalMeeting.recordingModelId,
  );

  Future<void> load() => _loading ??= _load();

  Future<void> retry() => transcriptSection.retry();
  Future<void> retranscribe() => transcriptSection.retranscribe();
  Future<void> setDiarizationEnabled(bool enabled) =>
      transcriptSection.setDiarizationEnabled(enabled);
  Future<void> retryDiarization() => transcriptSection.retryDiarization();
  Future<bool> renameSpeaker(String? currentSpeakerId, String newLabel) =>
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
    internalErrorMessage = null;
    internalNotify();
    try {
      _playbackSubscription ??= playback?.states.listen((state) {
        _playbackState = state;
        internalNotify();
      });
      internalDiarizationEnabled =
          await diarizationPreferences?.getEnabled() ?? true;
      await internalRefreshSnapshots();
      await internalRefreshDiarizationTask();
      if (internalMeeting.status == MeetingState.processing &&
          internalSnapshot?.status != TranscriptSnapshotStatus.complete) {
        final pending = internalProcessingAttempt;
        await internalRunTranscription(
          retrySnapshotId: pending == null
              ? null
              : internalLockedRetrySnapshotId(pending),
        );
      } else {
        await internalRunDiarizationIfNeeded();
      }
    } on Object {
      internalErrorMessage ??= '最终转录状态加载失败，请重试';
      internalNotify();
    } finally {
      _isLoading = false;
      internalNotify();
    }
  }

  Future<void> internalRefreshMeeting() async {
    final refreshed = await meetings.getById(internalMeeting.id);
    if (refreshed != null) {
      internalMeeting = refreshed;
    }
  }

  void internalNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> internalRunResultOperation(
    Future<void> Function() body, {
    required String failureMessage,
    String Function(Object error)? mapFailure,
  }) {
    final current = internalResultOperation;
    if (current != null || isProcessing) {
      return current ?? Future.value();
    }
    internalResultMessage = null;
    final operation = body().catchError((Object error) {
      internalResultMessage = mapFailure?.call(error) ?? failureMessage;
    });
    internalResultOperation = operation;
    internalNotify();
    return operation.whenComplete(() {
      internalResultOperation = null;
      internalNotify();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_playbackSubscription?.cancel());
    unawaited(playback?.dispose());
    super.dispose();
  }
}
