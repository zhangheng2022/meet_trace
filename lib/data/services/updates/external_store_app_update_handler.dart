import 'package:url_launcher/url_launcher.dart';

import 'signed_app_update_manifest_parser.dart';
import 'signed_manifest_app_update_port.dart';

typedef ExternalUpdateUriLauncher = Future<bool> Function(Uri uri);

final class ExternalStoreAppUpdateHandler implements PlatformAppUpdateHandler {
  ExternalStoreAppUpdateHandler({ExternalUpdateUriLauncher? launch})
    : _launch = launch ?? _launchExternal;

  final ExternalUpdateUriLauncher _launch;

  @override
  Future<void> stage(VerifiedPlatformAppUpdate update) async {
    if (update.artifact.platform == AppUpdatePlatform.android) {
      throw StateError('Android APK 不能使用外部 Store handler');
    }
  }

  @override
  Future<void> requestInstall(VerifiedPlatformAppUpdate update) async {
    if (update.artifact.platform == AppUpdatePlatform.android ||
        !await _launch(update.artifact.installUri)) {
      throw StateError('平台更新入口不可用');
    }
  }
}

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
