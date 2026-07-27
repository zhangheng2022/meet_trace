import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/ui/core/asr_model_option.dart';
import 'package:meettrace/ui/features/settings/view_models/model_settings_view_model.dart';

import '../../../../support/model_selection_fakes.dart';

void main() {
  late TestModelPreferences preferences;
  late TestActiveInstallations installations;

  setUp(() {
    preferences = TestModelPreferences(paraformerStandardModelId);
    installations = TestActiveInstallations();
    final standard = AsrModelRegistry.alpha.requireById(
      paraformerStandardModelId,
    );
    installations.install(installations.installed(standard), active: true);
  });

  tearDown(() => installations.dispose());

  test('加载全局默认和双模型安装状态', () async {
    final viewModel = ModelSettingsViewModel(
      preferences: preferences,
      installations: installations,
    );

    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.defaultModelId, paraformerStandardModelId);
    expect(viewModel.options, hasLength(2));
    expect(
      viewModel.optionFor(paraformerStandardModelId).status,
      AsrModelUiStatus.installed,
    );
    expect(
      viewModel.optionFor(qwenAdvancedModelId).status,
      AsrModelUiStatus.notInstalled,
    );
    viewModel.dispose();
  });

  test('只有已安装模型可以保存为后续会议默认值', () async {
    final qwen = AsrModelRegistry.alpha.requireById(qwenAdvancedModelId);
    final viewModel = ModelSettingsViewModel(
      preferences: preferences,
      installations: installations,
    );
    await viewModel.load();

    await viewModel.selectDefault(qwen.modelId);
    expect(preferences.setCalls, isEmpty);
    expect(viewModel.errorMessage, '请先下载并校验高级模型');

    installations.install(
      installations.installed(qwen),
      active: true,
      notify: true,
    );
    await Future<void>.delayed(Duration.zero);
    await viewModel.selectDefault(qwen.modelId);

    expect(preferences.setCalls, [qwen.modelId]);
    expect(viewModel.defaultModelId, qwen.modelId);
    viewModel.dispose();
  });

  test('下载、取消、重试和删除动作由 ViewModel 统一转发', () async {
    final calls = <String>[];
    final viewModel = ModelSettingsViewModel(
      preferences: preferences,
      installations: installations,
      actions: AdvancedModelActions(
        download: () async => calls.add('download'),
        cancel: () => calls.add('cancel'),
        retry: () async => calls.add('retry'),
        delete: () async => calls.add('delete'),
      ),
    );
    await viewModel.load();

    await viewModel.downloadAdvanced();
    viewModel.cancelAdvanced();
    await viewModel.retryAdvanced();
    await viewModel.deleteAdvanced();

    expect(calls, ['download', 'cancel', 'retry', 'delete']);
    viewModel.dispose();
  });
}
