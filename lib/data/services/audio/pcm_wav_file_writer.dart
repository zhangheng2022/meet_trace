import 'dart:io';
import 'dart:typed_data';

const pcmSampleRate = 16000;
const pcmChannels = 1;
const pcmBitsPerSample = 16;
const pcmBytesPerSample = pcmBitsPerSample ~/ 8;
const pcmBytesPerMillisecond =
    pcmSampleRate * pcmChannels * pcmBytesPerSample ~/ 1000;
const wavHeaderBytes = 44;
const maxWavPcmBytes = 0xffffffff - 36;

final class PcmWavWriteException implements Exception {
  const PcmWavWriteException(this.code);

  final String code;
}

final class PcmWavFileWriter {
  const PcmWavFileWriter();

  int wavLengthForPcm(int pcmBytes) {
    if (pcmBytes <= 0 ||
        pcmBytes > maxWavPcmBytes ||
        pcmBytes % pcmBytesPerSample != 0) {
      throw const PcmWavWriteException('wav.invalid_pcm_length');
    }
    return wavHeaderBytes + pcmBytes;
  }

  Future<void> write({
    required String sourcePath,
    required String targetPath,
    int startByte = 0,
    int? endByte,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const PcmWavWriteException('wav.source_missing');
    }
    final sourceLength = await source.length();
    final resolvedEnd = endByte ?? sourceLength;
    if (startByte < 0 ||
        resolvedEnd <= startByte ||
        resolvedEnd > sourceLength ||
        startByte % pcmBytesPerSample != 0 ||
        resolvedEnd % pcmBytesPerSample != 0) {
      throw const PcmWavWriteException('wav.invalid_pcm_range');
    }

    final dataLength = resolvedEnd - startByte;
    wavLengthForPcm(dataLength);
    final input = await source.open();
    final output = await File(targetPath).open(mode: FileMode.write);
    try {
      await input.setPosition(startByte);
      final header = Uint8List(wavHeaderBytes);
      _writeWavHeader(header, dataLength);
      await output.writeFrom(header);
      var remaining = dataLength;
      while (remaining > 0) {
        final chunk = await input.read(
          remaining > 64 * 1024 ? 64 * 1024 : remaining,
        );
        if (chunk.isEmpty) {
          throw const PcmWavWriteException('wav.source_read_incomplete');
        }
        await output.writeFrom(chunk);
        remaining -= chunk.length;
      }
      await output.flush();
    } finally {
      await input.close();
      await output.close();
    }
  }
}

void _writeWavHeader(Uint8List target, int dataLength) {
  final data = ByteData.sublistView(target);
  _writeAscii(target, 0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  _writeAscii(target, 8, 'WAVE');
  _writeAscii(target, 12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, pcmChannels, Endian.little)
    ..setUint32(24, pcmSampleRate, Endian.little)
    ..setUint32(
      28,
      pcmSampleRate * pcmChannels * pcmBytesPerSample,
      Endian.little,
    )
    ..setUint16(32, pcmChannels * pcmBytesPerSample, Endian.little)
    ..setUint16(34, pcmBitsPerSample, Endian.little);
  _writeAscii(target, 36, 'data');
  data.setUint32(40, dataLength, Endian.little);
}

void _writeAscii(Uint8List target, int offset, String value) {
  target.setRange(offset, offset + value.length, value.codeUnits);
}
