import 'package:patrol/patrol.dart';

final class System {
  const System(this._platform);

  final PlatformAutomator _platform;

  Future<void> denyPermission() {
    return _platform.mobile.denyPermission();
  }

  Future<void> grantPermissionWhenInUse() {
    return _platform.mobile.grantPermissionWhenInUse();
  }

  Future<void> grantPermissionWhenInUseIfRequested({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final dialogVisible = await _platform.mobile.isPermissionDialogVisible(
      timeout: timeout,
    );
    if (dialogVisible) {
      await grantPermissionWhenInUse();
    }
  }

  Future<void> leaveAndReturnToApp({
    Duration backgroundDuration = Duration.zero,
  }) async {
    await _platform.mobile.pressHome();
    if (backgroundDuration > Duration.zero) {
      await Future<void>.delayed(backgroundDuration);
    }
    await _platform.mobile.openApp();
  }
}
