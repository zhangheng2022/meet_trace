import 'dart:typed_data';

import 'package:record/record.dart';

import '../../../domain/models/recording_input.dart';
import 'recording_ports.dart';

const meettracePcmRecordConfig = RecordConfig(
  encoder: AudioEncoder.pcm16bits,
  sampleRate: 16000,
  numChannels: 1,
  // 由官方 record 插件请求平台语音处理；支持程度取决于设备能力。
  // 增强后的 PCM 同时作为事实音频和 ASR 输入，避免两条链路内容不一致。
  autoGain: true,
  echoCancel: true,
  noiseSuppress: true,
  audioInterruption: AudioInterruptionMode.pauseResume,
);

const meettraceFallbackPcmRecordConfig = RecordConfig(
  encoder: AudioEncoder.pcm16bits,
  sampleRate: 16000,
  numChannels: 1,
  autoGain: false,
  echoCancel: false,
  noiseSuppress: false,
  audioInterruption: AudioInterruptionMode.pauseResume,
);

typedef PcmStreamStarter = Future<Stream<Uint8List>> Function(
  RecordConfig config,
);

Future<Stream<Uint8List>> startPcmStreamWithEnhancementFallback(
  PcmStreamStarter startStream, {
  LockedRecordingInput input = const LockedRecordingInput.systemDefault(),
}) async {
  final primaryConfig = _configForInput(meettracePcmRecordConfig, input);
  final fallbackConfig = _configForInput(
    meettraceFallbackPcmRecordConfig,
    input,
  );
  try {
    return await startStream(primaryConfig);
  } on Exception catch (enhancementError, enhancementStackTrace) {
    try {
      return await startStream(fallbackConfig);
    } on Exception {
      Error.throwWithStackTrace(enhancementError, enhancementStackTrace);
    }
  }
}

RecordConfig _configForInput(RecordConfig config, LockedRecordingInput input) {
  final device = input.device;
  if (device == null) {
    return config;
  }
  return config.copyWith(
    device: (value: InputDevice(id: device.id, label: device.label)),
  );
}

final class RecordPcmAudioCapture implements PcmAudioCapture {
  RecordPcmAudioCapture({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission({bool request = true}) {
    return _recorder.hasPermission(request: request);
  }

  @override
  Future<Stream<Uint8List>> start({
    LockedRecordingInput input = const LockedRecordingInput.systemDefault(),
  }) {
    return startPcmStreamWithEnhancementFallback(
      (config) => _recorder.startStream(config),
      input: input,
    );
  }

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
