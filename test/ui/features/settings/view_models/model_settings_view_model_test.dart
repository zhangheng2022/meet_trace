import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/ui/core/asr_model_option.dart';
import 'package:meettrace/ui/features/settings/view_models/model_settings_view_model.dart';

import '../../../../support/model_selection_fakes.dart';

void main() {
  late TestModelPreferences preferences;
  late TestActiveInstallations installations;

  setUp(() {
    preferences = TestModelPreferences(senseVoiceDefaultModelId);
    installations = TestActiveInstallations();
  });

  tearDown(() => installations.dispose());

  test('加载唯一默认 SenseVoice 安装状态', () async {
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    installations.install(installations.installed(descriptor), active: true);
    final viewModel = ModelSettingsViewModel(
      preferences: preferences,
      installations: installations,
    );

    await viewModel.load();

    expect(viewModel.defaultModelId, senseVoiceDefaultModelId);
    expect(viewModel.options, hasLength(1));
    expect(viewModel.options.single.status, AsrModelUiStatus.installed);
    viewModel.dispose();
  });

  test('未安装时不能选择为默认模型', () async {
    final viewModel = ModelSettingsViewModel(
      preferences: preferences,
      installations: installations,
    );
    await viewModel.load();

    await viewModel.selectDefault(senseVoiceDefaultModelId);

    expect(preferences.setCalls, isEmpty);
    expect(viewModel.errorMessage, 'SenseVoice 尚未安装或校验未通过');
    viewModel.dispose();
  });

  test('校验修复与暂停动作由 ViewModel 转发', () async {
    final calls = <String>[];
    final viewModel = ModelSettingsViewModel(
      preferences: preferences,
      installations: installations,
      actions: ModelMaintenanceActions(
        repair: () async => calls.add('repair'),
        pause: () => calls.add('pause'),
      ),
    );
    await viewModel.load();

    await viewModel.repairModel();
    viewModel.pauseRepair();

    expect(calls, ['repair', 'pause']);
    viewModel.dispose();
  });
}
