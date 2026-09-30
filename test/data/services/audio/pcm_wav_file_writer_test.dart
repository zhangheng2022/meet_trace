import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/pcm_wav_file_writer.dart';

void main() {
  late Directory directory;
  late File pcm;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pcm-wav-test-');
    pcm = File('${directory.path}/fact.pcm');
    await pcm.writeAsBytes([0, 1, 2, 3, 4, 5, 6, 7]);
  });
  tearDown(() => directory.delete(recursive: true));

  test('内存 WAV 与原文件转换的范围及头完全一致，不改写 PCM', () async {
    const writer = PcmWavFileWriter();
    final bytes = await writer.readChunk(
      sourcePath: pcm.path,
      startByte: 2,
      endByte: 6,
    );
    final output = File('${directory.path}/expected.wav');
    await writer.write(
      sourcePath: pcm.path,
      targetPath: output.path,
      startByte: 2,
      endByte: 6,
    );
    expect(bytes, await output.readAsBytes());
    expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 4);
    expect(bytes.sublist(44), [2, 3, 4, 5]);
    expect(await pcm.readAsBytes(), [0, 1, 2, 3, 4, 5, 6, 7]);
  });

  test('内存 WAV 在分配及读取前拒绝超过 60 秒或非法范围', () async {
    const writer = PcmWavFileWriter();
    for (final range in [
      (0, maxInMemoryWavPcmBytes + 2),
      (-2, 4),
      (0, 0),
      (0, 3),
      (1, 4),
      (0, 10),
    ]) {
      await expectLater(
        writer.readChunk(
          sourcePath: pcm.path,
          startByte: range.$1,
          endByte: range.$2,
        ),
        throwsA(
          isA<PcmWavWriteException>().having(
            (error) => error.code,
            'code',
            'wav.invalid_pcm_range',
          ),
        ),
      );
    }
    expect(await directory.list().length, 1);
  });

  test('内存 WAV 接受精确 60 秒上限', () async {
    await pcm.writeAsBytes(Uint8List(maxInMemoryWavPcmBytes));
    final bytes = await const PcmWavFileWriter().readChunk(
      sourcePath: pcm.path,
      startByte: 0,
      endByte: maxInMemoryWavPcmBytes,
    );
    expect(bytes.length, maxInMemoryWavPcmBytes + wavHeaderBytes);
    expect(await directory.list().length, 1);
  });

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
