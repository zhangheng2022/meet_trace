import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ports/repositories.dart';

final class SharedPreferencesRemoteDiagnosticsRepository
    implements RemoteDiagnosticsPreferenceRepository {
  static const _enabledKey = 'remote_diagnostics_enabled';
  static const _noticeDismissedKey = 'remote_diagnostics_notice_dismissed';

  @override
  Future<bool> getEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    if (!preferences.containsKey(_enabledKey)) {
      return true;
    }
    try {
      return preferences.getBool(_enabledKey) ?? false;
    } on TypeError {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(_enabledKey, enabled)) {
      throw StateError('远程诊断偏好保存失败');
    }
  }

  @override
  Future<bool> getNoticeDismissed() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      return preferences.getBool(_noticeDismissedKey) ?? false;
    } on TypeError {
      return false;
    }
  }

  @override
  Future<void> setNoticeDismissed() async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(_noticeDismissedKey, true)) {
      throw StateError('远程诊断告知状态保存失败');
    }
  }
}
