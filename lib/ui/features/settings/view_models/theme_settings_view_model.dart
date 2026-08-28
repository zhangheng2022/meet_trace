import 'package:flutter/foundation.dart';

import '../../../../domain/models/app_theme.dart';
import '../../../../domain/ports/repositories.dart';

final class ThemeSettingsViewModel extends ChangeNotifier {
  ThemeSettingsViewModel({required this.preferences, required this.themeMode});

  final ThemePreferenceRepository preferences;
  final ValueNotifier<AppThemeMode> themeMode;

  bool _isBusy = false;
  bool _disposed = false;
  String? _errorMessage;

  AppThemeMode get selectedMode => themeMode.value;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  Future<void> select(AppThemeMode mode) async {
    if (_disposed || _isBusy || mode == selectedMode) {
      return;
    }
    final previous = selectedMode;
    _isBusy = true;
    _errorMessage = null;
    themeMode.value = mode;
    _notify();
    try {
      await preferences.setThemeMode(mode);
    } on Object {
      themeMode.value = previous;
      _errorMessage = '主题设置保存失败，已恢复原选择';
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
