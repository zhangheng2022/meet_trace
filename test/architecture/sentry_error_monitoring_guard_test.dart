import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('后台推理 Isolate 在执行前接入并在退出时释放 Sentry 错误监听', () async {
    for (final path in <String>[
      'lib/data/services/asr/sherpa_onnx/sherpa_onnx_adapter.dart',
      'lib/data/services/diarization/'
          'sherpa_onnx_speaker_diarization_worker.dart',
    ]) {
      final source = await File(path).readAsString();

      expect(source, contains('paused: true'));
      final attachAt = source.indexOf(
        'SentryIsolateErrorMonitor.attach(isolate)',
      );
      final resumeAt = source.indexOf(
        'isolate.resume(isolate.pauseCapability!)',
      );
      expect(attachAt, isNonNegative, reason: '$path 缺少错误监听');
      expect(resumeAt, isNonNegative, reason: '$path 缺少恢复执行');
      expect(attachAt, lessThan(resumeAt), reason: '$path 必须先监听再执行');
      expect(source, contains('_sentryErrors.close()'));
    }
  });
}
