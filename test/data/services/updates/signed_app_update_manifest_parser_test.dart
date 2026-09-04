import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/updates/signed_app_update_manifest_parser.dart';
import 'package:meettrace/domain/models/app_update.dart';

void main() {
  test('验签成功后只解析目标平台的公开 Alpha 候选', () async {
    final verifier = _SignatureVerifier();
    final parser = SignedAppUpdateManifestParser(
      signatureVerifier: verifier,
      androidAbi: Abi.androidArm64,
    );

    final update = await parser.parse(
      _envelopeBytes(),
      platform: AppUpdatePlatform.android,
    );

    expect(update.candidate.status, AppUpdateCandidateStatus.publicApproved);
    expect(update.candidate.buildNumber, 2001);
    expect(update.candidate.artifactId, 'android-arm64-2001');
    expect(update.artifact.platform, AppUpdatePlatform.android);
    expect(update.artifact.packageIdentity, 'com.meettrace.app');
    expect(update.artifact.versionCode, 2001);
    expect(update.artifact.bytes, 1024);
    expect(verifier.payload, isNotEmpty);
    expect(verifier.algorithm, 'Ed25519');
    expect(verifier.keyId, 'alpha-2026');
  });

  test('验签失败时不解析候选或暴露安装入口', () async {
    final parser = SignedAppUpdateManifestParser(
      signatureVerifier: _SignatureVerifier()..valid = false,
    );

    await expectLater(
      parser.parse(_envelopeBytes(), platform: AppUpdatePlatform.windows),
      throwsA(isA<FormatException>()),
    );
  });

  test('拒绝 Draft 状态、非 Alpha 频道和 Android 包身份变化', () async {
    for (final mutation in <void Function(Map<String, Object?>)>[
      (payload) => payload['status'] = 'draft',
      (payload) => payload['channel'] = 'nightly',
      (payload) => payload['schemaVersion'] = 1,
      (payload) {
        final artifacts = payload['artifacts']! as Map<String, Object?>;
        final android = artifacts['android']! as Map<String, Object?>;
        android['packageIdentity'] = 'example.attacker';
      },
      (payload) {
        _arm64Artifact(payload)['bytes'] = 512 * 1024 * 1024 + 1;
      },
      (payload) => _arm64Artifact(payload)['versionCode'] = 0,
      (payload) => _arm64Artifact(payload)['versionCode'] = 2002,
      (payload) => _arm64Artifact(payload).remove('versionCode'),
    ]) {
      final parser = SignedAppUpdateManifestParser(
        signatureVerifier: _SignatureVerifier(),
        androidAbi: Abi.androidArm64,
      );
      await expectLater(
        parser.parse(
          _envelopeBytes(mutate: mutation),
          platform: AppUpdatePlatform.android,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('Android 按当前 ABI 选择 split 且未知 ABI 失败关闭', () async {
    for (final (abi, artifactId) in <(Abi, String)>[
      (Abi.androidArm, 'android-arm-2001'),
      (Abi.androidArm64, 'android-arm64-2001'),
      (Abi.androidX64, 'android-x64-2001'),
    ]) {
      final update = await SignedAppUpdateManifestParser(
        signatureVerifier: _SignatureVerifier(),
        androidAbi: abi,
      ).parse(_envelopeBytes(), platform: AppUpdatePlatform.android);
      expect(update.candidate.artifactId, artifactId);
    }

    await expectLater(
      SignedAppUpdateManifestParser(
        signatureVerifier: _SignatureVerifier(),
        androidAbi: Abi.windowsX64,
      ).parse(_envelopeBytes(), platform: AppUpdatePlatform.android),
      throwsFormatException,
    );
  });

  test('Windows 只接受固定 Microsoft Store 产品和包身份', () async {
    final parser = SignedAppUpdateManifestParser(
      signatureVerifier: _SignatureVerifier(),
    );
    final ios = await parser.parse(
      _envelopeBytes(),
      platform: AppUpdatePlatform.ios,
    );
    final windows = await parser.parse(
      _envelopeBytes(),
      platform: AppUpdatePlatform.windows,
    );

    expect(ios.artifact.installUri.host, 'testflight.apple.com');
    expect(windows.artifact.installUri.scheme, 'ms-windows-store');
    expect(windows.artifact.packageIdentity, 'zhangheng2026.MeetTrace');
    expect(windows.artifact.signingIdentitySha256, isNull);
  });

  test('拒绝 App Installer、错误 Store ID 和错误 Windows 包身份', () async {
    for (final mutation in <void Function(Map<String, Object?>)>[
      (payload) {
        final windows = _windowsArtifact(payload);
        windows['distribution'] = 'appInstaller';
        windows['installUri'] =
            'https://updates.example.test/meettrace.appinstaller';
      },
      (payload) => _windowsArtifact(payload)['installUri'] =
          'ms-windows-store://pdp/?productid=EXAMPLE',
      (payload) => _windowsArtifact(payload)['installUri'] =
          'ms-windows-store://attacker@pdp/?productid=9PHHSJMWK06G',
      (payload) => _windowsArtifact(payload)['installUri'] =
          'ms-windows-store://pdp/?productid=9PHHSJMWK06G&mode=extra',
      (payload) =>
          _windowsArtifact(payload)['packageIdentity'] = 'MeetTrace.Alpha',
    ]) {
      final parser = SignedAppUpdateManifestParser(
        signatureVerifier: _SignatureVerifier(),
      );
      await expectLater(
        parser.parse(
          _envelopeBytes(mutate: mutation),
          platform: AppUpdatePlatform.windows,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });
}

Map<String, Object?> _windowsArtifact(Map<String, Object?> payload) {
  final artifacts = payload['artifacts']! as Map<String, Object?>;
  return artifacts['windows']! as Map<String, Object?>;
}

Map<String, Object?> _arm64Artifact(Map<String, Object?> payload) {
  final artifacts = payload['artifacts']! as Map<String, Object?>;
  final android = artifacts['android']! as Map<String, Object?>;
  final variants = android['variants']! as Map<String, Object?>;
  return variants['arm64-v8a']! as Map<String, Object?>;
}

List<int> _envelopeBytes({void Function(Map<String, Object?>)? mutate}) {
  final hash = 'a' * 64;
  final payload = <String, Object?>{
    'schemaVersion': 2,
    'channel': 'alpha',
    'status': 'publicApproved',
    'releaseId': 'v1.1.0-alpha.1',
    'versionName': '1.1.0',
    'buildNumber': 2001,
    'dataGeneration': 3,
    'sourceCommitSha': '0123456789abcdef0123456789abcdef01234567',
    'approvedAt': '2026-08-15T10:00:00Z',
    'artifacts': <String, Object?>{
      'android': <String, Object?>{
        'packageIdentity': 'com.meettrace.app',
        'signingIdentitySha256': hash,
        'variants': <String, Object?>{
          'armeabi-v7a': _androidVariant('android-arm-2001', hash),
          'arm64-v8a': _androidVariant('android-arm64-2001', hash),
          'x86_64': _androidVariant('android-x64-2001', hash),
        },
      },
      'ios': <String, Object?>{
        'artifactId': 'ios-11',
        'installUri': 'https://testflight.apple.com/join/example',
        'distribution': 'testflight',
      },
      'windows': <String, Object?>{
        'artifactId': 'windows-11',
        'installUri': 'ms-windows-store://pdp/?productid=9PHHSJMWK06G',
        'distribution': 'store',
        'packageIdentity': 'zhangheng2026.MeetTrace',
      },
    },
  };
  mutate?.call(payload);
  final payloadBytes = utf8.encode(jsonEncode(payload));
  return utf8.encode(
    jsonEncode({
      'schemaVersion': 1,
      'signedPayload': base64Encode(payloadBytes),
      'signature': {
        'algorithm': 'Ed25519',
        'keyId': 'alpha-2026',
        'value': base64Encode([1, 2, 3]),
      },
    }),
  );
}

Map<String, Object?> _androidVariant(String artifactId, String hash) =>
    <String, Object?>{
      'artifactId': artifactId,
      'installUri': 'https://updates.example.test/$artifactId.apk',
      'bytes': 1024,
      'sha256': hash,
      'versionCode': 2001,
    };

final class _SignatureVerifier implements AppUpdateManifestSignatureVerifier {
  bool valid = true;
  Uint8List payload = Uint8List(0);
  String? algorithm;
  String? keyId;

  @override
  Future<bool> verify({
    required Uint8List signedPayload,
    required String algorithm,
    required String keyId,
    required Uint8List signature,
  }) async {
    payload = signedPayload;
    this.algorithm = algorithm;
    this.keyId = keyId;
    return valid;
  }
}
