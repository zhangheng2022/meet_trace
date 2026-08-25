import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/updates/ed25519_app_update_signature_verifier.dart';

import '../../../tool/release/app_update_manifest.dart';
import '../../../tool/release/public_update_validation.dart';

void main() {
  late List<int> seed;
  late List<int> publicKey;

  setUp(() async {
    seed = List<int>.generate(32, (index) => index);
    final keyPair = await Ed25519().newKeyPairFromSeed(seed);
    publicKey = (await keyPair.extractPublicKey()).bytes;
  });

  test('验签并交叉核对公开 Release 的三平台更新合同', () async {
    final envelope = await createSignedAppUpdateManifest(
      _request(seed: seed, publicKey: publicKey),
    );

    final receipt = await validatePublicUpdateContract(
      envelopeBytes: envelope,
      androidCandidate: _androidCandidate(),
      iosCandidate: _iosCandidate(),
      windowsCandidate: _windowsCandidate(),
      windowsProductionReceipt: _windowsProductionReceipt(),
      expectedReleaseId: 'v1.1.0-alpha.1',
      expectedRepository: 'example/meettrace',
      expectedSourceRunId: 123,
      expectedPublishRunId: 456,
      signatureVerifier: Ed25519AppUpdateSignatureVerifier(
        expectedKeyId: 'alpha-0123456789abcdef',
        publicKeyBytes: publicKey,
      ),
    );

    expect(receipt.releaseId, 'v1.1.0-alpha.1');
    expect(receipt.buildNumber, 11);
    expect(receipt.sourceCommitSha, '0123456789abcdef0123456789abcdef01234567');
    expect(
      receipt.androidArtifactName,
      'meettrace-v1.1.0-alpha.1-android-arm64.apk',
    );
    expect(receipt.androidSha256, 'b' * 64);
    expect(receipt.iosInstallUri.host, 'testflight.apple.com');
    expect(receipt.windowsStoreId, '9PHHSJMWK06G');
    expect(receipt.windowsPackageVersion, '1.0.11.0');
    expect(receipt.toJson()['sourceRunId'], 123);
    expect(receipt.toJson()['publishRunId'], 456);
  });

  test('拒绝公开 manifest 与签名指针的身份或摘要不一致', () async {
    final envelope = await createSignedAppUpdateManifest(
      _request(seed: seed, publicKey: publicKey),
    );
    final candidate = _androidCandidate();
    (candidate['artifact']! as Map<String, Object?>)['sha256'] = 'c' * 64;

    await expectLater(
      validatePublicUpdateContract(
        envelopeBytes: envelope,
        androidCandidate: candidate,
        iosCandidate: _iosCandidate(),
        windowsCandidate: _windowsCandidate(),
        windowsProductionReceipt: _windowsProductionReceipt(),
        expectedReleaseId: 'v1.1.0-alpha.1',
        expectedRepository: 'example/meettrace',
        expectedSourceRunId: 123,
        expectedPublishRunId: 456,
        signatureVerifier: Ed25519AppUpdateSignatureVerifier(
          expectedKeyId: 'alpha-0123456789abcdef',
          publicKeyBytes: publicKey,
        ),
      ),
      throwsFormatException,
    );
  });

  test('拒绝已撤回候选和错误的 Alpha Release 运行身份', () async {
    final publicEnvelope = await createSignedAppUpdateManifest(
      _request(seed: seed, publicKey: publicKey),
    );
    final withdrawn = await createSignedAppUpdateManifest(
      _request(
        seed: seed,
        publicKey: publicKey,
        status: 'withdrawn',
        previous: publicEnvelope,
      ),
    );
    final verifier = Ed25519AppUpdateSignatureVerifier(
      expectedKeyId: 'alpha-0123456789abcdef',
      publicKeyBytes: publicKey,
    );

    await expectLater(
      validatePublicUpdateContract(
        envelopeBytes: withdrawn,
        androidCandidate: _androidCandidate(),
        iosCandidate: _iosCandidate(),
        windowsCandidate: _windowsCandidate(),
        windowsProductionReceipt: _windowsProductionReceipt(),
        expectedReleaseId: 'v1.1.0-alpha.1',
        expectedRepository: 'example/meettrace',
        expectedSourceRunId: 123,
        expectedPublishRunId: 456,
        signatureVerifier: verifier,
      ),
      throwsStateError,
    );

    await expectLater(
      validatePublicUpdateContract(
        envelopeBytes: publicEnvelope,
        androidCandidate: _androidCandidate(),
        iosCandidate: _iosCandidate(),
        windowsCandidate: _windowsCandidate(),
        windowsProductionReceipt: _windowsProductionReceipt(),
        expectedReleaseId: 'v1.1.0-alpha.1',
        expectedRepository: 'example/meettrace',
        expectedSourceRunId: 999,
        expectedPublishRunId: 456,
        signatureVerifier: verifier,
      ),
      throwsFormatException,
    );
  });

  test('接受 Partner Center API 生产回执但仍绑定确切包身份', () async {
    final envelope = await createSignedAppUpdateManifest(
      _request(seed: seed, publicKey: publicKey),
    );
    final productionReceipt = _windowsProductionReceipt()
      ..['verificationMode'] = 'partnerCenterApi'
      ..remove('approval');
    (productionReceipt['package']! as Map<String, Object?>).remove(
      'candidateSha256',
    );

    final receipt = await validatePublicUpdateContract(
      envelopeBytes: envelope,
      androidCandidate: _androidCandidate(),
      iosCandidate: _iosCandidate(),
      windowsCandidate: _windowsCandidate(),
      windowsProductionReceipt: productionReceipt,
      expectedReleaseId: 'v1.1.0-alpha.1',
      expectedRepository: 'example/meettrace',
      expectedSourceRunId: 123,
      expectedPublishRunId: 456,
      signatureVerifier: Ed25519AppUpdateSignatureVerifier(
        expectedKeyId: 'alpha-0123456789abcdef',
        publicKeyBytes: publicKey,
      ),
    );

    expect(receipt.windowsVerificationMode, 'partnerCenterApi');
    expect(receipt.windowsArtifactSha256, 'd' * 64);
  });

  test('拒绝 Windows 人工 Environment 批准回执', () async {
    final envelope = await createSignedAppUpdateManifest(
      _request(seed: seed, publicKey: publicKey),
    );
    final productionReceipt = _windowsProductionReceipt();
    productionReceipt['verificationMode'] = 'manualEnvironmentApproval';

    await expectLater(
      validatePublicUpdateContract(
        envelopeBytes: envelope,
        androidCandidate: _androidCandidate(),
        iosCandidate: _iosCandidate(),
        windowsCandidate: _windowsCandidate(),
        windowsProductionReceipt: productionReceipt,
        expectedReleaseId: 'v1.1.0-alpha.1',
        expectedRepository: 'example/meettrace',
        expectedSourceRunId: 123,
        expectedPublishRunId: 456,
        signatureVerifier: Ed25519AppUpdateSignatureVerifier(
          expectedKeyId: 'alpha-0123456789abcdef',
          publicKeyBytes: publicKey,
        ),
      ),
      throwsFormatException,
    );
  });
}

