part of 'meeting_detail_view_model.dart';

final class MeetingAudioViewModel {
  const MeetingAudioViewModel._(this._owner);
  final MeetingDetailViewModel _owner;
  EvidencePlaybackState get state => _owner.playbackState;
  String? get selectedEvidenceSegmentId => _owner.selectedEvidenceSegmentId;
  Future<void> playEvidence(SummaryEvidence evidence) =>
      _owner._playEvidence(evidence);
  Future<void> playFullAudio() => _owner._playFullAudio();
  Future<void> stop() => _owner._stopPlayback();
}

extension _MeetingAudioOperations on MeetingDetailViewModel {
  Future<void> _playEvidence(SummaryEvidence evidence) async {
    final service = playback;
    final snapshot = _snapshot;
    final audioPath = _meeting.audioPath;
    if (service == null || snapshot == null || audioPath == null) {
      _resultMessage = '事实音频不可用';
      _notify();
      return;
    }
    final valid = snapshot.segments.any(
      (segment) =>
          segment.id == evidence.segmentId &&
          evidence.startMs >= segment.startMs &&
          evidence.endMs <= segment.endMs &&
          segment.text.contains(evidence.quote),
    );
    if (!valid) {
      _resultMessage = '证据与当前最终转录不一致，已拒绝播放';
      _notify();
      return;
    }
    _selectedEvidenceSegmentId = evidence.segmentId;
    _notify();
    try {
      await service.play(
        audioPath: audioPath,
        startMs: evidence.startMs,
        endMs: evidence.endMs,
      );
    } on Object {
      _resultMessage = '证据音频播放失败';
      _notify();
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

  Future<void> _stopPlayback() => playback?.stop() ?? Future.value();
}
