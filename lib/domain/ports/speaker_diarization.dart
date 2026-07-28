import '../models/audio_source.dart';
import '../models/speaker_diarization.dart';
import '../models/transcript.dart';

abstract interface class SpeakerDiarizationService {
  SpeakerDiarizationCapability get capability;

  Future<List<SpeakerTurn>> diarize(AudioSource source);
}

abstract interface class SpeakerDiarizationRunner {
  SpeakerDiarizationCapability get capability;

  Future<SpeakerDiarizationResult> process({
    required String meetingId,
    required String snapshotId,
    required bool enabled,
  });

  Future<TranscriptSnapshot> renameSpeaker({
    required String meetingId,
    required String snapshotId,
    required String? currentSpeakerId,
    required String newLabel,
  });
}
