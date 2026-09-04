import 'dart:convert';
import 'dart:ffi';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/updates/ed25519_app_update_signature_verifier.dart';
import 'package:meettrace/data/services/updates/signed_app_update_manifest_parser.dart';
import 'package:meettrace/domain/models/app_update.dart';

import '../../../tool/release/app_update_manifest.dart';

void main() {
  late List<int> seed;
  late List<int> publicKey;

  setUp(() async {
    seed = List<int>.generate(32, (index) => index);
    final keyPair = await Ed25519().newKeyPairFromSeed(seed);
    publicKey = (await keyPair.extractPublicKey()).bytes;
  });

  test('生成的 envelope 可由客户端公钥验签并解析三平台资产', () async {
    final envelope = await createSignedAppUpdateManifest(
      _request(seed: seed, publicKey: publicKey),
    );
    final parser = SignedAppUpdateManifestParser(
      signatureVerifier: Ed25519AppUpdateSignatureVerifier(
        expectedKeyId: 'alpha-0123456789abcdef',
        publicKeyBytes: publicKey,
      ),
      androidAbi: Abi.androidArm64,
    );

    final android = await parser.parse(
      envelope,
      platform: AppUpdatePlatform.android,
    );
    final ios = await parser.parse(envelope, platform: AppUpdatePlatform.ios);
    final windows = await parser.parse(
      envelope,
      platform: AppUpdatePlatform.windows,
    );

    expect(android.candidate.releaseId, 'v1.1.0-alpha.1');
    expect(android.candidate.buildNumber, 2001);
    expect(android.artifact.versionCode, 2001);
    expect(android.artifact.bytes, 1024);
    expect(
      android.artifact.installUri.toString(),
      'https://github.com/example/meettrace/releases/download/'
      'v1.1.0-alpha.1/meettrace-v1.1.0-alpha.1-android-arm64.apk',
    );
    expect(ios.artifact.installUri.host, 'testflight.apple.com');
    expect(windows.artifact.installUri.scheme, 'ms-windows-store');
  });

  test('拒绝与客户端公钥不匹配的私钥', () async {
    await expectLater(
      createSignedAppUpdateManifest(
        _request(seed: List<int>.filled(32, 9), publicKey: publicKey),
      ),
      throwsStateError,
    );
  });

  test('仅允许构建号递增、当前版本修复或撤回当前公开版本', () async {
    final previous = await createSignedAppUpdateManifest(
      _request(
        seed: seed,
        publicKey: publicKey,
        releaseId: 'v1.1.0-alpha.2',
        buildNumber: 2002,
      ),
    );

    final repaired = await createSignedAppUpdateManifest(
      _request(
        seed: seed,
        publicKey: publicKey,
        previous: previous,
        releaseId: 'v1.1.0-alpha.2',
        buildNumber: 2002,
      ),
    );
    expect(repaired, isNotEmpty);
    final withdrawn = await createSignedAppUpdateManifest(
      _request(
        seed: seed,
        publicKey: publicKey,
        previous: previous,
        releaseId: 'v1.1.0-alpha.2',
        buildNumber: 2002,
        status: 'withdrawn',
      ),
    );
    final parsedWithdrawal = await SignedAppUpdateManifestParser(
      signatureVerifier: Ed25519AppUpdateSignatureVerifier(
        expectedKeyId: 'alpha-0123456789abcdef',
        publicKeyBytes: publicKey,
      ),
      androidAbi: Abi.androidArm64,
    ).parse(withdrawn, platform: AppUpdatePlatform.android);
    expect(
      parsedWithdrawal.candidate.status,
      AppUpdateCandidateStatus.withdrawn,
    );

    await expectLater(
      createSignedAppUpdateManifest(
        _request(
          seed: seed,
          publicKey: publicKey,
          previous: previous,
          buildNumber: 2001,
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      createSignedAppUpdateManifest(
        _request(seed: seed, publicKey: publicKey, previous: withdrawn),
      ),
      throwsStateError,
    );
  });

  test('拒绝篡改的上一指针和非 TestFlight iOS 入口', () async {
    final previous = await createSignedAppUpdateManifest(
      _request(seed: seed, publicKey: publicKey),
    );
    previous[previous.length ~/ 2] ^= 1;

    await expectLater(
      createSignedAppUpdateManifest(
        _request(seed: seed, publicKey: publicKey, previous: previous),
      ),
      throwsA(anything),
    );
    await expectLater(
      createSignedAppUpdateManifest(
        _request(
          seed: seed,
          publicKey: publicKey,
          testFlightUri: Uri.parse('https://example.test/app'),
        ),
      ),
      throwsFormatException,
    );
  });

  test('拒绝 Android split versionCode 与共享构建号不匹配', () async {
    final request = _request(seed: seed, publicKey: publicKey);
    final artifacts = request.androidCandidate['artifacts']! as Map;
    (artifacts['arm64-v8a']! as Map)['versionCode'] = 2002;

    await expectLater(
      createSignedAppUpdateManifest(request),
      throwsFormatException,
    );
  });

  test('拒绝旧 Android 候选 schema', () async {
    final request = _request(seed: seed, publicKey: publicKey);
    request.androidCandidate['schemaVersion'] = 2;
    await expectLater(
      createSignedAppUpdateManifest(request),
      throwsFormatException,
    );
  });

  test('签名器可从已验签 schema 1 指针单向迁移到 schema 2', () async {
    final current = await createSignedAppUpdateManifest(
      _request(seed: seed, publicKey: publicKey),
    );
    final envelope = jsonDecode(utf8.decode(current)) as Map<String, Object?>;
    final payload = jsonDecode(
      utf8.decode(base64Decode(envelope['signedPayload']! as String)),
    ) as Map<String, Object?>;
    payload['schemaVersion'] = 1;
    final payloadBytes = utf8.encode(jsonEncode(payload));
    final signature = await Ed25519().sign(
      payloadBytes,
      keyPair: await Ed25519().newKeyPairFromSeed(seed),
    );
    envelope['signedPayload'] = base64Encode(payloadBytes);
    (envelope['signature']! as Map<String, Object?>)['value'] = base64Encode(
      signature.bytes,
    );

    final migrated = await createSignedAppUpdateManifest(
      _request(
        seed: seed,
        publicKey: publicKey,
        previous: utf8.encode(jsonEncode(envelope)),
        releaseId: 'v1.1.0-alpha.2',
        buildNumber: 2002,
      ),
    );
    final migratedEnvelope = jsonDecode(utf8.decode(migrated)) as Map;
    final migratedPayload = jsonDecode(
      utf8.decode(base64Decode(migratedEnvelope['signedPayload'] as String)),
    ) as Map;
    expect(migratedPayload['schemaVersion'], 2);
  });
}

AppUpdateManifestSigningRequest _request({
  required List<int> seed,
  required List<int> publicKey,
  List<int>? previous,
  String status = 'publicApproved',
  String releaseId = 'v1.1.0-alpha.1',
  String versionName = '1.1.0',
  int buildNumber = 2001,
  Uri? testFlightUri,
}) => AppUpdateManifestSigningRequest(
  privateSeed: seed,
  expectedPublicKey: publicKey,
  keyId: 'alpha-0123456789abcdef',
  status: status,
  releaseId: releaseId,
  versionName: versionName,
  buildNumber: buildNumber,
  dataGeneration: 3,
  sourceCommitSha: '0123456789abcdef0123456789abcdef01234567',
  approvedAt: DateTime.utc(2026, 8, 20),
  repository: 'example/meettrace',
  androidCandidate: <String, Object?>{
    'schemaVersion': 3,
    'releaseId': releaseId,
    'marketingVersion': versionName,
    'buildNumber': buildNumber,
    'commitSha': '0123456789abcdef0123456789abcdef01234567',
    'packageIdentity': 'com.meettrace.app',
    'signingIdentitySha256': 'a' * 64,
    'artifacts': <String, Object?>{
      for (final entry in const <String, String>{
        'armeabi-v7a': 'armeabi-v7a',
        'arm64-v8a': 'arm64',
        'x86_64': 'x86_64',
        'universal': 'universal',
      }.entries)
        entry.key: <String, Object?>{
          'name': 'meettrace-$releaseId-android-${entry.value}.apk',
          'bytes': 1024,
          'sha256': 'b' * 64,
          'versionCode': buildNumber,
        },
    },
  },
  testFlightUri:
      testFlightUri ?? Uri.parse('https://testflight.apple.com/join/example'),
  previousEnvelope: previous,
);
