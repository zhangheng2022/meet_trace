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
  bool _disposed = false;

  RuntimeInitializationProgress get state => _state;
  bool get isReady => _state.phase == RuntimeInitializationPhase.ready;

  Future<void> start() {
    final current = _operation;
    if (current != null) {
      return current;
    }
    late final Future<void> operation;
    operation = _run().whenComplete(() {
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

  Future<void> resume() async {
    await _operation;
    await start();
  }

  void pause() => _initialize.pause();

  Future<void> _run() async {
    _set(
      RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.checking,
        completedBytes: _state.completedBytes,
        totalBytes: _state.totalBytes,
        message: '正在检查本地转录资源',
      ),
    );
    try {
      await _initialize.execute(onProgress: _set, forceRepair: _forceRepair);
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
          message: error.message,
          shortageBytes: error.shortageBytes,
        ),
      );
    } on Object {
      _set(
        RuntimeInitializationProgress(
          phase: RuntimeInitializationPhase.failed,
          completedBytes: _state.completedBytes,
          totalBytes: _state.totalBytes,
          message: '离线转录资源准备失败，请重试',
        ),
      );
    }
  }

  void _set(RuntimeInitializationProgress value) {
    if (_disposed) {
      return;
    }
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _initialize.pause();
    super.dispose();
  }
}
