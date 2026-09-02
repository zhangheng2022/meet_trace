import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/ui/features/settings/view_models/remote_diagnostics_settings_view_model.dart';

void main() {
  test('读取本机开关并在切换后持久化和应用运行状态', () async {
    final preferences = _RemoteDiagnosticsPreferences(enabled: false);
    final controller = _RemoteDiagnosticsController();
    final viewModel = RemoteDiagnosticsSettingsViewModel(
      preferences: preferences,
      controller: controller,
    );

    await viewModel.load();
    expect(viewModel.enabled, isFalse);

    await viewModel.setEnabled(true);
    expect(viewModel.enabled, isTrue);
    expect(preferences.savedEnabled, isTrue);
    expect(controller.appliedEnabled, isTrue);
  });

  test('读取失败时按关闭展示且结束加载', () async {
    final viewModel = RemoteDiagnosticsSettingsViewModel(
      preferences: _RemoteDiagnosticsPreferences(
        enabled: false,
        failLoading: true,
      ),
      controller: _RemoteDiagnosticsController(),
    );

    await viewModel.load();

    expect(viewModel.enabled, isFalse);
    expect(viewModel.isLoading, isFalse);
  });

  test('并发读取复用同一加载任务', () async {
    final loading = Completer<bool>();
    final preferences = _RemoteDiagnosticsPreferences(
      enabled: false,
      loading: loading,
    );
    final viewModel = RemoteDiagnosticsSettingsViewModel(
      preferences: preferences,
      controller: _RemoteDiagnosticsController(),
    );

    final first = viewModel.load();
    final second = viewModel.load();
    expect(second, same(first));
    expect(preferences.readCount, 1);

    loading.complete(true);
    await first;
    expect(viewModel.enabled, isTrue);
  });

  test('相同值不重复保存，切换进行中忽略并发请求且可安全释放', () async {
    final pending = Completer<void>();
    final preferences = _RemoteDiagnosticsPreferences(enabled: true);
    final controller = _RemoteDiagnosticsController(pending: pending);
    final viewModel = RemoteDiagnosticsSettingsViewModel(
      preferences: preferences,
      controller: controller,
    );
    await viewModel.load();

    await viewModel.setEnabled(true);
    expect(preferences.saveCount, 0);

    final switching = viewModel.setEnabled(false);
    await Future<void>.delayed(Duration.zero);
    await viewModel.setEnabled(true);
    expect(controller.callCount, 1);

    viewModel.dispose();
    pending.complete();
    await switching;
  });

  test('页面释放后失败的 SDK 切换不再回写旧偏好', () async {
    final pending = Completer<void>();
    final preferences = _RemoteDiagnosticsPreferences(enabled: true);
    final viewModel = RemoteDiagnosticsSettingsViewModel(
      preferences: preferences,
      controller: _RemoteDiagnosticsController(
        succeeds: false,
        pending: pending,
      ),
    );
    await viewModel.load();

    final switching = viewModel.setEnabled(false);
    await Future<void>.delayed(Duration.zero);
    viewModel.dispose();
    pending.complete();
    await switching;

    expect(preferences.enabled, isFalse);
    expect(preferences.saveAttempts, 1);
  });

  test('保存失败时恢复原选择且不改变 SDK', () async {
    final controller = _RemoteDiagnosticsController();
    final preferences = _RemoteDiagnosticsPreferences(
      enabled: true,
      failSaving: true,
    );
    final viewModel = RemoteDiagnosticsSettingsViewModel(
      preferences: preferences,
      controller: controller,
    );
    await viewModel.load();

    await viewModel.setEnabled(false);

    expect(viewModel.enabled, isTrue);
    expect(viewModel.saveFailed, isTrue);
    expect(controller.appliedEnabled, isNull);
    expect(preferences.saveAttempts, 1);
  });

  test('SDK 状态切换失败时补偿本机偏好并恢复原选择', () async {
    final preferences = _RemoteDiagnosticsPreferences(enabled: true);
    final viewModel = RemoteDiagnosticsSettingsViewModel(
      preferences: preferences,
      controller: _RemoteDiagnosticsController(succeeds: false),
    );
    await viewModel.load();

    await viewModel.setEnabled(false);

    expect(viewModel.enabled, isTrue);
    expect(viewModel.saveFailed, isTrue);
    expect(preferences.enabled, isTrue);
  });

  test('补偿写入失败时保留本机实际值并恢复本次显示', () async {
    final preferences = _RemoteDiagnosticsPreferences(
      enabled: true,
      failOnSaveAttempt: 2,
    );
    final viewModel = RemoteDiagnosticsSettingsViewModel(
      preferences: preferences,
      controller: _RemoteDiagnosticsController(succeeds: false),
    );
    await viewModel.load();

    await viewModel.setEnabled(false);

    expect(viewModel.enabled, isTrue);
    expect(viewModel.saveFailed, isTrue);
    expect(preferences.enabled, isFalse);
    expect(preferences.saveAttempts, 2);
  });
}

final class _RemoteDiagnosticsPreferences
    implements RemoteDiagnosticsPreferenceRepository {
  _RemoteDiagnosticsPreferences({
    required this.enabled,
    this.loading,
    this.failLoading = false,
    this.failSaving = false,
    this.failOnSaveAttempt,
  });

  bool enabled;
  final Completer<bool>? loading;
  final bool failLoading;
  final bool failSaving;
  final int? failOnSaveAttempt;
  bool? savedEnabled;
  int saveCount = 0;
  int saveAttempts = 0;
  int readCount = 0;

  @override
  Future<bool> getEnabled() async {
    readCount += 1;
    if (failLoading) {
      throw StateError('preferences unavailable');
    }
    final pending = loading;
    if (pending != null) {
      return pending.future;
    }
    return enabled;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    saveAttempts += 1;
    if (failSaving || saveAttempts == failOnSaveAttempt) {
      throw StateError('preferences unavailable');
    }
    saveCount += 1;
    savedEnabled = enabled;
    this.enabled = enabled;
  }
}

final class _RemoteDiagnosticsController
    implements RemoteDiagnosticsController {
  _RemoteDiagnosticsController({this.succeeds = true, this.pending});

  final bool succeeds;
  final Completer<void>? pending;
  bool? appliedEnabled;
  int callCount = 0;

  @override
  Future<bool> setEnabled(bool enabled) async {
    callCount += 1;
    appliedEnabled = enabled;
    await pending?.future;
    return succeeds;
  }
}
