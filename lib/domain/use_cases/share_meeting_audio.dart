import '../models/domain_exception.dart';
import '../models/meeting.dart';
import '../ports/audio_share.dart';

final class AudioSharePreparation {
  const AudioSharePreparation({
    required this.meetingId,
    required this.meetingTitle,
    required this.audioPath,
    required this.durationMs,
    required this.storage,
  });

  final String meetingId;
  final String meetingTitle;
  final String audioPath;
  final int durationMs;
  final AudioShareStorageSnapshot storage;

  bool get canShare => storage.hasEnoughSpace;
}

final class ShareMeetingAudioUseCase {
  const ShareMeetingAudioUseCase(this.service);

  final AudioShareService service;

  Future<AudioSharePreparation> prepare(Meeting meeting) async {
    final audioPath = meeting.audioPath;
    if (audioPath == null || audioPath.trim().isEmpty) {
      throw const DomainInvariantViolation('会议没有可分享的事实音频');
    }
    if (meeting.audioDurationMs <= 0) {
      throw const DomainInvariantViolation('事实音频时长无效，不能分享');
    }
    return AudioSharePreparation(
      meetingId: meeting.id,
      meetingTitle: meeting.title,
      audioPath: audioPath,
      durationMs: meeting.audioDurationMs,
      storage: await service.inspect(audioPath: audioPath),
    );
  }

  Future<AudioShareOutcome> execute(AudioSharePreparation preparation) {
    if (!preparation.canShare) {
      throw AudioShareException(
        'audio_share.insufficient_space',
        shortageBytes: preparation.storage.shortageBytes,
      );
    }
    return service.share(
      meetingId: preparation.meetingId,
      meetingTitle: preparation.meetingTitle,
      audioPath: preparation.audioPath,
      expectedPcmBytes: preparation.storage.pcmBytes,
    );
  }
}