AppUpdateManifestSigningRequest _request({
  required List<int> seed,
  required List<int> publicKey,
  String status = 'publicApproved',
  List<int>? previous,
}) => AppUpdateManifestSigningRequest(
  privateSeed: seed,
  expectedPublicKey: publicKey,
  keyId: 'alpha-0123456789abcdef',
  status: status,
  releaseId: 'v1.1.0-alpha.1',
  versionName: '1.1.0',
  buildNumber: 11,
  dataGeneration: 3,
  sourceCommitSha: '0123456789abcdef0123456789abcdef01234567',
  approvedAt: DateTime.utc(2026, 8, 21),
  repository: 'example/meettrace',
  androidCandidate: _androidCandidate(),
  testFlightUri: Uri.parse('https://testflight.apple.com/join/example'),
  previousEnvelope: previous,
);

Map<String, Object?> _androidCandidate() => <String, Object?>{
  'schemaVersion': 1,
  'platform': 'android',
  'releaseId': 'v1.1.0-alpha.1',
  'marketingVersion': '1.1.0',
  'buildNumber': '11',
  'commitSha': '0123456789abcdef0123456789abcdef01234567',
  'workflowFile': '.github/workflows/alpha-release.yml',
  'job': 'android',
  'runId': '123',
  'runAttempt': '1',
  'packageIdentity': 'com.meettrace.app',
  'signingIdentitySha256': 'a' * 64,
  'artifact': <String, Object?>{
    'name': 'meettrace-v1.1.0-alpha.1-android-arm64.apk',
    'bytes': 1024,
    'sha256': 'b' * 64,
  },
  'distribution': <String, Object?>{'repository': 'example/meettrace'},
};

