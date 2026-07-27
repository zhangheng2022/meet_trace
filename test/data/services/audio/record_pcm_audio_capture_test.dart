import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/record_pcm_audio_capture.dart';
import 'package:record/record.dart';

void main() {
  test('官方 record 适配器固定请求 16kHz 单声道 PCM16 并自动处理音频中断', () {
    expect(meettracePcmRecordConfig.encoder, AudioEncoder.pcm16bits);
    expect(meettracePcmRecordConfig.sampleRate, 16000);
    expect(meettracePcmRecordConfig.numChannels, 1);
    expect(
      meettracePcmRecordConfig.audioInterruption,
      AudioInterruptionMode.pauseResume,
    );
    expect(meettracePcmRecordConfig.autoGain, false);
    expect(meettracePcmRecordConfig.echoCancel, false);
    expect(meettracePcmRecordConfig.noiseSuppress, false);
  });
}
