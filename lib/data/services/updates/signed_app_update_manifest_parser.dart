import 'dart:convert';
import 'dart:typed_data';

import '../../../domain/models/app_update.dart';

const _microsoftStorePackageIdentity = 'zhangheng2026.MeetTrace';
const _microsoftStoreInstallUri =
    'ms-windows-store://pdp/?productid=9PHHSJMWK06G';

enum AppUpdatePlatform { android, ios, windows }

abstract interface class AppUpdateManifestSignatureVerifier {
  Future<bool> verify({
    required Uint8List signedPayload,
    required String algorithm,
    required String keyId,
    required Uint8List signature,
  });
}

final class VerifiedPlatformUpdateArtifact {
  const VerifiedPlatformUpdateArtifact({
    required this.platform,
    required this.installUri,
    this.bytes,
    this.sha256,
    this.packageIdentity,
    this.signingIdentitySha256,
  });

  final AppUpdatePlatform platform;
  final Uri installUri;
  final int? bytes;
  final String? sha256;
  final String? packageIdentity;
  final String? signingIdentitySha256;
}

final class VerifiedPlatformAppUpdate {
  const VerifiedPlatformAppUpdate({
    required this.candidate,
    required this.artifact,
  });

  final AppUpdateCandidate candidate;
  final VerifiedPlatformUpdateArtifact artifact;
}

/// 验证签名 envelope 后解析单一 Alpha 频道的平台更新候选。
///
/// 签名直接覆盖 `signedPayload` 的 Base64 解码字节，避免 JSON key 顺序、空白
/// 或编码差异改变验签结果。
final class SignedAppUpdateManifestParser {
  const SignedAppUpdateManifestParser({required this.signatureVerifier});

  final AppUpdateManifestSignatureVerifier signatureVerifier;

  Future<VerifiedPlatformAppUpdate> parse(
    List<int> envelopeBytes, {
    required AppUpdatePlatform platform,
  }) async {
    final envelope = _jsonObject(utf8.decode(envelopeBytes), '更新 envelope');
    if (envelope['schemaVersion'] != 1) {
      throw const FormatException('不支持的更新 envelope schemaVersion');
    }
    final payloadBytes = _base64Bytes(envelope, 'signedPayload');
    final signature = _jsonObject(envelope['signature'], 'signature');
    final algorithm = _text(signature, 'algorithm');
    final keyId = _text(signature, 'keyId');
    final signatureBytes = _base64Bytes(signature, 'value');
    if (!await signatureVerifier.verify(
      signedPayload: payloadBytes,
      algorithm: algorithm,
      keyId: keyId,
      signature: signatureBytes,
    )) {
      throw const FormatException('更新 Manifest 签名无效');
    }

    final payload = _jsonObject(utf8.decode(payloadBytes), 'signedPayload');
    if (payload['schemaVersion'] != 1 || payload['channel'] != 'alpha') {
      throw const FormatException('更新 Manifest schema 或频道不受支持');
    }
    final status = switch (_text(payload, 'status')) {
      'publicApproved' => AppUpdateCandidateStatus.publicApproved,
      'withdrawn' => AppUpdateCandidateStatus.withdrawn,
      _ => throw const FormatException('更新候选不是公开批准或已撤回状态'),
    };
    final artifacts = _jsonObject(payload['artifacts'], 'artifacts');
    final artifactJson = _jsonObject(artifacts[platform.name], platform.name);
    final artifactId = _text(artifactJson, 'artifactId');
    final artifact = _parseArtifact(platform, artifactJson);
    final candidate = AppUpdateCandidate(
      releaseId: _text(payload, 'releaseId'),
      versionName: _text(payload, 'versionName'),
      buildNumber: _positiveInt(payload, 'buildNumber'),
      dataGeneration: _positiveInt(payload, 'dataGeneration'),
      status: status,
      sourceCommitSha: _sha(payload, 'sourceCommitSha'),
      artifactId: artifactId,
      approvedAt: _utcDate(payload, 'approvedAt'),
    );
    return VerifiedPlatformAppUpdate(candidate: candidate, artifact: artifact);
  }

  VerifiedPlatformUpdateArtifact _parseArtifact(
    AppUpdatePlatform platform,
    Map<String, Object?> json,
  ) {
    final installUri = Uri.parse(_text(json, 'installUri'));
    switch (platform) {
      case AppUpdatePlatform.android:
        _requireHttps(installUri);
        final packageIdentity = _text(json, 'packageIdentity');
        if (packageIdentity != 'com.meettrace.app') {
          throw const FormatException('Android 更新包名不匹配');
        }
        return VerifiedPlatformUpdateArtifact(
          platform: platform,
          installUri: installUri,
          bytes: _positiveInt(json, 'bytes'),
          sha256: _sha(json, 'sha256'),
          packageIdentity: packageIdentity,
          signingIdentitySha256: _sha(json, 'signingIdentitySha256'),
        );
      case AppUpdatePlatform.ios:
        _requireHttps(installUri);
        if (installUri.host != 'testflight.apple.com') {
          throw const FormatException('iOS 更新入口必须是 TestFlight');
        }
        return VerifiedPlatformUpdateArtifact(
          platform: platform,
          installUri: installUri,
        );
      case AppUpdatePlatform.windows:
        final distribution = _text(json, 'distribution');
        if (distribution != 'store') {
          throw const FormatException('Windows 当前只接受 Microsoft Store 更新');
        }
        if (installUri.toString() != _microsoftStoreInstallUri) {
          throw const FormatException('Store 更新入口与固定产品 ID 不匹配');
        }
        final packageIdentity = _text(json, 'packageIdentity');
        if (packageIdentity != _microsoftStorePackageIdentity) {
          throw const FormatException('Windows Store 包身份不匹配');
        }
        return VerifiedPlatformUpdateArtifact(
          platform: platform,
          installUri: installUri,
          packageIdentity: packageIdentity,
        );
    }
  }
}

Map<String, Object?> _jsonObject(Object? value, String name) {
  final Object? decoded = value is String ? jsonDecode(value) : value;
  if (decoded is! Map<String, Object?>) {
    throw FormatException('$name 必须是 JSON object');
  }
  return decoded;
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
  if (value is! int || value <= 0) {
    throw FormatException('$key 必须是正整数');
  }
  return value;
}

String _sha(Map<String, Object?> json, String key) {
  final value = _text(json, key).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value) && key != 'sourceCommitSha') {
    throw FormatException('$key 必须是 64 位十六进制 SHA-256');
  }
  if (key == 'sourceCommitSha' && !RegExp(r'^[0-9a-f]{40}$').hasMatch(value)) {
    throw FormatException('$key 必须是 40 位 Git commit SHA');
  }
  return value;
}

DateTime _utcDate(Map<String, Object?> json, String key) {
  final parsed = DateTime.tryParse(_text(json, key));
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$key 必须是 UTC ISO-8601 时间');
  }
  return parsed;
}

Uint8List _base64Bytes(Map<String, Object?> json, String key) {
  try {
    final decoded = base64Decode(_text(json, key));
    if (decoded.isEmpty) {
      throw const FormatException('Base64 内容不能为空');
    }
    return decoded;
  } on FormatException {
    throw FormatException('$key 必须是有效的非空 Base64');
  }
}

void _requireHttps(Uri uri) {
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw const FormatException('更新入口必须是无用户信息的 HTTPS URL');
  }
}
