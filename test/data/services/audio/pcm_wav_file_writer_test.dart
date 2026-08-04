import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/pcm_wav_file_writer.dart';

void main() {
  test('WAV 大小包含 44 字节头并拒绝 RIFF 32 位上限外的 PCM', () {
    const writer = PcmWavFileWriter();

    expect(writer.wavLengthForPcm(32000), 32044);
    expect(
      () => writer.wavLengthForPcm(maxWavPcmBytes + 2),
      throwsA(
        isA<PcmWavWriteException>().having(
          (error) => error.code,
          'code',
          'wav.invalid_pcm_length',
        ),
      ),
    );
  });
}
