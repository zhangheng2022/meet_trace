import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart';
import 'package:meettrace/domain/models/app_failure.dart';

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

  test('bindings 初始化失败后允许显式重试且成功后只初始化一次', () {
    final bindings = _FakeBindings(failuresRemaining: 1);
    final initializer = SherpaOnnxRuntimeInitializer(bindings: bindings);

    expect(initializer.initialize().isReady, isFalse);
    expect(initializer.initialize().isReady, isTrue);
    expect(initializer.initialize().isReady, isTrue);
    expect(bindings.initializeCalls, 2);
  });
}

final class _FakeBindings implements SherpaOnnxBindings {
  _FakeBindings({this.error, this.failuresRemaining = 0});

  final Object? error;
  int failuresRemaining;
  int initializeCalls = 0;

  @override
  void initialize() {
    initializeCalls++;
    Object? failure = error;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      failure = StateError('native failed');
    }
    if (failure != null) {
      throw failure;
    }
  }
}
