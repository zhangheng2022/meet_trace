import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meettrace/data/services/updates/app_update_signing_identity.dart';
import 'package:meettrace/data/services/updates/ed25519_app_update_signature_verifier.dart';
import 'package:meettrace/data/services/updates/signed_app_update_manifest_parser.dart';
import 'package:meettrace/domain/models/app_update.dart';

const _androidPackageIdentity = 'com.meettrace.app';
const _alphaReleaseWorkflow = '.github/workflows/alpha-release.yml';
const _windowsPackageIdentity = 'zhangheng2026.MeetTrace';
const _windowsPackageFamilyName = 'zhangheng2026.MeetTrace_vaaj3dqegb9y0';
const _windowsPublisher = 'CN=E5BC0A60-65F7-46C4-9A30-653FFCF9619B';
const _windowsStoreId = '9PHHSJMWK06G';

final class PublicUpdateValidationReceipt {
  const PublicUpdateValidationReceipt({
    required this.releaseId,
    required this.versionName,
    required this.buildNumber,
    required this.dataGeneration,
    required this.sourceCommitSha,
    required this.sourceRunId,
    required this.approvedAt,
    required this.androidArtifactName,
    required this.androidBytes,
    required this.androidSha256,
    required this.androidSigningIdentitySha256,
    required this.androidInstallUri,
    required this.iosInstallUri,
    required this.windowsInstallUri,
    required this.iosArtifactName,
    required this.iosArtifactSha256,
    required this.windowsArtifactName,
    required this.windowsArtifactBytes,
    required this.windowsArtifactSha256,
    required this.windowsVerificationMode,
  });

  final String releaseId;
  final String versionName;
  final int buildNumber;
  final int dataGeneration;
  final String sourceCommitSha;
  final int sourceRunId;
  final DateTime approvedAt;
  final String androidArtifactName;
  final int androidBytes;
  final String androidSha256;
  final String androidSigningIdentitySha256;
  final Uri androidInstallUri;
  final Uri iosInstallUri;
  final Uri windowsInstallUri;
  final String iosArtifactName;
  final String iosArtifactSha256;
  final String windowsArtifactName;
  final int windowsArtifactBytes;
  final String windowsArtifactSha256;
  final String windowsVerificationMode;

  String get windowsStoreId => _windowsStoreId;
  String get windowsPackageIdentity => _windowsPackageIdentity;
  String get windowsPackageVersion => '1.0.$buildNumber.0';

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'releaseId': releaseId,
    'versionName': versionName,
    'buildNumber': buildNumber,
    'dataGeneration': dataGeneration,
    'sourceCommitSha': sourceCommitSha,
    'sourceRunId': sourceRunId,
    'approvedAt': approvedAt.toUtc().toIso8601String(),
    'android': <String, Object?>{
      'artifactName': androidArtifactName,
      'bytes': androidBytes,
      'sha256': androidSha256,
      'packageIdentity': _androidPackageIdentity,
      'signingIdentitySha256': androidSigningIdentitySha256,
      'installUri': androidInstallUri.toString(),
    },
    'ios': <String, Object?>{
      'distribution': 'testflight',
      'artifactName': iosArtifactName,
      'artifactSha256': iosArtifactSha256,
      'installUri': iosInstallUri.toString(),
    },
    'windows': <String, Object?>{
      'distribution': 'store',
      'storeId': windowsStoreId,
      'packageIdentity': windowsPackageIdentity,
      'packageVersion': windowsPackageVersion,
      'artifactName': windowsArtifactName,
      'artifactBytes': windowsArtifactBytes,
      'artifactSha256': windowsArtifactSha256,
      'verificationMode': windowsVerificationMode,
      'installUri': windowsInstallUri.toString(),
    },
  };
}

