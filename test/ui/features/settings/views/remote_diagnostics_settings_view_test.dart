import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/ui/core/asr_model_option.dart';
import 'package:meettrace/ui/features/settings/view_models/model_settings_view_model.dart';
import 'package:meettrace/ui/features/settings/view_models/remote_diagnostics_settings_view_model.dart';
import 'package:meettrace/ui/features/settings/views/model_settings_view.dart';

import '../../../../support/model_selection_fakes.dart';

void main() {
  testWidgets('设置页默认开启远程诊断并允许退出', (tester) async {
    final installations = TestActiveInstallations();
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    installations.install(installations.installed(descriptor), active: true);
    final modelSettings = ModelSettingsViewModel(
      preferences: TestModelPreferences(senseVoiceDefaultModelId),
      installations: installations,
      actions: const ModelMaintenanceActions(),
    );
    final preferences = _RemoteDiagnosticsPreferences();
    final controller = _RemoteDiagnosticsController();
    final remoteDiagnostics = RemoteDiagnosticsSettingsViewModel(
      preferences: preferences,
      controller: controller,
    );

    await tester.pumpWidget(
      Application(
        home: ModelSettingsView(
          viewModel: modelSettings,
          remoteDiagnostics: remoteDiagnostics,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final disclosure = find.byKey(
      const ValueKey('remote-diagnostics-disclosure'),
    );
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(
      const ValueKey('remote-diagnostics-switch'),
    );
    expect(switchFinder, findsOneWidget);
    final initialSwitch = tester.widget<FSwitch>(switchFinder);
    expect(initialSwitch.value, isTrue);
    expect(initialSwitch.enabled, isTrue);
    await tester.ensureVisible(switchFinder);
    final switchRect = tester.getRect(switchFinder);
    // FSwitch 的根节点包含整行标签；点击右侧轨道，而不是不可点击的行中心。
    await tester.tapAt(Offset(switchRect.right - 24, switchRect.center.dy));
    await tester.pumpAndSettle();

    expect(preferences.savedEnabled, isFalse);
    expect(controller.appliedEnabled, isFalse);

    remoteDiagnostics.dispose();
    modelSettings.dispose();
    await installations.dispose();
  });
}

final class _RemoteDiagnosticsPreferences
    implements RemoteDiagnosticsPreferenceRepository {
  bool? savedEnabled;

  @override
  Future<bool> getEnabled() async => true;

  @override
  Future<bool> getNoticeDismissed() async => false;

  @override
  Future<void> setEnabled(bool enabled) async => savedEnabled = enabled;

  @override
  Future<void> setNoticeDismissed() async {}
}

final class _RemoteDiagnosticsController
    implements RemoteDiagnosticsController {
  bool? appliedEnabled;

  @override
  Future<bool> setEnabled(bool enabled) async {
    appliedEnabled = enabled;
    return true;
  }
}
