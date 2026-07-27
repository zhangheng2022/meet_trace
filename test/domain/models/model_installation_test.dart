import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/domain_exception.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/workflow_states.dart';

void main() {
  test('installed 状态必须包含安装路径和校验时间', () {
    expect(
      () => ModelInstallation(
        modelId: 'qwen',
        version: '1',
        installationType: AsrInstallationType.downloadable,
        state: ModelInstallationState.installed,
        bytes: 100,
      ),
      throwsArgumentError,
    );
  });

  test('校验完成后可以原子形成已安装记录', () {
    final verifying = ModelInstallation(
      modelId: 'qwen',
      version: '1',
      installationType: AsrInstallationType.downloadable,
      state: ModelInstallationState.verifying,
      bytes: 100,
    );

    final installed = verifying.transitionTo(
      ModelInstallationState.installed,
      installedPath: '/models/qwen/1',
      verifiedAt: DateTime.utc(2026, 7, 24),
    );

    expect(installed.state, ModelInstallationState.installed);
    expect(installed.installedPath, '/models/qwen/1');
  });

  test('内置标准模型不能进入删除状态', () {
    final bundled = ModelInstallation(
      modelId: 'paraformer',
      version: '1',
      installationType: AsrInstallationType.bundled,
      state: ModelInstallationState.installed,
      installedPath: '/models/paraformer/1',
      verifiedAt: DateTime.utc(2026, 7, 24),
      bytes: 100,
    );

    expect(
      () => bundled.transitionTo(ModelInstallationState.deleting),
      throwsA(isA<DomainInvariantViolation>()),
    );
  });
}
