import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/audio/record_pcm_audio_capture.dart';
import 'package:record/record.dart';

void main() {
  test('官方 record 适配器固定请求 16kHz 单声道 PCM16 并自动处理音频中断', () {
    expect(meetilyPcmRecordConfig.encoder, AudioEncoder.pcm16bits);
    expect(meetilyPcmRecordConfig.sampleRate, 16000);
    expect(meetilyPcmRecordConfig.numChannels, 1);
    expect(
      meetilyPcmRecordConfig.audioInterruption,
      AudioInterruptionMode.pauseResume,
    );
    expect(meetilyPcmRecordConfig.autoGain, false);
    expect(meetilyPcmRecordConfig.echoCancel, false);
    expect(meetilyPcmRecordConfig.noiseSuppress, false);
  });
}