Map<String, Object?> _iosCandidate() => <String, Object?>{
  'schemaVersion': 1,
  'platform': 'ios',
  'releaseId': 'v1.1.0-alpha.1',
  'marketingVersion': '1.1.0',
  'buildNumber': '11',
  'commitSha': '0123456789abcdef0123456789abcdef01234567',
  'workflowFile': '.github/workflows/alpha-release.yml',
  'job': 'ios',
  'runId': '123',
  'runAttempt': '1',
  'bundleId': 'com.meettrace.app',
  'repository': 'example/meettrace',
  'artifact': <String, Object?>{
    'name': 'meettrace-testflight-11.ipa',
    'bytes': 2048,
    'sha256': 'c' * 64,
    'distributionSigned': true,
    'testFlightUploadCandidate': true,
  },
};

Map<String, Object?> _windowsCandidate() => <String, Object?>{
  'schemaVersion': 1,
  'platform': 'windows',
  'distribution': 'microsoftStore',
  'releaseId': 'v1.1.0-alpha.1',
  'marketingVersion': '1.1.0',
  'buildNumber': '11',
  'packageVersion': '1.0.11.0',
  'commitSha': '0123456789abcdef0123456789abcdef01234567',
  'workflowFile': '.github/workflows/alpha-release.yml',
  'job': 'windows',
  'runId': '123',
  'runAttempt': '1',
  'packageIdentity': 'zhangheng2026.MeetTrace',
  'publisher': 'CN=E5BC0A60-65F7-46C4-9A30-653FFCF9619B',
  'publisherDisplayName': 'zhangheng2026',
  'packageFamilyName': 'zhangheng2026.MeetTrace_vaaj3dqegb9y0',
  'storeId': '9PHHSJMWK06G',
  'storeUri': 'ms-windows-store://pdp/?productid=9PHHSJMWK06G',
  'storeUrl': 'https://apps.microsoft.com/detail/9PHHSJMWK06G',
  'repository': 'example/meettrace',
  'artifact': <String, Object?>{
    'name': 'meettrace-v1.1.0-alpha.1-windows-store-x64.msix',
    'bytes': 4096,
    'sha256': 'd' * 64,
    'storeSubmissionCandidate': true,
  },
};

Map<String, Object?> _windowsProductionReceipt() {
  return <String, Object?>{
    'schemaVersion': 1,
    'distribution': 'microsoftStore',
    'verificationMode': 'partnerCenterApi',
    'productId': '9PHHSJMWK06G',
    'submissionId': 'submission-456',
    'status': 'Published',
    'visibility': 'Public',
    'releaseId': 'v1.1.0-alpha.1',
    'candidateCommitSha': '0123456789abcdef0123456789abcdef01234567',
    'sourceRunId': 123,
    'package': <String, Object?>{
      'fileName': 'meettrace-v1.1.0-alpha.1-windows-store-x64.msix',
      'version': '1.0.11.0',
      'architecture': 'x64',
      'fileStatus': 'Uploaded',
    },
  };
}
