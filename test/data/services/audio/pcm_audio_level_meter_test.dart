import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/pcm_audio_level_meter.dart';
import 'package:meettrace/domain/models/recording.dart';

void main() {
  group('PcmAudioLevelMeter', () {
    test('静音窗口输出零电平和准确时间', () async {
      final meter = PcmAudioLevelMeter();
      final values = <RecordingAudioLevel>[];
      final subscription = meter.changes.listen(values.add);

      await meter.add(
        RecordingPcmChunk(
          bytes: Uint8List(recordingBytesPerSecond ~/ 10),
          startByteOffset: 0,
        ),
      );

      expect(values, hasLength(1));
      expect(values.single.level, 0);
      expect(values.single.capturedThrough, defaultRecordingAudioLevelFrame);
      await subscription.cancel();
      await meter.dispose();
    });

    test('半满刻度 PCM 输出约负 6 dBFS 的归一化电平', () async {
      final meter = PcmAudioLevelMeter();
      final values = <RecordingAudioLevel>[];
      final subscription = meter.changes.listen(values.add);

      await meter.add(
        RecordingPcmChunk(
          bytes: _constantPcm16(
            sample: 16384,
            sampleCount: recordingSampleRate ~/ 10,
          ),
          startByteOffset: 0,
        ),
      );

      expect(values, hasLength(1));
      expect(values.single.level, closeTo(0.8997, 0.001));
      await subscription.cancel();
      await meter.dispose();
    });

    test('跨块累计窗口，输入出现缺口时丢弃未完成窗口', () async {
      final meter = PcmAudioLevelMeter();
      final values = <RecordingAudioLevel>[];
      final subscription = meter.changes.listen(values.add);
      final halfFrameBytes = recordingBytesPerSecond ~/ 20;

      await meter.add(
        RecordingPcmChunk(bytes: Uint8List(halfFrameBytes), startByteOffset: 0),
      );
      await meter.add(
        RecordingPcmChunk(
          bytes: Uint8List(halfFrameBytes),
          startByteOffset: halfFrameBytes * 2,
        ),
      );
      expect(values, isEmpty);

      await meter.add(
        RecordingPcmChunk(
          bytes: Uint8List(halfFrameBytes),
          startByteOffset: halfFrameBytes * 3,
        ),
      );

      expect(values, hasLength(1));
      expect(
        values.single.capturedThrough,
        recordingDurationForBytes(halfFrameBytes * 4),
      );
      await subscription.cancel();
      await meter.dispose();
    });
  });
}

Uint8List _constantPcm16({required int sample, required int sampleCount}) {
  final bytes = Uint8List(sampleCount * recordingBytesPerSample);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < sampleCount; index++) {
    data.setInt16(index * recordingBytesPerSample, sample, Endian.little);
  }
  return bytes;
}
