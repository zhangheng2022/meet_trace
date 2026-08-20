import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../domain/models/app_update.dart';
import '../../../domain/ports/app_update.dart';
import '../storage/local_data_generation_gate.dart';
import 'app_update_signing_identity.dart';
import 'signed_app_update_manifest_parser.dart';

const appUpdateManifestUrl =
    'https://raw.githubusercontent.com/zhangheng2022/meet_trace/'
    'updates/alpha/alpha.json';

final class AppUpdateRuntimeConfiguration {
  AppUpdateRuntimeConfiguration({
    required this.enabled,
    required this.platform,
    required this.installedVersion,
    Uri? manifestUri,
    this.signingKeyId = appUpdateSigningKeyId,
    String signingPublicKeyBase64 = appUpdateSigningPublicKeyBase64,
  }) : manifestUri = manifestUri ?? Uri.parse(appUpdateManifestUrl),
       signingPublicKey = _decodePublicKey(signingPublicKeyBase64) {
    if (enabled && platform == null) {
      throw ArgumentError('启用自动更新时必须使用受支持的平台');
    }
  }

  factory AppUpdateRuntimeConfiguration.fromEnvironment() {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => AppUpdatePlatform.android,
      TargetPlatform.iOS => AppUpdatePlatform.ios,
      TargetPlatform.windows => AppUpdatePlatform.windows,
      _ => null,
    };
    const enabledByBuild = bool.fromEnvironment(
      'MEETTRACE_APP_UPDATE_ENABLED',
      defaultValue: false,
    );
    const versionName = String.fromEnvironment(
      'MEETTRACE_VERSION_NAME',
      defaultValue: '1.0.0',
    );
    const buildNumberText = String.fromEnvironment(
      'MEETTRACE_BUILD_NUMBER',
      defaultValue: '1',
    );
    final buildNumber = int.tryParse(buildNumberText);
    if (buildNumber == null || buildNumber <= 0) {
      throw const FormatException('MEETTRACE_BUILD_NUMBER 必须是正整数');
    }
    return AppUpdateRuntimeConfiguration(
      enabled: enabledByBuild && platform != null,
      platform: platform,
      installedVersion: InstalledAppVersion(
        versionName: versionName,
        buildNumber: buildNumber,
        dataGeneration: LocalDataGenerationGate.currentGeneration,
      ),
    );
  }

  final bool enabled;
  final AppUpdatePlatform? platform;
  final InstalledAppVersion installedVersion;
  final Uri manifestUri;
  final String signingKeyId;
  final List<int> signingPublicKey;
}

final class ConfiguredInstalledAppVersionPort
    implements InstalledAppVersionPort {
  const ConfiguredInstalledAppVersionPort(this.version);

  final InstalledAppVersion version;

  @override
  Future<InstalledAppVersion> read() async => version;
}

List<int> _decodePublicKey(String value) {
  try {
    final bytes = base64Decode(value);
    if (bytes.length != 32) {
      throw const FormatException('Ed25519 公钥必须是 32 字节');
    }
    return List<int>.unmodifiable(bytes);
  } on FormatException {
    throw const FormatException('更新签名公钥必须是有效的 32 字节 Base64');
  }
}
