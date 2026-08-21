import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const updateSigningAlgorithm = 'Ed25519';
const _maxAndroidUpdateBytes = 512 * 1024 * 1024;

final class AppUpdateManifestSigningRequest {
  const AppUpdateManifestSigningRequest({
    required this.privateSeed,
    required this.expectedPublicKey,
    required this.keyId,
    required this.status,
    required this.releaseId,
    required this.versionName,
    required this.buildNumber,
    required this.dataGeneration,
    required this.sourceCommitSha,
    required this.approvedAt,
    required this.repository,
    required this.androidCandidate,
    required this.testFlightUri,
    this.previousEnvelope,
  });

  final List<int> privateSeed;
  final List<int> expectedPublicKey;
  final String keyId;
  final String status;
  final String releaseId;
  final String versionName;
  final int buildNumber;
  final int dataGeneration;
  final String sourceCommitSha;
  final DateTime approvedAt;
  final String repository;
  final Map<String, Object?> androidCandidate;
  final Uri testFlightUri;
  final List<int>? previousEnvelope;
}

Future<List<int>> createSignedAppUpdateManifest(
  AppUpdateManifestSigningRequest request,
) async {
  _validateRequest(request);
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(request.privateSeed);
  final publicKey = await keyPair.extractPublicKey();
  if (!_constantTimeEquals(publicKey.bytes, request.expectedPublicKey)) {
    throw StateError('更新签名私钥与客户端内置公钥不匹配');
  }

  final previousPayload = request.previousEnvelope == null
      ? null
      : await _verifyEnvelope(
          request.previousEnvelope!,
          expectedPublicKey: request.expectedPublicKey,
          expectedKeyId: request.keyId,
        );
  _validateTransition(request, previousPayload);

  final artifact = _object(request.androidCandidate['artifact'], 'artifact');
  if (_text(request.androidCandidate, 'releaseId') != request.releaseId ||
      _text(request.androidCandidate, 'marketingVersion') !=
          request.versionName ||
      _positiveInt(request.androidCandidate, 'buildNumber') !=
          request.buildNumber ||
      _text(request.androidCandidate, 'commitSha') != request.sourceCommitSha) {
    throw const FormatException('Android 候选身份与待签名版本不匹配');
  }
  final artifactName = _text(artifact, 'name');
  final artifactBytes = _positiveInt(artifact, 'bytes');
  if (artifactBytes > _maxAndroidUpdateBytes) {
    throw const FormatException('Android 更新包超过 512 MiB 上限');
  }
  final signingIdentity = _sha256(
    request.androidCandidate,
    'signingIdentitySha256',
  );
  final candidateSchema = _positiveInt(
    request.androidCandidate,
    'schemaVersion',
  );
  if (candidateSchema != 1 && candidateSchema != 2) {
    throw const FormatException('Android 候选 schemaVersion 不受支持');
  }
  final androidVersionCode = candidateSchema == 2
      ? _positiveInt(request.androidCandidate, 'versionCode')
      : null;
  if (candidateSchema == 2) {
    final androidBaseBuildNumber = _positiveInt(
      request.androidCandidate,
      'androidBaseBuildNumber',
    );
    if (androidVersionCode != androidBaseBuildNumber + 2000 ||
        androidVersionCode != request.buildNumber) {
      throw const FormatException('Android arm64 split versionCode 映射无效');
    }
  }
  if (_text(request.androidCandidate, 'packageIdentity') !=
      'com.meettrace.app') {
    throw const FormatException('Android 候选包名不匹配');
  }
  final encodedRelease = Uri.encodeComponent(request.releaseId);
  final encodedArtifact = Uri.encodeComponent(artifactName);
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'channel': 'alpha',
    'status': request.status,
    'releaseId': request.releaseId,
    'versionName': request.versionName,
    'buildNumber': request.buildNumber,
    'dataGeneration': request.dataGeneration,
    'sourceCommitSha': request.sourceCommitSha,
    'approvedAt': request.approvedAt.toUtc().toIso8601String(),
    'artifacts': <String, Object?>{
      'android': <String, Object?>{
        'artifactId': 'android-${request.buildNumber}-$artifactName',
        'installUri':
            'https://github.com/${request.repository}/releases/download/'
            '$encodedRelease/$encodedArtifact',
        'bytes': artifactBytes,
        'sha256': _sha256(artifact, 'sha256'),
        'packageIdentity': 'com.meettrace.app',
        'signingIdentitySha256': signingIdentity,
        'versionCode': ?androidVersionCode,
      },
      'ios': <String, Object?>{
        'artifactId': 'ios-testflight-${request.buildNumber}',
        'installUri': request.testFlightUri.toString(),
        'distribution': 'testflight',
      },
      'windows': <String, Object?>{
        'artifactId': 'windows-store-${request.buildNumber}',
        'installUri': 'ms-windows-store://pdp/?productid=9PHHSJMWK06G',
        'distribution': 'store',
        'packageIdentity': 'zhangheng2026.MeetTrace',
      },
    },
  };
  final payloadBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  final signature = await algorithm.sign(payloadBytes, keyPair: keyPair);
  return utf8.encode(
    '${jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'signedPayload': base64Encode(payloadBytes),
      'signature': <String, Object?>{'algorithm': updateSigningAlgorithm, 'keyId': request.keyId, 'value': base64Encode(signature.bytes)},
    })}\n',
  );
}

