import 'package:flutter/foundation.dart';

import '../../../../domain/models/runtime_initialization.dart';
import '../../../../domain/use_cases/initialize_runtime_assets.dart';

final class RuntimeInitializationViewModel extends ChangeNotifier {
  RuntimeInitializationViewModel(
    InitializeRuntimeAssetsUseCase initialize, {
    bool forceRepair = false,
  }) : this._(initialize, forceRepair);

  RuntimeInitializationViewModel._(this._initialize, this._forceRepair)
    : _state = const RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.checking,
        completedBytes: 0,
        totalBytes: 0,
        message: '正在准备本地数据',
      );

  final InitializeRuntimeAssetsUseCase _initialize;
  bool _forceRepair;
  RuntimeInitializationProgress _state;
  Future<void>? _operation;
  Future<void>? _resumeOperation;
  bool _pauseRequested = false;
  bool _disposed = false;

  RuntimeInitializationProgress get state => _state;
  bool get isReady => _state.phase == RuntimeInitializationPhase.ready;

  Future<void> start() => _start();

  Future<void> _start({bool resumePausedDownload = false}) {
    final current = _operation;
    if (current != null) {
      return current;
    }
    late final Future<void> operation;
    operation = _run(resumePausedDownload: resumePausedDownload)
        .whenComplete(() {
          if (identical(_operation, operation)) {
            _operation = null;
          }
        });
    _operation = operation;
    return operation;
  }

  Future<void> confirmMobileDownload() async {
    if (_state.phase != RuntimeInitializationPhase.awaitingMobileConsent) {
      return;
    }
    await _initialize.grantMobileConsent();
    await _operation;
    await start();
  }

  void declineMobileDownload() {
    if (_state.phase != RuntimeInitializationPhase.awaitingMobileConsent) {
      return;
    }
    _set(
      RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.failed,
        completedBytes: _state.completedBytes,
        totalBytes: _state.totalBytes,
        message: '已暂不使用移动网络。连接 Wi-Fi 后可重试，现有会议数据不会改变。',
      ),
    );
  }

  Future<void> resume() {
    final current = _resumeOperation;
    if (current != null) {
      return current;
    }
    late final Future<void> operation;
    operation = _resume().whenComplete(() {
      if (identical(_resumeOperation, operation)) {
        _resumeOperation = null;
      }
    });
    _resumeOperation = operation;
    return operation;
  }

  Future<void> _resume() async {
    final resumePausedDownload =
        _state.phase == RuntimeInitializationPhase.paused;
    final current = _operation;
    if (current != null) {
      await current;
    }
    await _start(resumePausedDownload: resumePausedDownload);
    _surfaceRetryFailure();
  }

  void pause() {
    _pauseRequested = true;
    _initialize.pause();
  }

  Future<void> _run({bool resumePausedDownload = false}) async {
    _pauseRequested = false;
    final previous = _state;
    _set(
      RuntimeInitializationProgress(
        phase: resumePausedDownload
            ? RuntimeInitializationPhase.downloading
            : RuntimeInitializationPhase.checking,
        completedBytes: previous.completedBytes,
        totalBytes: previous.totalBytes,
        resourceName: previous.resourceName,
        message: resumePausedDownload ? '正在从当前进度继续下载' : '正在检查本地转录资源',
      ),
    );
    try {
      await _initialize.execute(
        onProgress: (progress) {
          if (resumePausedDownload &&
              progress.phase == RuntimeInitializationPhase.checking) {
            return;
          }
          _set(progress);
          if (_pauseRequested &&
              progress.phase == RuntimeInitializationPhase.downloading) {
            _initialize.pause();
          }
        },
        forceRepair: _forceRepair,
      );
      _forceRepair = false;
    } on RuntimeInitializationException catch (error) {
      final phase = switch (error.code) {
        'runtime.network.mobileConsentRequired' =>
          RuntimeInitializationPhase.awaitingMobileConsent,
        'runtime.storage.insufficient' =>
          RuntimeInitializationPhase.insufficientSpace,
        'runtime.download.paused' => RuntimeInitializationPhase.paused,
        _ => RuntimeInitializationPhase.failed,
      };
      _set(
        RuntimeInitializationProgress(
          phase: phase,
          completedBytes: _state.completedBytes,
          totalBytes: _state.totalBytes,
          resourceName: _state.resourceName,
          message: error.message,
          messageCode: error.code,
          shortageBytes: error.shortageBytes,
        ),
      );
    } on Object {
      _set(
        RuntimeInitializationProgress(
          phase: RuntimeInitializationPhase.failed,
          completedBytes: _state.completedBytes,
          totalBytes: _state.totalBytes,
          resourceName: _state.resourceName,
          message: '离线转录资源准备失败，请重试',
        ),
      );
    } finally {
      _pauseRequested = false;
    }
  }

  void _set(RuntimeInitializationProgress value) {
    if (_disposed) {
      return;
    }
    _state = value;
    notifyListeners();
  }

  void _surfaceRetryFailure() {
    final state = _state;
    if (state.phase != RuntimeInitializationPhase.failed &&
        state.phase != RuntimeInitializationPhase.insufficientSpace) {
      return;
    }
    final message = state.message;
    if (message == null || message.startsWith('重试未成功：')) {
      return;
    }
    _set(
      RuntimeInitializationProgress(
        phase: state.phase,
        completedBytes: state.completedBytes,
        totalBytes: state.totalBytes,
        resourceName: state.resourceName,
        message: '重试未成功：$message',
        messageCode: state.messageCode,
        shortageBytes: state.shortageBytes,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _initialize.pause();
    super.dispose();
  }
}
