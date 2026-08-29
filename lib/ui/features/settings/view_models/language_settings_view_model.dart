import 'package:flutter/foundation.dart';

import '../../../../domain/models/app_language.dart';
import '../../../../domain/ports/repositories.dart';

final class LanguageSettingsViewModel extends ChangeNotifier {
  LanguageSettingsViewModel({
    required this.preferences,
    required this.languageMode,
  });

  final LanguagePreferenceRepository preferences;
  final ValueNotifier<AppLanguageMode> languageMode;

  bool _isBusy = false;
  bool _saveFailed = false;
  bool _disposed = false;

  AppLanguageMode get selectedMode => languageMode.value;
  bool get isBusy => _isBusy;
  bool get saveFailed => _saveFailed;

  Future<void> select(AppLanguageMode mode) async {
    if (_disposed || _isBusy || mode == selectedMode) {
      return;
    }
    final previous = selectedMode;
    _isBusy = true;
    _saveFailed = false;
    languageMode.value = mode;
    _notify();
    try {
      await preferences.setLanguageMode(mode);
    } on Object {
      languageMode.value = previous;
      _saveFailed = true;
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
