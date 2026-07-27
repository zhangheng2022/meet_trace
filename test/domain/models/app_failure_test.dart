import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/app_failure.dart';

void main() {
  test('结构化错误保留阶段、恢复性、用户动作和只读诊断上下文', () {
    final context = <String, Object?>{'queuedAudioMs': 15000};
    final failure = AppFailure(
      code: 'asr.queue_overflow',
      stage: FailureStage.asrInference,
      recoverability: FailureRecoverability.retryable,
      userAction: FailureUserAction.retry,
      diagnosticContext: context,
    );

    context['queuedAudioMs'] = 0;

    expect(failure.diagnosticContext['queuedAudioMs'], 15000);
    expect(() => failure.diagnosticContext.clear(), throwsUnsupportedError);
  });
}
