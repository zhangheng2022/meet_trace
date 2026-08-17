import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/record_pcm_audio_capture.dart';
import 'package:meettrace/domain/models/recording_input.dart';
import 'package:record/record.dart';

void main() {
  test('官方 record 适配器固定请求 PCM16、输入增强和音频中断恢复', () {
    expect(meettracePcmRecordConfig.encoder, AudioEncoder.pcm16bits);
    expect(meettracePcmRecordConfig.sampleRate, 16000);
    expect(meettracePcmRecordConfig.numChannels, 1);
    expect(
      meettracePcmRecordConfig.audioInterruption,
      AudioInterruptionMode.pauseResume,
    );
    expect(meettracePcmRecordConfig.autoGain, isTrue);
    expect(meettracePcmRecordConfig.echoCancel, isTrue);
    expect(meettracePcmRecordConfig.noiseSuppress, isTrue);
  });

  test('增强录音启动失败时使用同规格基础 PCM 继续录音', () async {
    final attemptedConfigs = <RecordConfig>[];
    final expectedStream = Stream<Uint8List>.empty();

    final stream = await startPcmStreamWithEnhancementFallback((config) async {
      attemptedConfigs.add(config);
      if (attemptedConfigs.length == 1) {
        throw Exception('voice processing unavailable');
      }
      return expectedStream;
    });

    expect(stream, same(expectedStream));
    expect(attemptedConfigs, [
      same(meettracePcmRecordConfig),
      same(meettraceFallbackPcmRecordConfig),
    ]);
    expect(meettraceFallbackPcmRecordConfig.encoder, AudioEncoder.pcm16bits);
    expect(meettraceFallbackPcmRecordConfig.sampleRate, 16000);
    expect(meettraceFallbackPcmRecordConfig.numChannels, 1);
    expect(meettraceFallbackPcmRecordConfig.autoGain, isFalse);
    expect(meettraceFallbackPcmRecordConfig.echoCancel, isFalse);
    expect(meettraceFallbackPcmRecordConfig.noiseSuppress, isFalse);
  });

  test('增强与基础录音均启动失败时保留首个错误', () async {
    final enhancementError = Exception('voice processing unavailable');
    var attempts = 0;

    await expectLater(
      startPcmStreamWithEnhancementFallback((config) async {
        attempts++;
        if (attempts == 1) {
          throw enhancementError;
        }
        throw Exception('microphone unavailable');
      }),
      throwsA(same(enhancementError)),
    );
    expect(attempts, 2);
  });

  test('显式输入设备同时应用到增强与基础 PCM 配置', () async {
    final attemptedConfigs = <RecordConfig>[];

    await startPcmStreamWithEnhancementFallback(
      (config) async {
        attemptedConfigs.add(config);
        if (attemptedConfigs.length == 1) {
          throw Exception('voice processing unavailable');
        }
        return const Stream<Uint8List>.empty();
      },
      input: const LockedRecordingInput.device(
        RecordingInputDevice(id: 'mic-1', label: 'USB 麦克风'),
      ),
    );

    expect(attemptedConfigs, hasLength(2));
    for (final config in attemptedConfigs) {
      expect(config.device?.id, 'mic-1');
      expect(config.device?.label, 'USB 麦克风');
      expect(config.encoder, AudioEncoder.pcm16bits);
      expect(config.sampleRate, 16000);
      expect(config.numChannels, 1);
    }
  });
}
