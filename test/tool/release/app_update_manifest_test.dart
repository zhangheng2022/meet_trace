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
    expect(android.candidate.buildNumber, 11);
    expect(android.artifact.bytes, 1024);
    expect(
      android.artifact.installUri.toString(),
      'https://github.com/example/meettrace/releases/download/'
      'v1.1.0-alpha.1/meettrace.apk',
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
      _request(seed: seed, publicKey: publicKey),
    );

    final repaired = await createSignedAppUpdateManifest(
      _request(seed: seed, publicKey: publicKey, previous: previous),
    );
    expect(repaired, isNotEmpty);
    final withdrawn = await createSignedAppUpdateManifest(
      _request(
        seed: seed,
        publicKey: publicKey,
        previous: previous,
        status: 'withdrawn',
      ),
    );
    final parsedWithdrawal = await SignedAppUpdateManifestParser(
      signatureVerifier: Ed25519AppUpdateSignatureVerifier(
        expectedKeyId: 'alpha-0123456789abcdef',
        publicKeyBytes: publicKey,
      ),
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
          releaseId: 'v1.0.0-alpha.9',
          versionName: '1.0.0',
          buildNumber: 10,
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
}

AppUpdateManifestSigningRequest _request({
  required List<int> seed,
  required List<int> publicKey,
  List<int>? previous,
  String status = 'publicApproved',
  String releaseId = 'v1.1.0-alpha.1',
  String versionName = '1.1.0',
  int buildNumber = 11,
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
    'releaseId': releaseId,
    'marketingVersion': versionName,
    'buildNumber': buildNumber,
    'commitSha': '0123456789abcdef0123456789abcdef01234567',
    'packageIdentity': 'com.meettrace.app',
    'signingIdentitySha256': 'a' * 64,
    'artifact': <String, Object?>{
      'name': 'meettrace.apk',
      'bytes': 1024,
      'sha256': 'b' * 64,
    },
  },
  testFlightUri:
      testFlightUri ?? Uri.parse('https://testflight.apple.com/join/example'),
  previousEnvelope: previous,
);
