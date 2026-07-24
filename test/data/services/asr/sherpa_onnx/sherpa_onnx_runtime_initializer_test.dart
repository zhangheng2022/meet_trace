import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';
import 'package:meetily_ai/domain/models/app_failure.dart';

void main() {
  test('官方 bindings 在同一 isolate 只初始化一次', () {
    final bindings = _FakeBindings();
    final initializer = SherpaOnnxRuntimeInitializer(bindings: bindings);

    final first = initializer.initialize();
    final second = initializer.initialize();

    expect(first.isReady, true);
    expect(second, same(first));
    expect(bindings.initializeCalls, 1);
  });

  test('bindings 异常转换为结构化失败且不阻止应用继续启动', () {
    final initializer = SherpaOnnxRuntimeInitializer(
      bindings: _FakeBindings(error: StateError('native failed')),
    );

    final status = initializer.initialize();

    expect(status.isReady, false);
    expect(status.failure?.code, 'asr.official.bindings_initialization_failed');
    expect(status.failure?.stage, FailureStage.asrInitialization);
    expect(status.failure?.recoverability, FailureRecoverability.retryable);
    expect(status.failure?.userAction, FailureUserAction.retry);
    expect(status.failure?.diagnosticContext['errorType'], 'StateError');
  });
}

final class _FakeBindings implements SherpaOnnxBindings {
  _FakeBindings({this.error});

  final Object? error;
  int initializeCalls = 0;

  @override
  void initialize() {
    initializeCalls++;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
  }
}