Future<PublicUpdateValidationReceipt> validatePublicUpdateContract({
  required List<int> envelopeBytes,
  required Map<String, Object?> androidCandidate,
  required Map<String, Object?> iosCandidate,
  required Map<String, Object?> windowsCandidate,
  required Map<String, Object?> windowsProductionReceipt,
  required String expectedReleaseId,
  required String expectedRepository,
  required int expectedSourceRunId,
  AppUpdateManifestSignatureVerifier? signatureVerifier,
}) async {
  if (!RegExp(r'^v[0-9]+\.[0-9]+\.[0-9]+-alpha\.[1-9][0-9]*$')
      .hasMatch(expectedReleaseId)) {
    throw const FormatException('待验证 releaseId 格式无效');
  }
  if (!RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')
      .hasMatch(expectedRepository)) {
    throw const FormatException('待验证 repository 格式无效');
  }
  if (expectedSourceRunId <= 0) {
    throw const FormatException('待验证 source run ID 必须为正整数');
  }

  final parser = SignedAppUpdateManifestParser(
    signatureVerifier:
        signatureVerifier ??
        Ed25519AppUpdateSignatureVerifier(
          expectedKeyId: appUpdateSigningKeyId,
          publicKeyBytes: base64Decode(appUpdateSigningPublicKeyBase64),
        ),
  );
  final updates = await Future.wait(<Future<VerifiedPlatformAppUpdate>>[
    parser.parse(envelopeBytes, platform: AppUpdatePlatform.android),
    parser.parse(envelopeBytes, platform: AppUpdatePlatform.ios),
    parser.parse(envelopeBytes, platform: AppUpdatePlatform.windows),
  ]);
  final android = updates[0];
  final ios = updates[1];
  final windows = updates[2];

  if (android.candidate.status != AppUpdateCandidateStatus.publicApproved) {
    throw StateError('更新指针不是公开批准状态');
  }
  for (final update in <VerifiedPlatformAppUpdate>[ios, windows]) {
    _requireSameCandidate(android.candidate, update.candidate);
  }
  final candidate = android.candidate;
  if (candidate.releaseId != expectedReleaseId) {
    throw const FormatException('更新指针 releaseId 与待验证版本不匹配');
  }

  _requireCandidateValue(androidCandidate, 'schemaVersion', 1);
  _requireCandidateValue(androidCandidate, 'platform', 'android');
  _requireCandidateValue(androidCandidate, 'releaseId', candidate.releaseId);
  _requireCandidateValue(
    androidCandidate,
    'marketingVersion',
    candidate.versionName,
  );
  _requireCandidateValue(
    androidCandidate,
    'workflowFile',
    _alphaReleaseWorkflow,
  );
  _requireCandidateValue(androidCandidate, 'job', 'android');
  _requireCandidateValue(
    androidCandidate,
    'packageIdentity',
    _androidPackageIdentity,
  );
  if (_positiveInt(androidCandidate, 'buildNumber') != candidate.buildNumber ||
      _positiveInt(androidCandidate, 'runId') != expectedSourceRunId ||
      _positiveInt(androidCandidate, 'runAttempt') <= 0 ||
      _sha(androidCandidate, 'commitSha', 40) != candidate.sourceCommitSha) {
    throw const FormatException('Android 候选构建或运行身份不匹配');
  }

  final artifact = _object(androidCandidate['artifact'], 'artifact');
  final artifactName = _text(artifact, 'name');
  if (artifactName != 'meettrace-${candidate.releaseId}-android-arm64.apk') {
    throw const FormatException('Android 候选文件名不匹配');
  }
  final artifactBytes = _positiveInt(artifact, 'bytes');
  final artifactSha256 = _sha(artifact, 'sha256', 64);
  final signingIdentity = _sha(androidCandidate, 'signingIdentitySha256', 64);
  final androidDistribution = _object(
    androidCandidate['distribution'],
    'Android distribution',
  );
  _requireCandidateValue(androidDistribution, 'repository', expectedRepository);
  final expectedAndroidUri = Uri.https(
    'github.com',
    '/$expectedRepository/releases/download/'
        '${Uri.encodeComponent(candidate.releaseId)}/'
        '${Uri.encodeComponent(artifactName)}',
  );
  if (android.artifact.installUri != expectedAndroidUri ||
      android.artifact.bytes != artifactBytes ||
      android.artifact.sha256 != artifactSha256 ||
      android.artifact.packageIdentity != _androidPackageIdentity ||
      android.artifact.signingIdentitySha256 != signingIdentity) {
    throw const FormatException('Android 公开资产与签名更新指针不匹配');
  }
  if (windows.artifact.packageIdentity != _windowsPackageIdentity ||
      windows.artifact.installUri.queryParameters['productid'] !=
          _windowsStoreId) {
    throw const FormatException('Windows Store 公开更新合同不匹配');
  }

  _requireCandidateValue(iosCandidate, 'schemaVersion', 1);
  _requireCandidateValue(iosCandidate, 'platform', 'ios');
  _requireCandidateValue(iosCandidate, 'releaseId', candidate.releaseId);
  _requireCandidateValue(
    iosCandidate,
    'marketingVersion',
    candidate.versionName,
  );
  _requireCandidateValue(iosCandidate, 'commitSha', candidate.sourceCommitSha);
  _requireCandidateValue(iosCandidate, 'workflowFile', _alphaReleaseWorkflow);
  _requireCandidateValue(iosCandidate, 'job', 'ios');
  _requireCandidateValue(iosCandidate, 'bundleId', _androidPackageIdentity);
  _requireCandidateValue(iosCandidate, 'repository', expectedRepository);
  if (_positiveInt(iosCandidate, 'buildNumber') != candidate.buildNumber ||
      _positiveInt(iosCandidate, 'runId') != expectedSourceRunId ||
      _positiveInt(iosCandidate, 'runAttempt') <= 0) {
    throw const FormatException('iOS 候选构建或运行身份不匹配');
  }
  final iosArtifact = _object(iosCandidate['artifact'], 'iOS artifact');
  final iosArtifactName = _text(iosArtifact, 'name');
  if (iosArtifactName != 'meettrace-testflight-${candidate.buildNumber}.ipa') {
    throw const FormatException('iOS 候选文件名不匹配');
  }
  final iosArtifactSha256 = _sha(iosArtifact, 'sha256', 64);
  if (iosArtifact['distributionSigned'] != true ||
      iosArtifact['testFlightUploadCandidate'] != true) {
    throw const FormatException('iOS 候选不是已签名的 TestFlight 上传候选');
  }

  _requireCandidateValue(windowsCandidate, 'schemaVersion', 1);
  _requireCandidateValue(windowsCandidate, 'platform', 'windows');
  _requireCandidateValue(windowsCandidate, 'distribution', 'microsoftStore');
  _requireCandidateValue(windowsCandidate, 'releaseId', candidate.releaseId);
  _requireCandidateValue(
    windowsCandidate,
    'marketingVersion',
    candidate.versionName,
  );
  _requireCandidateValue(
    windowsCandidate,
    'commitSha',
    candidate.sourceCommitSha,
  );
  _requireCandidateValue(
    windowsCandidate,
    'workflowFile',
    _alphaReleaseWorkflow,
  );
  _requireCandidateValue(windowsCandidate, 'job', 'windows');
  _requireCandidateValue(
    windowsCandidate,
    'packageIdentity',
    _windowsPackageIdentity,
  );
  _requireCandidateValue(windowsCandidate, 'publisher', _windowsPublisher);
  _requireCandidateValue(
    windowsCandidate,
    'publisherDisplayName',
    'zhangheng2026',
  );
  _requireCandidateValue(
    windowsCandidate,
    'packageFamilyName',
    _windowsPackageFamilyName,
  );
  _requireCandidateValue(windowsCandidate, 'storeId', _windowsStoreId);
  _requireCandidateValue(
    windowsCandidate,
    'storeUri',
    'ms-windows-store://pdp/?productid=$_windowsStoreId',
  );
  _requireCandidateValue(
    windowsCandidate,
    'storeUrl',
    'https://apps.microsoft.com/detail/$_windowsStoreId',
  );
  _requireCandidateValue(windowsCandidate, 'repository', expectedRepository);
  if (_positiveInt(windowsCandidate, 'buildNumber') != candidate.buildNumber ||
      _positiveInt(windowsCandidate, 'runId') != expectedSourceRunId ||
      _positiveInt(windowsCandidate, 'runAttempt') <= 0 ||
      _text(windowsCandidate, 'packageVersion') !=
          '1.0.${candidate.buildNumber}.0') {
    throw const FormatException('Windows 候选构建或运行身份不匹配');
  }
  final windowsArtifact = _object(
    windowsCandidate['artifact'],
    'Windows artifact',
  );
  final windowsArtifactName = _text(windowsArtifact, 'name');
  if (windowsArtifactName !=
      'meettrace-${candidate.releaseId}-windows-store-x64.msix') {
    throw const FormatException('Windows Store 候选文件名不匹配');
  }
  final windowsArtifactBytes = _positiveInt(windowsArtifact, 'bytes');
  final windowsArtifactSha256 = _sha(windowsArtifact, 'sha256', 64);
  if (windowsArtifact['storeSubmissionCandidate'] != true) {
    throw const FormatException('Windows 候选不是 Store submission 候选');
  }

  _requireCandidateValue(windowsProductionReceipt, 'schemaVersion', 1);
  _requireCandidateValue(
    windowsProductionReceipt,
    'distribution',
    'microsoftStore',
  );
  _requireCandidateValue(
    windowsProductionReceipt,
    'productId',
    _windowsStoreId,
  );
  _requireCandidateValue(windowsProductionReceipt, 'status', 'Published');
  _requireCandidateValue(windowsProductionReceipt, 'visibility', 'Public');
  _requireCandidateValue(
    windowsProductionReceipt,
    'releaseId',
    candidate.releaseId,
  );
  _requireCandidateValue(
    windowsProductionReceipt,
    'candidateCommitSha',
    candidate.sourceCommitSha,
  );
  if (_positiveInt(windowsProductionReceipt, 'sourceRunId') !=
      expectedSourceRunId) {
    throw const FormatException('Windows 生产回执来源运行不匹配');
  }
  final windowsVerificationMode = _text(
    windowsProductionReceipt,
    'verificationMode',
  );
  if (windowsVerificationMode != 'manualEnvironmentApproval' &&
      windowsVerificationMode != 'partnerCenterApi') {
    throw const FormatException('Windows 生产回执验证模式未知');
  }
  final productionPackage = _object(
    windowsProductionReceipt['package'],
    'Windows production package',
  );
  _requireCandidateValue(productionPackage, 'fileName', windowsArtifactName);
  _requireCandidateValue(
    productionPackage,
    'version',
    '1.0.${candidate.buildNumber}.0',
  );
  _requireCandidateValue(productionPackage, 'architecture', 'x64');
  _requireCandidateValue(productionPackage, 'fileStatus', 'Uploaded');
  if (windowsVerificationMode == 'manualEnvironmentApproval') {
    _requireCandidateValue(
      productionPackage,
      'candidateSha256',
      windowsArtifactSha256,
    );
    final approval = _object(
      windowsProductionReceipt['approval'],
      'Windows approval',
    );
    _requireCandidateValue(
      windowsProductionReceipt,
      'evidenceSource',
      'github-release',
    );
    if (_positiveInt(approval, 'runId') != expectedSourceRunId) {
      throw const FormatException('Windows 审批运行不匹配');
    }
    _requireCandidateValue(approval, 'environment', 'github-release');
    final reviewer = _text(approval, 'reviewer');
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,38}$').hasMatch(reviewer)) {
      throw const FormatException('Windows 审批人格式无效');
    }
    final expectedComment =
        'STORE $_windowsStoreId Published Public '
        '1.0.${candidate.buildNumber}.0 x64 $windowsArtifactSha256';
    final comment = _text(approval, 'comment');
    _requireCandidateValue(approval, 'comment', expectedComment);
    final commentDigest = sha256.convert(utf8.encode(comment)).toString();
    _requireCandidateValue(approval, 'commentSha256', commentDigest);
  }

  return PublicUpdateValidationReceipt(
    releaseId: candidate.releaseId,
    versionName: candidate.versionName,
    buildNumber: candidate.buildNumber,
    dataGeneration: candidate.dataGeneration,
    sourceCommitSha: candidate.sourceCommitSha,
    sourceRunId: expectedSourceRunId,
    approvedAt: candidate.approvedAt,
    androidArtifactName: artifactName,
    androidBytes: artifactBytes,
    androidSha256: artifactSha256,
    androidSigningIdentitySha256: signingIdentity,
    androidInstallUri: android.artifact.installUri,
    iosInstallUri: ios.artifact.installUri,
    windowsInstallUri: windows.artifact.installUri,
    iosArtifactName: iosArtifactName,
    iosArtifactSha256: iosArtifactSha256,
    windowsArtifactName: windowsArtifactName,
    windowsArtifactBytes: windowsArtifactBytes,
    windowsArtifactSha256: windowsArtifactSha256,
    windowsVerificationMode: windowsVerificationMode,
  );
}

void _requireSameCandidate(
  AppUpdateCandidate expected,
  AppUpdateCandidate actual,
) {
  if (actual.releaseId != expected.releaseId ||
      actual.versionName != expected.versionName ||
      actual.buildNumber != expected.buildNumber ||
      actual.dataGeneration != expected.dataGeneration ||
      actual.status != expected.status ||
      actual.sourceCommitSha != expected.sourceCommitSha ||
      actual.approvedAt != expected.approvedAt) {
    throw const FormatException('三平台更新候选身份不一致');
  }
}

void _requireCandidateValue(
  Map<String, Object?> json,
  String key,
  Object expected,
) {
  if (json[key] != expected) {
    throw FormatException('$key 不匹配');
  }
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$name 必须是 JSON object');
  }
  return value;
}

String _text(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串');
  }
  return value;
}

int _positiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed <= 0) {
    throw FormatException('$key 必须是正整数');
  }
  return parsed;
}

String _sha(Map<String, Object?> json, String key, int length) {
  final value = _text(json, key).toLowerCase();
  if (!RegExp('^[0-9a-f]{$length}\$').hasMatch(value)) {
    throw FormatException('$key 必须是 $length 位十六进制摘要');
  }
  return value;
}
