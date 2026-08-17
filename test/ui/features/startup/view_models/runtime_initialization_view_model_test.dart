import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/runtime_initialization.dart';
import 'package:meettrace/domain/ports/runtime_asset_preparation.dart';
import 'package:meettrace/domain/use_cases/initialize_runtime_assets.dart';
import 'package:meettrace/ui/features/startup/view_models/runtime_initialization_view_model.dart';

void main() {
  test('移动网络确认绑定资源版本并在同一 ViewModel 中继续', () async {
    final port = _Preparation();
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(port),
    );

    await viewModel.start();
    expect(
      viewModel.state.phase,
      RuntimeInitializationPhase.awaitingMobileConsent,
    );

    await viewModel.confirmMobileDownload();
    expect(port.grants, 1);
    expect(viewModel.isReady, isTrue);
    viewModel.dispose();
  });

  test('拒绝移动网络后保持阻断且不授予同意', () async {
    final port = _Preparation();
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(port),
    );

    await viewModel.start();
    viewModel.declineMobileDownload();

    expect(viewModel.state.phase, RuntimeInitializationPhase.failed);
    expect(viewModel.state.message, contains('暂不使用移动网络'));
    expect(port.grants, 0);
    viewModel.dispose();
  });

  test('暂停会转发给初始化端口并保留 paused 状态', () async {
    final port = _Preparation(paused: true);
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(port),
    );

    await viewModel.start();
    expect(viewModel.state.phase, RuntimeInitializationPhase.paused);
    viewModel.pause();
    expect(port.pauses, 1);
    viewModel.dispose();
  });

  test('重试仍失败时更新提示以提供明确反馈', () async {
    final port = _OfflinePreparation();
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(port),
    );

    await viewModel.start();
    expect(viewModel.state.message, '首次初始化需要联网下载离线运行资源');

    final firstRetry = viewModel.resume();
    final duplicateRetry = viewModel.resume();
    expect(identical(firstRetry, duplicateRetry), isTrue);
    await firstRetry;

    expect(port.attempts, 2);
    expect(viewModel.state.message, '重试未成功：首次初始化需要联网下载离线运行资源');
    viewModel.dispose();
  });

  test('重试下载期间手动暂停只显示暂停状态', () async {
    final port = _PauseOnResumePreparation();
    final viewModel = RuntimeInitializationViewModel(
      InitializeRuntimeAssetsUseCase(port),
    );

    await viewModel.start();
    final retry = viewModel.resume();
    expect(viewModel.state.phase, RuntimeInitializationPhase.downloading);

    viewModel.pause();
    expect(port.pauses, 1);
    port.completePreflight();
    await port.downloadStarted.future;
    await retry;

    expect(port.pauses, 2);
    expect(viewModel.state.phase, RuntimeInitializationPhase.paused);
    expect(viewModel.state.message, '下载已暂停，已完成的分片会保留');
    expect(viewModel.state.message, isNot(startsWith('重试未成功：')));
    viewModel.dispose();
  });
}

final class _PauseOnResumePreparation implements RuntimeAssetPreparationPort {
  final Completer<void> _preflightCompletion = Completer<void>();
  final Completer<void> downloadStarted = Completer<void>();
  final Completer<void> _pauseSignal = Completer<void>();
  int attempts = 0;
  int pauses = 0;
  bool _downloadActive = false;

  @override
  Future<void> prepare({
    required void Function(RuntimeInitializationProgress progress) onProgress,
    bool forceRepair = false,
  }) async {
    attempts++;
    if (attempts == 1) {
      throw const RuntimeInitializationException(
        code: 'runtime.download.paused',
        message: '下载已暂停，已完成的分片会保留',
      );
    }
    onProgress(
      const RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.checking,
        completedBytes: 27000000,
        totalBytes: 286314800,
        resourceName: 'SenseVoice',
      ),
    );
    await _preflightCompletion.future;
    _downloadActive = true;
    onProgress(
      const RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.downloading,
        completedBytes: 27000000,
        totalBytes: 286314800,
        resourceName: 'SenseVoice',
      ),
    );
    downloadStarted.complete();
    await _pauseSignal.future;
    throw const RuntimeInitializationException(
      code: 'runtime.download.paused',
      message: '下载已暂停，已完成的分片会保留',
    );
  }

  void completePreflight() {
    if (!_preflightCompletion.isCompleted) {
      _preflightCompletion.complete();
    }
  }

  @override
  Future<void> grantMobileConsent() async {}

  @override
  void pause() {
    pauses++;
    if (_downloadActive && !_pauseSignal.isCompleted) {
      _pauseSignal.complete();
    }
  }
}

final class _OfflinePreparation implements RuntimeAssetPreparationPort {
  int attempts = 0;

  @override
  Future<void> prepare({
    required void Function(RuntimeInitializationProgress progress) onProgress,
    bool forceRepair = false,
  }) async {
    attempts++;
    throw const RuntimeInitializationException(
      code: 'runtime.network.offline',
      message: '首次初始化需要联网下载离线运行资源',
    );
  }

  @override
  Future<void> grantMobileConsent() async {}

  @override
  void pause() {}
}

final class _Preparation implements RuntimeAssetPreparationPort {
  _Preparation({this.paused = false});
  final bool paused;
  int grants = 0;
  int pauses = 0;

  @override
  Future<void> prepare({
    required void Function(RuntimeInitializationProgress progress) onProgress,
    bool forceRepair = false,
  }) async {
    if (paused) {
      throw const RuntimeInitializationException(
        code: 'runtime.download.paused',
        message: '已暂停',
      );
    }
    if (grants == 0) {
      throw const RuntimeInitializationException(
        code: 'runtime.network.mobileConsentRequired',
        message: '需要移动网络确认',
      );
    }
    onProgress(
      const RuntimeInitializationProgress(
        phase: RuntimeInitializationPhase.ready,
        completedBytes: 286314800,
        totalBytes: 286314800,
      ),
    );
  }

  @override
  Future<void> grantMobileConsent() async => grants++;

  @override
  void pause() => pauses++;
}
