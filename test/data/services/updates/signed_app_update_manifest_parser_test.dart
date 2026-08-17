import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/updates/signed_app_update_manifest_parser.dart';
import 'package:meettrace/domain/models/app_update.dart';

void main() {
  test('验签成功后只解析目标平台的公开 Alpha 候选', () async {
    final verifier = _SignatureVerifier();
    final parser = SignedAppUpdateManifestParser(signatureVerifier: verifier);

    final update = await parser.parse(
      _envelopeBytes(),
      platform: AppUpdatePlatform.android,
    );

    expect(update.candidate.status, AppUpdateCandidateStatus.publicApproved);
    expect(update.candidate.buildNumber, 11);
    expect(update.candidate.artifactId, 'android-11');
    expect(update.artifact.platform, AppUpdatePlatform.android);
    expect(update.artifact.packageIdentity, 'com.meettrace.app');
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
      (payload) {
        final artifacts = payload['artifacts']! as Map<String, Object?>;
        final android = artifacts['android']! as Map<String, Object?>;
        android['packageIdentity'] = 'example.attacker';
      },
    ]) {
      final parser = SignedAppUpdateManifestParser(
        signatureVerifier: _SignatureVerifier(),
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

  test('各平台只接受 HTTPS TestFlight、App Installer 或 Store 固定路线', () async {
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
    expect(windows.artifact.installUri.scheme, 'https');
  });
}

List<int> _envelopeBytes({void Function(Map<String, Object?>)? mutate}) {
  final hash = 'a' * 64;
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'channel': 'alpha',
    'status': 'publicApproved',
    'releaseId': 'v1.1.0-alpha.1',
    'versionName': '1.1.0',
    'buildNumber': 11,
    'dataGeneration': 3,
    'sourceCommitSha': '0123456789abcdef0123456789abcdef01234567',
    'approvedAt': '2026-08-15T10:00:00Z',
    'artifacts': <String, Object?>{
      'android': <String, Object?>{
        'artifactId': 'android-11',
        'installUri': 'https://updates.example.test/meettrace.apk',
        'bytes': 1024,
        'sha256': hash,
        'packageIdentity': 'com.meettrace.app',
        'signingIdentitySha256': hash,
      },
      'ios': <String, Object?>{
        'artifactId': 'ios-11',
        'installUri': 'https://testflight.apple.com/join/example',
      },
      'windows': <String, Object?>{
        'artifactId': 'windows-11',
        'installUri': 'https://updates.example.test/meettrace.appinstaller',
        'distribution': 'appInstaller',
        'packageIdentity': 'MeetTrace.Alpha',
        'signingIdentitySha256': hash,
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
