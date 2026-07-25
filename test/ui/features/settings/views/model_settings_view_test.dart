import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meetily_ai/app/application.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/model_installation.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';
import 'package:meetily_ai/ui/core/asr_model_option.dart';
import 'package:meetily_ai/ui/features/settings/view_models/model_settings_view_model.dart';
import 'package:meetily_ai/ui/features/settings/views/model_settings_view.dart';

import '../../../../support/model_selection_fakes.dart';

void main() {
  final cases = <(ModelInstallation?, String)>[
    (null, '未下载'),
    (_qwenState(ModelInstallationState.downloading), '下载中'),
    (_qwenState(ModelInstallationState.verifying), '校验中'),
    (_qwenState(ModelInstallationState.installed), '已安装'),
    (
      _qwenState(
        ModelInstallationState.failed,
        errorCode: 'model.download.failed',
      ),
      '下载失败',
    ),
    (
      _qwenState(
        ModelInstallationState.failed,
        errorCode: 'model.storage.insufficient',
      ),
      '空间不足',
    ),
  ];

  for (final (installation, expectedStatus) in cases) {
    testWidgets('设置页显示高级模型状态：$expectedStatus', (tester) async {
      final installations = TestActiveInstallations();
      final standard = AsrModelRegistry.alpha.requireById(
        paraformerStandardModelId,
      );
      installations.install(installations.installed(standard), active: true);
      if (installation != null) {
        installations.install(
          installation,
          active: installation.state == ModelInstallationState.installed,
        );
      }
      final viewModel = ModelSettingsViewModel(
        preferences: TestModelPreferences(paraformerStandardModelId),
        installations: installations,
      );

      await tester.pumpWidget(
        Application(home: ModelSettingsView(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FScaffold), findsOneWidget);
      expect(find.text('转录模型'), findsWidgets);
      expect(find.text('标准模型（Paraformer）'), findsOneWidget);
      expect(find.text('已安装'), findsWidgets);
      expect(find.text('高级模型（Qwen3-ASR）'), findsOneWidget);
      expect(
        find.text(expectedStatus),
        expectedStatus == '已安装' ? findsNWidgets(2) : findsOneWidget,
      );
      expect(find.textContaining('约 941 MB'), findsOneWidget);
      expect(tester.takeException(), isNull);

      viewModel.dispose();
      await installations.dispose();
    });
  }

  testWidgets('未下载时下载按钮触发高级模型动作', (tester) async {
    var downloadCalls = 0;
    final installations = TestActiveInstallations();
    final standard = AsrModelRegistry.alpha.requireById(
      paraformerStandardModelId,
    );
    installations.install(installations.installed(standard), active: true);
    final viewModel = ModelSettingsViewModel(
      preferences: TestModelPreferences(paraformerStandardModelId),
      installations: installations,
      actions: AdvancedModelActions(download: () async => downloadCalls++),
    );

    await tester.pumpWidget(
      Application(home: ModelSettingsView(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载高级模型'));
    await tester.pumpAndSettle();

    expect(downloadCalls, 1);
    viewModel.dispose();
    await installations.dispose();
  });

  testWidgets('高级模型下载进行中仍可取消', (tester) async {
    final download = Completer<void>();
    var cancelCalls = 0;
    final installations = TestActiveInstallations();
    final registry = AsrModelRegistry.alpha;
    installations.install(
      installations.installed(registry.requireById(paraformerStandardModelId)),
      active: true,
    );
    final viewModel = ModelSettingsViewModel(
      preferences: TestModelPreferences(paraformerStandardModelId),
      installations: installations,
      actions: AdvancedModelActions(
        download: () => download.future,
        cancel: () {
          cancelCalls++;
          download.complete();
        },
      ),
    );
    await tester.pumpWidget(
      Application(home: ModelSettingsView(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载高级模型'));
    installations.install(
      _qwenState(ModelInstallationState.downloading),
      notify: true,
    );
    await tester.pump();

    await tester.tap(find.text('取消下载'));
    await tester.pumpAndSettle();

    expect(cancelCalls, 1);
    viewModel.dispose();
    await installations.dispose();
  });
}

ModelInstallation _qwenState(
  ModelInstallationState state, {
  String? errorCode,
}) {
  final descriptor = AsrModelRegistry.alpha.requireById(qwenAdvancedModelId);
  return ModelInstallation(
    modelId: descriptor.modelId,
    version: descriptor.version,
    installationType: descriptor.installationType,
    state: state,
    installedPath: state == ModelInstallationState.installed
        ? 'models/qwen'
        : null,
    verifiedAt: state == ModelInstallationState.installed
        ? DateTime.utc(2026, 7, 24)
        : null,
    bytes: state == ModelInstallationState.installed
        ? descriptor.requiredBytes
        : 0,
    lastErrorCode: errorCode,
  );
}
