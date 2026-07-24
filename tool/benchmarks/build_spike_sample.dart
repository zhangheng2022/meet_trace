import 'dart:io';
import 'dart:typed_data';

void main(List<String> arguments) {
  if (arguments.length < 3) {
    stderr.writeln(
      '用法：dart run tool/benchmarks/build_spike_sample.dart '
      '<输出 WAV> <秒数> <源 WAV...>',
    );
    exitCode = 64;
    return;
  }

  final outputPath = arguments[0];
  final durationSeconds = int.tryParse(arguments[1]);
  if (durationSeconds == null || durationSeconds <= 0) {
    stderr.writeln('秒数必须是正整数。');
    exitCode = 64;
    return;
  }

  final sources = arguments.skip(2).map(_readPcm16MonoWave).toList();
  final sampleRate = sources.first.sampleRate;
  if (sources.any((source) => source.sampleRate != sampleRate)) {
    stderr.writeln('所有源 WAV 必须使用相同采样率。');
    exitCode = 65;
    return;
  }

  final targetDataBytes = durationSeconds * sampleRate * 2;
  final output = File(outputPath);
  output.parent.createSync(recursive: true);
  final sink = output.openSync(mode: FileMode.write);
  try {
    sink.writeFromSync(_waveHeader(sampleRate, targetDataBytes));
    var written = 0;
    var sourceIndex = 0;
    while (written < targetDataBytes) {
      final samples = sources[sourceIndex % sources.length].pcmBytes;
      final count = (targetDataBytes - written).clamp(0, samples.length);
      sink.writeFromSync(samples, 0, count);
      written += count;
      sourceIndex += 1;
    }
    sink.flushSync();
  } finally {
    sink.closeSync();
  }

  stdout.writeln(
    '已生成 ${durationSeconds}s、${sampleRate}Hz、单声道 PCM16：$outputPath',
  );
}

_Pcm16Wave _readPcm16MonoWave(String path) {
  final bytes = File(path).readAsBytesSync();
  if (bytes.length < 44 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    throw FormatException('不是有效 WAV：$path');
  }

  final data = ByteData.sublistView(bytes);
  var offset = 12;
  int? sampleRate;
  Uint8List? pcmBytes;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    final payloadOffset = offset + 8;
    if (payloadOffset + size > bytes.length) {
      throw FormatException('WAV chunk 越界：$path');
    }

    if (id == 'fmt ') {
      final format = data.getUint16(payloadOffset, Endian.little);
      final channels = data.getUint16(payloadOffset + 2, Endian.little);
      sampleRate = data.getUint32(payloadOffset + 4, Endian.little);
      final bitsPerSample = data.getUint16(payloadOffset + 14, Endian.little);
      if (format != 1 || channels != 1 || bitsPerSample != 16) {
        throw FormatException('只支持单声道 PCM16 WAV：$path');
      }
    } else if (id == 'data') {
      pcmBytes = Uint8List.fromList(
        bytes.sublist(payloadOffset, payloadOffset + size),
      );
    }
    offset = payloadOffset + size + (size.isOdd ? 1 : 0);
  }

  if (sampleRate == null || pcmBytes == null || pcmBytes.isEmpty) {
    throw FormatException('WAV 缺少 fmt 或 data：$path');
  }
  return _Pcm16Wave(sampleRate: sampleRate, pcmBytes: pcmBytes);
}

Uint8List _waveHeader(int sampleRate, int dataBytes) {
  final header = ByteData(44);
  _writeAscii(header, 0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  _writeAscii(header, 8, 'WAVE');
  _writeAscii(header, 12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  _writeAscii(header, 36, 'data');
  header.setUint32(40, dataBytes, Endian.little);
  return header.buffer.asUint8List();
}

void _writeAscii(ByteData data, int offset, String value) {
  for (var index = 0; index < value.length; index++) {
    data.setUint8(offset + index, value.codeUnitAt(index));
  }
}

final class _Pcm16Wave {
  const _Pcm16Wave({required this.sampleRate, required this.pcmBytes});

  final int sampleRate;
  final Uint8List pcmBytes;
}
