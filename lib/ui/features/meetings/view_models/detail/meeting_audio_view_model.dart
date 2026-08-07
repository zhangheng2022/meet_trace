import '../../../../../domain/ports/audio_playback.dart';
import 'meeting_detail_view_model.dart';

final class MeetingAudioViewModel {
  const MeetingAudioViewModel.internal(this._owner);
  final MeetingDetailViewModel _owner;
  AudioPlaybackState get state => _owner.playbackState;
  Future<void> playFullAudio() => _owner.internalPlayFullAudio();
  Future<void> stop() => _owner.internalStopPlayback();
}

extension _MeetingAudioOperations on MeetingDetailViewModel {
  Future<void> internalPlayFullAudio() async {
    final service = playback;
    final audioPath = internalMeeting.audioPath;
    if (service == null ||
        audioPath == null ||
        internalMeeting.audioDurationMs <= 0) {
      return;
    }
    try {
      await service.play(
        audioPath: audioPath,
        startMs: 0,
        endMs: internalMeeting.audioDurationMs,
      );
    } on Object {
      internalResultMessage = '事实音频播放失败';
      internalNotify();
    }
  }

  Future<void> internalStopPlayback() => playback?.stop() ?? Future.value();
}
