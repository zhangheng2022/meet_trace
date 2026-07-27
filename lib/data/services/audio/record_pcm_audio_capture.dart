import 'dart:typed_data';

import 'package:record/record.dart';

import 'recording_ports.dart';

const meettracePcmRecordConfig = RecordConfig(
  encoder: AudioEncoder.pcm16bits,
  sampleRate: 16000,
  numChannels: 1,
  autoGain: false,
  echoCancel: false,
  noiseSuppress: false,
  audioInterruption: AudioInterruptionMode.pauseResume,
);

final class RecordPcmAudioCapture implements PcmAudioCapture {
  RecordPcmAudioCapture({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission({bool request = true}) {
    return _recorder.hasPermission(request: request);
  }

  @override
  Future<Stream<Uint8List>> start() {
    return _recorder.startStream(meettracePcmRecordConfig);
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
