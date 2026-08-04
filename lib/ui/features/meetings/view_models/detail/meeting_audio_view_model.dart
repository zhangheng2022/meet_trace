part of 'meeting_detail_view_model.dart';

final class MeetingAudioViewModel {
  const MeetingAudioViewModel._(this._owner);
  final MeetingDetailViewModel _owner;
  AudioPlaybackState get state => _owner.playbackState;
  Future<void> playFullAudio() => _owner._playFullAudio();
  Future<void> stop() => _owner._stopPlayback();
}

extension _MeetingAudioOperations on MeetingDetailViewModel {
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
