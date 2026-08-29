import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/app_language.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/ui/features/settings/view_models/language_settings_view_model.dart';

void main() {
  test('选择语言立即生效并持久化', () async {
    final preferences = _LanguagePreferences();
    final languageMode = ValueNotifier(AppLanguageMode.system);
    final viewModel = LanguageSettingsViewModel(
      preferences: preferences,
      languageMode: languageMode,
    );

    final saving = viewModel.select(AppLanguageMode.english);

    expect(languageMode.value, AppLanguageMode.english);
    expect(viewModel.isBusy, isTrue);
    preferences.complete();
    await saving;
    expect(preferences.savedMode, AppLanguageMode.english);
    expect(viewModel.isBusy, isFalse);
    viewModel.dispose();
    languageMode.dispose();
  });

  test('保存失败时恢复原语言并显示错误状态', () async {
    final languageMode = ValueNotifier(AppLanguageMode.simplifiedChinese);
    final viewModel = LanguageSettingsViewModel(
      preferences: _FailingLanguagePreferences(),
      languageMode: languageMode,
    );

    await viewModel.select(AppLanguageMode.english);

    expect(languageMode.value, AppLanguageMode.simplifiedChinese);
    expect(viewModel.saveFailed, isTrue);
    viewModel.dispose();
    languageMode.dispose();
  });
}

final class _LanguagePreferences implements LanguagePreferenceRepository {
  final Completer<void> _saving = Completer();
  AppLanguageMode? savedMode;

  void complete() => _saving.complete();

  @override
  Future<AppLanguageMode> getLanguageMode() async => AppLanguageMode.system;

  @override
  Future<void> setLanguageMode(AppLanguageMode mode) async {
    savedMode = mode;
    await _saving.future;
  }
}

final class _FailingLanguagePreferences
    implements LanguagePreferenceRepository {
  @override
  Future<AppLanguageMode> getLanguageMode() async => AppLanguageMode.system;

  @override
  Future<void> setLanguageMode(AppLanguageMode mode) async {
    throw StateError('database unavailable');
  }
}
