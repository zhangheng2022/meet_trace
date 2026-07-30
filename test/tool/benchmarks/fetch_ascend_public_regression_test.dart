import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/benchmarks/fetch_ascend_public_regression.dart';

void main() {
  test('选择固定数量、时长合规且来源受限的 ASCEND 样本', () {
    final rows = [
      _row(0, duration: 0.5),
      for (var index = 1; index <= 20; index++)
        _row(index, duration: 1 + index / 100),
      _row(21, duration: 4),
    ];

    final selected = selectAscendRows(
      rows,
      sampleCount: 20,
      minimumDurationSeconds: 1,
      maximumDurationSeconds: 3,
    );

    expect(selected, hasLength(20));
    expect(selected.first.rowIndex, 1);
    expect(selected.last.rowIndex, 20);
    expect(selected.first.language, 'mixed');
  });

  test('拒绝非 Hugging Face HTTPS 音频来源', () {
    final rows = [_row(0, duration: 2, host: 'example.com')];

    expect(
      () => selectAscendRows(
        rows,
        sampleCount: 1,
        minimumDurationSeconds: 1,
        maximumDurationSeconds: 3,
      ),
      throwsA(isA<AscendRegressionException>()),
    );

    final nonStandardPort = [
      _row(0, duration: 2, host: 'datasets-server.huggingface.co:8443'),
    ];
    expect(
      () => selectAscendRows(
        nonStandardPort,
        sampleCount: 1,
        minimumDurationSeconds: 1,
        maximumDurationSeconds: 3,
      ),
      throwsA(isA<AscendRegressionException>()),
    );
  });

  test('从带额外 chunk 的 WAV 提取 16kHz 单声道 PCM16LE', () {
    final pcm = Uint8List.fromList([0, 0, 255, 127, 0, 128]);
    final wav = _wav(pcm, includeJunkChunk: true);

    expect(extractPcm16Mono16Khz(wav), pcm);
  });

  test('拒绝立体声或损坏的 WAV', () {
    expect(
      () => extractPcm16Mono16Khz(_wav(Uint8List(4), channels: 2)),
      throwsA(isA<AscendRegressionException>()),
    );
    expect(
      () => extractPcm16Mono16Khz(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<AscendRegressionException>()),
    );
  });
}

Map<String, Object?> _row(
  int index, {
  required double duration,
  String host = 'datasets-server.huggingface.co',
}) {
  return {
    'row_idx': index,
    'row': {
      'id': index.toString().padLeft(5, '0'),
      'duration': duration,
      'language': 'mixed',
      'transcription': '测试 transcription $index',
      'audio': [
        {
          'type': 'audio/wav',
          'src': 'https://$host/cached-assets/audio-$index.wav',
        },
      ],
    },
  };
}

Uint8List _wav(
  Uint8List pcm, {
  int channels = 1,
  bool includeJunkChunk = false,
}) {
  final junkSize = includeJunkChunk ? 10 : 0;
  final totalLength =
      12 + 8 + 16 + (includeJunkChunk ? 8 + junkSize : 0) + 8 + pcm.length;
  final bytes = Uint8List(totalLength);
  final data = ByteData.sublistView(bytes);
  var offset = 0;

  void fourCc(String value) {
    for (final codeUnit in value.codeUnits) {
      bytes[offset++] = codeUnit;
    }
  }

  fourCc('RIFF');
  data.setUint32(offset, totalLength - 8, Endian.little);
  offset += 4;
  fourCc('WAVE');
  fourCc('fmt ');
  data.setUint32(offset, 16, Endian.little);
  offset += 4;
  data.setUint16(offset, 1, Endian.little);
  data.setUint16(offset + 2, channels, Endian.little);
  data.setUint32(offset + 4, 16000, Endian.little);
  data.setUint32(offset + 8, 16000 * channels * 2, Endian.little);
  data.setUint16(offset + 12, channels * 2, Endian.little);
  data.setUint16(offset + 14, 16, Endian.little);
  offset += 16;
  if (includeJunkChunk) {
    fourCc('JUNK');
    data.setUint32(offset, junkSize, Endian.little);
    offset += 4 + junkSize;
  }
  fourCc('data');
  data.setUint32(offset, pcm.length, Endian.little);
  offset += 4;
  bytes.setRange(offset, offset + pcm.length, pcm);
  return bytes;
}
