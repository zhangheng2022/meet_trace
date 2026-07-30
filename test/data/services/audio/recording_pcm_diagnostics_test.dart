import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/recording_pcm_diagnostics.dart';

void main() {
  group('RecordingPcmDiagnostics', () {
    test('统计连续 PCM16 小端块的时长、峰值、RMS、削波和 DC 偏移', () {
      final diagnostics = RecordingPcmDiagnostics();

      diagnostics.addChunk(
        Uint8List.fromList([0x00, 0x00, 0xff, 0x7f, 0x00, 0x80, 0x00, 0x40]),
        startByteOffset: 0,
      );
      final snapshot = diagnostics.snapshot;

      expect(snapshot.chunkCount, 1);
      expect(snapshot.totalBytes, 8);
      expect(snapshot.sampleCount, 4);
      expect(snapshot.duration, const Duration(microseconds: 250));
      expect(snapshot.peakNormalized, 1);
      expect(snapshot.clippedSampleCount, 2);
      expect(snapshot.clippingRatio, 0.5);
      expect(snapshot.rmsNormalized, closeTo(0.75, 0.05));
      expect(snapshot.dcOffsetNormalized, closeTo(0.125, 0.01));
    });

    test('拒绝奇数字节和不连续 offset', () {
      final diagnostics = RecordingPcmDiagnostics();

      expect(
        () => diagnostics.addChunk(Uint8List.fromList([0]), startByteOffset: 0),
        throwsArgumentError,
      );
      diagnostics.addChunk(Uint8List.fromList([0, 0]), startByteOffset: 0);
      expect(
        () => diagnostics.addChunk(
          Uint8List.fromList([0, 0]),
          startByteOffset: 4,
        ),
        throwsStateError,
      );
    });

    test('快照只含统计值且 reset 后从新 offset 开始', () {
      final diagnostics = RecordingPcmDiagnostics();
      diagnostics.addChunk(
        Uint8List.fromList([1, 0, 2, 0]),
        startByteOffset: 0,
      );

      diagnostics.reset(nextByteOffset: 64);
      diagnostics.addChunk(Uint8List.fromList([3, 0]), startByteOffset: 64);

      expect(diagnostics.snapshot.toJson(), {
        'sampleRate': 16000,
        'channelCount': 1,
        'bitsPerSample': 16,
        'chunkCount': 1,
        'totalBytes': 2,
        'sampleCount': 1,
        'durationMicros': 62,
        'peakNormalized': closeTo(3 / 32768, 0.000001),
        'rmsNormalized': closeTo(3 / 32768, 0.000001),
        'dcOffsetNormalized': closeTo(3 / 32768, 0.000001),
        'clippedSampleCount': 0,
        'clippingRatio': 0,
      });
    });
  });
}
