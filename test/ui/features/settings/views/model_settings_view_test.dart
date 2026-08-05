import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/data_control.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/local_data_control.dart';
import 'package:meettrace/domain/ports/text_share.dart';
import 'package:meettrace/domain/use_cases/build_meeting_share.dart';
import 'package:meettrace/ui/core/asr_model_option.dart';
import 'package:meettrace/ui/features/settings/view_models/data_controls_view_model.dart';
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

    expect(find.text('SenseVoice'), findsNWidgets(2));
    expect(find.textContaining('239.5 MB'), findsOneWidget);
    expect(find.textContaining('高级'), findsNothing);
    expect(find.textContaining('标准'), findsNothing);
    expect(find.textContaining('即将'), findsNothing);
    expect(find.textContaining('删除'), findsNothing);
    expect(find.byType(FRadio), findsNothing);
    expect(
      find.byKey(const ValueKey('meeting-defaults-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('offline-resources-section')),
      findsOneWidget,
    );
    expect(find.textContaining('只影响后续新会议'), findsOneWidget);
    viewModel.dispose();
    await installations.dispose();
  });

  testWidgets('已安装模型将校验修复收进维护菜单', (tester) async {
    var repairCalls = 0;
    final installations = TestActiveInstallations();
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    installations.install(installations.installed(descriptor), active: true);
    final viewModel = ModelSettingsViewModel(
      preferences: TestModelPreferences(senseVoiceDefaultModelId),
      installations: installations,
      actions: ModelMaintenanceActions(repair: () async => repairCalls++),
    );

    await tester.pumpWidget(
      Application(home: ModelSettingsView(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('model-maintenance-menu')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('verify-and-repair-model')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('verify-and-repair-model')));
    await tester.pumpAndSettle();

    expect(repairCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
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

  testWidgets('存储账本展示真实分类且诊断分享必须二次确认', (tester) async {
    final fixture = await _Fixture.create();

    await tester.pumpWidget(
      Application(
        home: ModelSettingsView(
          viewModel: fixture.modelViewModel,
          dataControls: fixture.dataViewModel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('storage-privacy-section')),
      findsOneWidget,
    );
    expect(find.text('300.0 MiB'), findsOneWidget);
    expect(find.text('20.00 GiB'), findsOneWidget);
    expect(fixture.sharing.documents, isEmpty);

    final export = find.byKey(const ValueKey('export-diagnostics'));
    await tester.ensureVisible(export);
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(find.text('分享诊断信息？'), findsOneWidget);
    expect(fixture.sharing.documents, isEmpty);

    await tester.tap(find.byKey(const ValueKey('confirm-export-diagnostics')));
    await tester.pumpAndSettle();
    expect(fixture.sharing.documents, hasLength(1));
    expect(fixture.sharing.documents.single.text, contains('model_version'));
    expect(fixture.sharing.documents.single.text, isNot(contains('会议标题')));

    await fixture.dispose();
  });

  for (final dimensions in <(Size, Key)>[
    (const Size(320, 760), const ValueKey('settings-single-column')),
    (const Size(1024, 760), const ValueKey('settings-two-column')),
  ]) {
    testWidgets('${dimensions.$1.width.toInt()} 宽度使用对应设置布局且不溢出', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(dimensions.$1);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await _Fixture.create();

      await tester.pumpWidget(
        Application(
          home: ModelSettingsView(
            viewModel: fixture.modelViewModel,
            dataControls: fixture.dataViewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(dimensions.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
      await fixture.dispose();
    });
  }
}

final class _Fixture {
  _Fixture({
    required this.installations,
    required this.modelViewModel,
    required this.dataViewModel,
    required this.sharing,
  });

  final TestActiveInstallations installations;
  final ModelSettingsViewModel modelViewModel;
  final DataControlsViewModel dataViewModel;
  final _FakeTextShare sharing;

  static Future<_Fixture> create() async {
    final installations = TestActiveInstallations();
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    installations.install(installations.installed(descriptor), active: true);
    final modelViewModel = ModelSettingsViewModel(
      preferences: TestModelPreferences(senseVoiceDefaultModelId),
      installations: installations,
      actions: const ModelMaintenanceActions(),
    );
    final sharing = _FakeTextShare();
    return _Fixture(
      installations: installations,
      modelViewModel: modelViewModel,
      dataViewModel: DataControlsViewModel(
        dataControl: _FakeDataControl(),
        sharing: sharing,
      ),
      sharing: sharing,
    );
  }

  Future<void> dispose() async {
    modelViewModel.dispose();
    dataViewModel.dispose();
    await installations.dispose();
  }
}

final class _FakeDataControl implements LocalDataControlPort {
  @override
  Future<LocalStorageUsage> measure() async => const LocalStorageUsage(
    totalBytes: 300 * 1024 * 1024,
    meetingBytes: 12 * 1024 * 1024,
    modelBytes: 287 * 1024 * 1024,
    databaseBytes: 1 * 1024 * 1024,
    freeBytes: 20 * 1024 * 1024 * 1024,
  );

  @override
  Future<DiagnosticReport> buildDiagnostics() async =>
      DiagnosticReport({'model_version': '2024-07-17', 'error_code': null});
}

final class _FakeTextShare implements TextShareService {
  final List<MeetingShareDocument> documents = [];

  @override
  Future<void> share(MeetingShareDocument document) async {
    documents.add(document);
  }
}
