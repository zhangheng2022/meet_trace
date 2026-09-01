import 'package:flutter/foundation.dart';

import '../../../../domain/ports/repositories.dart';

final class RemoteDiagnosticsSettingsViewModel extends ChangeNotifier {
  RemoteDiagnosticsSettingsViewModel({
    required this.preferences,
    required this.controller,
  });

  final RemoteDiagnosticsPreferenceRepository preferences;
  final RemoteDiagnosticsController controller;

  static const _preferenceTimeout = Duration(seconds: 10);

  bool _enabled = false;
  bool _isLoading = true;
  bool _isBusy = false;
  bool _saveFailed = false;
  bool _disposed = false;
  Future<void>? _loadingOperation;

  bool get enabled => _enabled;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  bool get saveFailed => _saveFailed;

  Future<void> load() => _loadingOperation ??= _load();

  Future<void> _load() async {
    if (_disposed) {
      return;
    }
    try {
      _enabled = await preferences.getEnabled().timeout(_preferenceTimeout);
    } on Object {
      debugPrint('远程诊断偏好读取失败，本次按关闭状态展示。');
      _enabled = false;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _isBusy || _isLoading || enabled == _enabled) {
      return;
    }
    final previous = _enabled;
    _enabled = enabled;
    _isBusy = true;
    _saveFailed = false;
    _notify();
    var applied = false;
    var preferenceSaved = false;
    try {
      await preferences.setEnabled(enabled).timeout(_preferenceTimeout);
      preferenceSaved = true;
      applied = await controller.setEnabled(enabled);
    } on Object {
      applied = false;
    }
    if (!applied) {
      if (preferenceSaved && !_disposed) {
        try {
          await preferences.setEnabled(previous).timeout(_preferenceTimeout);
        } on Object {
          // 保留错误状态；下次启动仍以实际持久化结果为准。
          debugPrint('远程诊断偏好补偿写入失败，本机状态可能与持久化结果不一致。');
        }
      }
      _enabled = previous;
      _saveFailed = true;
    }
    _isBusy = false;
    _notify();
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
