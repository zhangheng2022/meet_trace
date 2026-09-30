import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/remote/pcm16_resampler.dart';

void main() {
  test(
    'continuous resampling is invariant to arbitrary input block boundaries',
    () {
      final signal = Float32List.fromList([
        for (var i = 0; i < 16001; i++) sin(i * 0.173) * 0.9,
      ]);
      Uint8List resample(List<int> sizes) {
        final resampler = Pcm16To24Resampler();
        final output = BytesBuilder(copy: false);
        var offset = 0;
        var next = 0;
        while (offset < signal.length) {
          final end = min(signal.length, offset + sizes[next++ % sizes.length]);
          output.add(
            resampler.add(Float32List.sublistView(signal, offset, end)),
          );
          offset = end;
        }
        output.add(resampler.finish());
        expect(resampler.finish(), isEmpty);
        return output.takeBytes();
      }

      final expected = resample([signal.length]);
      expect(expected.length, ((signal.length * 3 + 1) ~/ 2) * 2);
      expect(resample([1]), expected);
      expect(resample([3, 320, 7, 1024, 1, 239]), expected);
    },
  );

  test('linear interpolation, clipping and final sample are explicit', () {
    final resampler = Pcm16To24Resampler();
    final bytes = BytesBuilder()
      ..add(resampler.add(Float32List.fromList([-1, 0, 1])))
      ..add(resampler.finish());
    final data = ByteData.sublistView(bytes.takeBytes());
    expect(
      [
        for (var i = 0; i < data.lengthInBytes; i += 2)
          data.getInt16(i, Endian.little),
      ],
      [-32768, -10923, 10923, 32767, 32767],
    );
  });

  test(
    'pause boundary emits the tail once and preserves sample count on resume',
    () {
      final resampler = Pcm16To24Resampler();
      final output = BytesBuilder()
        ..add(resampler.add(Float32List(1600)))
        ..add(resampler.flushBoundary());
      expect(output.length, 4800);
      expect(resampler.flushBoundary(), isEmpty);
      output.add(resampler.add(Float32List(1600)));
      output.add(resampler.finish());
      expect(output.length, 9600);
    },
  );

  test(
    'invalid input is rejected and PCM decoder retains signed amplitude',
    () {
      expect(
        () => Pcm16To24Resampler().add(Float32List.fromList([double.nan])),
        throwsArgumentError,
      );
      expect(() => decodeRemotePcm16(Uint8List(3)), throwsArgumentError);
      expect(decodeRemotePcm16(Uint8List.fromList([0, 128, 255, 127])), [
        -1,
        32767 / 32768,
      ]);
    },
  );
}
