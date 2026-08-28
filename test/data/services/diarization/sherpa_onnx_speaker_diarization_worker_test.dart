import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/diarization/speaker_diarization_worker.dart';

void main() {
  test('说话人分离不得使用 isolateLocal 进度回调', () async {
    final source = await File(
      'lib/data/services/diarization/'
      'sherpa_onnx_speaker_diarization_worker.dart',
    ).readAsString();

    expect(source, isNot(contains('processWithCallback')));
    expect(
      RegExp(
        r'active\.process\(\s*samples:\s*samples,?\s*\)',
        multiLine: true,
      ).hasMatch(source),
      isTrue,
    );
  });

  test('整段 PCM 转换超过内存上限时在分配前拒绝', () {
    expect(
      speakerDiarizationPcmFitsMemory(maximumSpeakerDiarizationFloatBytes ~/ 2),
      isTrue,
    );
    expect(
      speakerDiarizationPcmFitsMemory(
        maximumSpeakerDiarizationFloatBytes ~/ 2 + 2,
      ),
      isFalse,
    );
  });
}
