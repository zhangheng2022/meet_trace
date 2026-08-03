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
        completedBytes: 239762595,
        totalBytes: 239762595,
      ),
    );
  }

  @override
  Future<void> grantMobileConsent() async => grants++;

  @override
  void pause() => pauses++;
}
