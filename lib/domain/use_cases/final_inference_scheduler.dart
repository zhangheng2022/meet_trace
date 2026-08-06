import 'dart:async';

/// 跨会议共享的最终推理 FIFO 调度器。
///
/// Alpha 默认并发度为 1，避免 ASR 与说话人分离在多场会议间争抢内存、CPU
/// 和温控预算。调用方取消等待不会取消已经入队的事实音频处理。
final class FinalInferenceScheduler {
  Future<void> _tail = Future<void>.value();

  Future<T> schedule<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}
