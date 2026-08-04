import '../models/audio_source.dart';
import '../models/speaker_diarization.dart';
import '../models/transcript.dart';

abstract interface class SpeakerDiarizationService {
  SpeakerDiarizationCapability get capability;

  Future<List<SpeakerTurn>> diarize(AudioSource source);
}

/// 可终止本地原生推理并释放模型句柄的可选生命周期能力。
///
/// Domain 编排只依赖该抽象，不感知 isolate 或 sherpa-onnx 类型。
abstract interface class SpeakerDiarizationServiceLifecycle {
  Future<void> cancelActive();

  Future<void> dispose();
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
