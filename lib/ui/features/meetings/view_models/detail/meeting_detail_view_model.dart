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
import '../../../../core/app_value_formatters.dart';
import 'meeting_speaker_labels.dart';

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
    required this.shareBuilderProvider,
    required this.speakerLabelBuilder,
    AsrModelRegistry? registry,
  })
    // ignore: prefer_initializing_formals
    : _meeting = meeting,
       registry = registry ?? AsrModelRegistry.alpha;

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
  final BuildMeetingShareUseCase Function() shareBuilderProvider;
  final String Function(int number) speakerLabelBuilder;
  final AsrModelRegistry registry;

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
  bool _diarizationEnabled = true;
  SpeakerDiarizationStatus _diarizationStatus =
      SpeakerDiarizationStatus.disabled;
  String? _diarizationMessage;
  String? _resultMessage;
  AudioPlaybackState _playbackState = const AudioPlaybackState(
    status: AudioPlaybackStatus.idle,
  );
  bool _deleted = false;
  bool _disposed = false;

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
  bool get canShareAudio =>
      audioSharing != null &&
      _meeting.audioPath != null &&
      _meeting.audioDurationMs > 0;

  List<SpeakerLabelGroup> get speakerGroups {
    final groups = <String?, int>{};
    for (final segment in _snapshot?.segments ?? const <TranscriptSegment>[]) {
      groups.update(segment.speakerId, (count) => count + 1, ifAbsent: () => 1);
    }
    return List.unmodifiable([
      for (final entry in groups.entries)
        SpeakerLabelGroup(
          speakerId: entry.key,
          displayLabel: displaySpeakerLabel(
            entry.key,
            speakerLabelBuilder: speakerLabelBuilder,
          ),
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

  Future<void> retry() => _retry();
  Future<void> retranscribe() => _runTranscription();
  Future<void> setDiarizationEnabled(bool enabled) =>
      _setDiarizationEnabled(enabled);
  Future<void> retryDiarization() => _runDiarization();
  Future<bool> renameSpeaker(String? currentSpeakerId, String newLabel) =>
      _renameSpeaker(currentSpeakerId, newLabel);
  Future<void> reviseTranscript(List<TranscriptSegmentRevision> revisions) =>
      _reviseTranscript(revisions);
  Future<void> playFullAudio() => _playFullAudio();
  Future<void> stopPlayback() => playback?.stop() ?? Future.value();
  Future<void> share(MeetingShareFormat format) => _share(format);
  Future<AudioSharePreparation?> prepareAudioShare() => _prepareAudioShare();
  Future<void> shareAudio(AudioSharePreparation preparation) =>
      _shareAudio(preparation);
  Future<void> deleteMeeting() => _deleteMeeting();

  Future<void> _load() async {
    _errorMessage = null;
    _notify();
    try {
      _playbackSubscription ??= playback?.states.listen((state) {
        _playbackState = state;
        _notify();
      });
      _diarizationEnabled = await diarizationPreferences?.getEnabled() ?? true;
      await _refreshSnapshots();
      await _refreshDiarizationTask();
      if (_meeting.status == MeetingState.processing &&
          _snapshot?.status != TranscriptSnapshotStatus.complete) {
        final pending = _processingAttempt;
        await _runTranscription(
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

  Future<void> _retry() {
    final failed = _failedAttempt;
    if (failed == null) {
      return Future.value();
    }
    return _runTranscription(retrySnapshotId: _lockedRetrySnapshotId(failed));
  }

  String? _lockedRetrySnapshotId(TranscriptSnapshot snapshot) {
    return snapshot.actualModelId == _meeting.recordingModelId &&
            snapshot.actualModelVersion == _meeting.recordingModelVersion
        ? snapshot.id
        : null;
  }

  Future<void> _setDiarizationEnabled(bool enabled) async {
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

  Future<bool> _renameSpeaker(String? currentSpeakerId, String newLabel) async {
    final currentSnapshot = _snapshot;
    if (currentSnapshot == null || isProcessing) {
      return false;
    }
    final revision = transcriptRevision;
    if (revision != null) {
      await reviseTranscript([
        for (final segment in currentSnapshot.segments)
          TranscriptSegmentRevision(
            segmentId: segment.id,
            text: segment.text,
            speakerLabel: segment.speakerId == currentSpeakerId
                ? newLabel
                : segment.speakerId,
          ),
      ]);
      return _snapshot?.id != currentSnapshot.id;
    }
    final runner = diarization;
    if (runner == null) {
      return false;
    }
    try {
      _snapshot = await runner.renameSpeaker(
        meetingId: _meeting.id,
        snapshotId: currentSnapshot.id,
        currentSpeakerId: currentSpeakerId,
        newLabel: newLabel,
      );
      _diarizationMessage = '说话人标签已保存';
      return true;
    } on Object {
      _diarizationMessage = '说话人标签保存失败，请重试';
      return false;
    } finally {
      _notify();
    }
  }

  Future<void> _reviseTranscript(List<TranscriptSegmentRevision> revisions) =>
      _runResultOperation(() async {
        final useCase = transcriptRevision;
        if (useCase == null) {
          return;
        }
        final result = await useCase.execute(
          meetingId: _meeting.id,
          revisions: revisions,
        );
        _meeting = result.meeting;
        _snapshot = result.snapshot;
        _resultMessage = '转录修订已保存为新版本';
      }, failureMessage: '转录修订保存失败，请检查内容后重试');

  Future<void> _runTranscription({String? retrySnapshotId}) {
    final current = _operation;
    if (current != null) {
      return current;
    }
    final operation = _transcribe(retrySnapshotId: retrySnapshotId);
    _operation = operation;
    _notify();
    return operation.whenComplete(() {
      _operation = null;
      _notify();
    });
  }

  Future<void> _transcribe({required String? retrySnapshotId}) async {
    _errorMessage = null;
    _progress = 0;
    _notify();
    try {
      final result = await transcription.transcribe(
        meetingId: _meeting.id,
        retrySnapshotId: retrySnapshotId,
        onProgress: _applyProgress,
      );
      _meeting = result.meeting;
      _snapshot = result.snapshot;
      _failedAttempt = null;
      _processingAttempt = null;
      _progress = 1;
      _diarizationStatus = result.diarizationStatus;
      _diarizationMessage = switch (result.diarizationStatus) {
        SpeakerDiarizationStatus.disabled => null,
        SpeakerDiarizationStatus.completed => '说话人分离已完成',
        SpeakerDiarizationStatus.degraded => '说话人分离失败，已按单一说话人显示；最终转录不受影响',
      };
    } on Object {
      _errorMessage = '最终转录失败，事实音频和旧结果均已保留';
      await _refreshMeeting();
      await _refreshSnapshots();
    } finally {
      _notify();
    }
  }

  Future<void> _runDiarizationIfNeeded() {
    final currentSnapshot = _snapshot;
    if (!_diarizationEnabled ||
        currentSnapshot == null ||
        currentSnapshot.status != TranscriptSnapshotStatus.complete ||
        currentSnapshot.segments.any((segment) => segment.speakerId != null)) {
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
    final currentSnapshot = _snapshot;
    if (runner == null ||
        currentSnapshot == null ||
        currentSnapshot.status != TranscriptSnapshotStatus.complete) {
      return Future.value();
    }
    final operation = _processDiarization(runner, currentSnapshot);
    _diarizationOperation = operation;
    _notify();
    return operation.whenComplete(() {
      _diarizationOperation = null;
      _notify();
    });
  }

  Future<void> _processDiarization(
    SpeakerDiarizationRunner runner,
    TranscriptSnapshot currentSnapshot,
  ) async {
    _diarizationMessage = null;
    _notify();
    try {
      final result = await runner.process(
        meetingId: _meeting.id,
        snapshotId: currentSnapshot.id,
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

  void _applyProgress(AsrFinalizationProgress progress) {
    _progress = progress.fraction;
    _notify();
  }

  Future<void> _refreshSnapshots() async {
    final activeId = _meeting.activeTranscriptSnapshotId;
    final snapshots = await Future.wait<TranscriptSnapshot?>([
      activeId == null
          ? Future<TranscriptSnapshot?>.value()
          : transcripts.getById(activeId),
      transcripts.getLatestByMeeting(
        meetingId: _meeting.id,
        kind: TranscriptSnapshotKind.finalTranscript,
        status: TranscriptSnapshotStatus.failed,
      ),
      transcripts.getLatestByMeeting(
        meetingId: _meeting.id,
        kind: TranscriptSnapshotKind.finalTranscript,
        status: TranscriptSnapshotStatus.processing,
      ),
    ]);
    _snapshot = snapshots[0];
    _failedAttempt = snapshots[1];
    _processingAttempt = snapshots[2];
  }

  Future<void> _refreshDiarizationTask() async {
    final repository = processingTasks;
    final currentSnapshot = _snapshot;
    if (repository == null || currentSnapshot == null) {
      return;
    }
    final records = await repository.listByMeeting(_meeting.id);
    ProcessingTask? task;
    for (final record in records) {
      if (record.kind == ProcessingTaskKind.speakerDiarization &&
          record.id == 'speaker-diarization-${currentSnapshot.id}') {
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

  Future<void> _playFullAudio() async {
    final service = playback;
    final audioPath = _meeting.audioPath;
    if (service == null || audioPath == null || _meeting.audioDurationMs <= 0) {
      return;
    }
    try {
      await service.play(
        audioPath: audioPath,
        startMs: 0,
        endMs: _meeting.audioDurationMs,
      );
    } on Object {
      _resultMessage = '事实音频播放失败';
      _notify();
    }
  }

  Future<void> _share(MeetingShareFormat format) =>
      _runResultOperation(() async {
        final service = sharing;
        final currentSnapshot = _snapshot;
        if (service == null || currentSnapshot == null) {
          return;
        }
        final document = shareBuilderProvider().execute(
          meeting: _meeting,
          snapshot: currentSnapshot,
          format: format,
        );
        await service.share(document);
        _resultMessage = '已打开系统分享面板，内容不包含原始音频';
      }, failureMessage: '分享失败，请重试');

  Future<AudioSharePreparation?> _prepareAudioShare() async {
    final useCase = audioSharing;
    if (useCase == null || _resultOperation != null || isProcessing) {
      return null;
    }
    _resultMessage = null;
    final preparation = useCase.prepare(_meeting);
    _resultOperation = preparation.then<void>((_) {});
    _notify();
    try {
      return await preparation;
    } on Object {
      _resultMessage = '无法读取事实音频或可用空间，请重试';
      return null;
    } finally {
      _resultOperation = null;
      _notify();
    }
  }

  Future<void> _shareAudio(AudioSharePreparation preparation) =>
      _runResultOperation(
        () async {
          final useCase = audioSharing;
          if (useCase == null) {
            return;
          }
          final outcome = await useCase.execute(preparation);
          _resultMessage = switch (outcome) {
            AudioShareOutcome.completed => '音频分享操作已完成，临时文件已清理',
            AudioShareOutcome.dismissed => '已取消音频分享，临时文件已清理',
            AudioShareOutcome.unavailable => '已打开系统分享面板，平台未返回操作结果；临时文件已清理',
          };
        },
        failureMessage: '音频分享失败，临时文件已清理，请重试',
        mapFailure: (error) {
          if (error case AudioShareException(shortageBytes: final shortage?)) {
            return '可用空间不足，还缺少 ${formatStorageBytes(shortage)}；未保留临时文件';
          }
          if (error case AudioShareException(
            code: 'audio_share.cleanup_failed',
          )) {
            return '音频分享临时文件清理失败，请重启应用后重试';
          }
          return '音频分享失败，临时文件已清理，请重试';
        },
      );

  Future<void> _deleteMeeting() => _runResultOperation(() async {
    final useCase = deletion;
    if (useCase == null) {
      return;
    }
    await playback?.stop();
    await useCase.execute(meetingId: _meeting.id);
    _deleted = true;
    _resultMessage = '会议及其本地派生数据已删除';
  }, failureMessage: '会议删除未完成，请重试');

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

  Future<void> _runResultOperation(
    Future<void> Function() body, {
    required String failureMessage,
    String Function(Object error)? mapFailure,
  }) {
    final current = _resultOperation;
    if (current != null || isProcessing) {
      return current ?? Future.value();
    }
    _resultMessage = null;
    final operation = body().catchError((Object error) {
      _resultMessage = mapFailure?.call(error) ?? failureMessage;
    });
    _resultOperation = operation;
    _notify();
    return operation.whenComplete(() {
      _resultOperation = null;
      _notify();
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
