import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/ui/core/asr_model_option.dart';
import 'package:meettrace/ui/features/settings/view_models/model_settings_view_model.dart';
import 'package:meettrace/ui/features/settings/views/model_settings_view.dart';

import '../../../../support/model_selection_fakes.dart';

void main() {
  testWidgets('设置页只显示真实 SenseVoice 且没有删除或占位模型', (tester) async {
    final installations = TestActiveInstallations();
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    installations.install(installations.installed(descriptor), active: true);
    final viewModel = ModelSettingsViewModel(
      preferences: TestModelPreferences(senseVoiceDefaultModelId),
      installations: installations,
      actions: const ModelMaintenanceActions(),
    );

    await tester.pumpWidget(
      Application(home: ModelSettingsView(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.text('SenseVoice'), findsOneWidget);
    expect(find.textContaining('239.5 MB'), findsOneWidget);
    expect(find.textContaining('高级'), findsNothing);
    expect(find.textContaining('标准'), findsNothing);
    expect(find.textContaining('即将'), findsNothing);
    expect(find.textContaining('删除'), findsNothing);
    viewModel.dispose();
    await installations.dispose();
  });

  testWidgets('下载中可以暂停并保留分片', (tester) async {
    var pauseCalls = 0;
    final installations = TestActiveInstallations();
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    installations.install(
      ModelInstallation(
        modelId: descriptor.modelId,
        version: descriptor.version,
        installationType: descriptor.installationType,
        state: ModelInstallationState.downloading,
        bytes: 0,
      ),
    );
    final viewModel = ModelSettingsViewModel(
      preferences: TestModelPreferences(senseVoiceDefaultModelId),
      installations: installations,
      actions: ModelMaintenanceActions(pause: () => pauseCalls++),
    );

    await tester.pumpWidget(
      Application(home: ModelSettingsView(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    final pause = find.text('暂停下载');
    await tester.ensureVisible(pause);
    await tester.tap(pause);
    await tester.pump();

    expect(pauseCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    viewModel.dispose();
    await installations.dispose();
  });
}
