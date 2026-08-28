import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/app_theme.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/ui/features/settings/view_models/theme_settings_view_model.dart';

void main() {
  test('选择主题立即生效并持久化', () async {
    final preferences = _ThemePreferences();
    final themeMode = ValueNotifier(AppThemeMode.system);
    final viewModel = ThemeSettingsViewModel(
      preferences: preferences,
      themeMode: themeMode,
    );

    final saving = viewModel.select(AppThemeMode.dark);

    expect(themeMode.value, AppThemeMode.dark);
    expect(viewModel.isBusy, isTrue);
    preferences.complete();
    await saving;
    expect(preferences.savedMode, AppThemeMode.dark);
    expect(viewModel.isBusy, isFalse);
    viewModel.dispose();
    themeMode.dispose();
  });

  test('保存失败时恢复原主题并显示错误', () async {
    final themeMode = ValueNotifier(AppThemeMode.light);
    final viewModel = ThemeSettingsViewModel(
      preferences: _FailingThemePreferences(),
      themeMode: themeMode,
    );

    await viewModel.select(AppThemeMode.dark);

    expect(themeMode.value, AppThemeMode.light);
    expect(viewModel.errorMessage, '主题设置保存失败，已恢复原选择');
    viewModel.dispose();
    themeMode.dispose();
  });
}

final class _ThemePreferences implements ThemePreferenceRepository {
  final Completer<void> _saving = Completer();
  AppThemeMode? savedMode;

  void complete() => _saving.complete();

  @override
  Future<AppThemeMode> getThemeMode() async => AppThemeMode.system;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    savedMode = mode;
    await _saving.future;
  }
}

final class _FailingThemePreferences implements ThemePreferenceRepository {
  @override
  Future<AppThemeMode> getThemeMode() async => AppThemeMode.system;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    throw StateError('database unavailable');
  }
}
