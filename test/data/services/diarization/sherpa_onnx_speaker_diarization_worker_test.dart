import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}