void _validateRequest(AppUpdateManifestSigningRequest request) {
  if (request.privateSeed.length != 32 ||
      request.expectedPublicKey.length != 32) {
    throw const FormatException('Ed25519 私钥 seed 和公钥必须各为 32 字节');
  }
  if (!RegExp(r'^alpha-[0-9a-f]{16}$').hasMatch(request.keyId)) {
    throw const FormatException('更新签名 keyId 格式无效');
  }
  if (request.status != 'publicApproved' && request.status != 'withdrawn') {
    throw const FormatException('更新状态必须是 publicApproved 或 withdrawn');
  }
  if (!RegExp(r'^v[0-9]+\.[0-9]+\.[0-9]+-alpha\.[1-9][0-9]*$')
      .hasMatch(request.releaseId)) {
    throw const FormatException('releaseId 格式无效');
  }
  if (request.versionName !=
      request.releaseId.substring(1, request.releaseId.indexOf('-alpha.'))) {
    throw const FormatException('releaseId 与 versionName 不匹配');
  }
  if (request.buildNumber <= 0 || request.dataGeneration <= 0) {
    throw const FormatException('构建号和数据代必须为正整数');
  }
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(request.sourceCommitSha)) {
    throw const FormatException('候选提交必须是小写 40 位 SHA');
  }
  if (!request.approvedAt.isUtc) {
    throw const FormatException('批准时间必须是 UTC');
  }
  if (!RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')
      .hasMatch(request.repository)) {
    throw const FormatException('GitHub repository 格式无效');
  }
  _validateTestFlightUri(request.testFlightUri);
}

void _validateTestFlightUri(Uri uri) {
  final validPath =
      uri.path == '/' || RegExp(r'^/join/[A-Za-z0-9]+/?$').hasMatch(uri.path);
  if (uri.scheme != 'https' ||
      uri.host != 'testflight.apple.com' ||
      uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      !validPath) {
    throw const FormatException('iOS 更新入口必须是受支持的 TestFlight URL');
  }
}

Future<Map<String, Object?>> _verifyEnvelope(
  List<int> bytes, {
  required List<int> expectedPublicKey,
  required String expectedKeyId,
}) async {
  final envelope = _object(jsonDecode(utf8.decode(bytes)), 'previous envelope');
  if (envelope['schemaVersion'] != 1) {
    throw const FormatException('上一更新 envelope schema 无效');
  }
  final payloadBytes = base64Decode(_text(envelope, 'signedPayload'));
  final signatureJson = _object(envelope['signature'], 'signature');
  if (_text(signatureJson, 'algorithm') != updateSigningAlgorithm ||
      _text(signatureJson, 'keyId') != expectedKeyId) {
    throw const FormatException('上一更新 envelope 的签名身份无效');
  }
  final signatureBytes = base64Decode(_text(signatureJson, 'value'));
  if (signatureBytes.length != 64) {
    throw const FormatException('上一更新 envelope 的签名长度无效');
  }
  final algorithm = Ed25519();
  final valid = await algorithm.verify(
    payloadBytes,
    signature: Signature(
      signatureBytes,
      publicKey: SimplePublicKey(expectedPublicKey, type: KeyPairType.ed25519),
    ),
  );
  if (!valid) {
    throw const FormatException('上一更新 envelope 签名无效');
  }
  final payload = _object(
    jsonDecode(utf8.decode(payloadBytes)),
    'previous payload',
  );
  if (payload['schemaVersion'] != 1 || payload['channel'] != 'alpha') {
    throw const FormatException('上一更新 payload schema 或频道无效');
  }
  return payload;
}

void _validateTransition(
  AppUpdateManifestSigningRequest request,
  Map<String, Object?>? previous,
) {
  if (previous == null) {
    if (request.status == 'withdrawn') {
      throw StateError('不存在公开更新时不能创建撤回指针');
    }
    return;
  }
  final previousBuild = _positiveInt(previous, 'buildNumber');
  final previousRelease = _text(previous, 'releaseId');
  final previousStatus = _text(previous, 'status');
  if (previousStatus != 'publicApproved' && previousStatus != 'withdrawn') {
    throw const FormatException('上一更新状态无效');
  }
  final sameCandidate =
      previousBuild == request.buildNumber &&
      previousRelease == request.releaseId;
  if (request.status == 'withdrawn') {
    if (!sameCandidate || previousStatus != 'publicApproved') {
      throw StateError('只能撤回当前公开批准的更新');
    }
    return;
  }
  if (sameCandidate) {
    if (previousStatus != 'publicApproved') {
      throw StateError('已撤回更新不得重新公开');
    }
    return;
  }
  if (request.buildNumber <= previousBuild) {
    throw StateError('更新频道拒绝构建号回滚或复用');
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

String _sha256(Map<String, Object?> json, String key) {
  final value = _text(json, key).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw FormatException('$key 必须是 64 位十六进制 SHA-256');
  }
  return value;
}

bool _constantTimeEquals(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
