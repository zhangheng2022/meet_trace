import '../../../domain/models/audio_source.dart';
import '../../../domain/models/speaker_diarization.dart';

abstract interface class SpeakerDiarizationService {
  SpeakerDiarizationCapability get capability;

  Future<List<SpeakerTurn>> diarize(AudioSource source);
}

/// 当前 Alpha 未配置经过发布校验的本地说话人模型，显式关闭能力。
///
/// 后续实现必须继续通过此 Dart 端口接入，不得绕过官方包自建原生桥接。
final class UnavailableSpeakerDiarizationService
    implements SpeakerDiarizationService {
  const UnavailableSpeakerDiarizationService();

  @override
  SpeakerDiarizationCapability get capability =>
      const SpeakerDiarizationCapability.unavailable(
        reasonCode: 'speaker_diarization.model_unavailable',
      );

  @override
  Future<List<SpeakerTurn>> diarize(AudioSource source) {
    throw const SpeakerDiarizationException(
      'speaker_diarization.model_unavailable',
    );
  }
}
