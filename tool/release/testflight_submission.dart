import 'dart:convert';

const testFlightStatusMaximumResponseBytes = 512 * 1024;

final class TestFlightVerificationRequest {
  const TestFlightVerificationRequest({
    required this.bundleId,
    required this.marketingVersion,
    required this.buildNumber,
    required this.externalGroup,
    required this.publicLink,
    required this.releaseId,
    required this.candidateCommitSha,
    required this.sourceRunId,
    required this.verifiedAt,
  });

  final String bundleId;
  final String marketingVersion;
  final int buildNumber;
  final String externalGroup;
  final Uri publicLink;
  final String releaseId;
  final String candidateCommitSha;
  final int sourceRunId;
  final DateTime verifiedAt;
}

Map<String, Object?> verifyTestFlightStatus(
  String source,
  TestFlightVerificationRequest request,
) {
  _validateRequest(request);
  if (utf8.encode(source).length > testFlightStatusMaximumResponseBytes) {
    throw const FormatException('TestFlight 状态响应超过 512 KiB 上限');
  }
  final status = _object(jsonDecode(source), 'status');
  if (_requiredInt(status, 'schemaVersion') != 1) {
    throw const FormatException('TestFlight 状态响应 schema 不受支持');
  }
  final bundleId = _requiredText(status, 'bundleId');
  final marketingVersion = _requiredText(status, 'marketingVersion');
  final buildNumber = _requiredInt(status, 'buildNumber');
  final appId = _safeIdentifier(status, 'appId');
  final buildId = _safeIdentifier(status, 'buildId');
  final processingState = _requiredText(status, 'processingState');
  final betaReviewState = _requiredText(status, 'betaReviewState');
  final externalBuildState = _requiredText(status, 'externalBuildState');
  final testing = status['testing'];
  final expired = status['expired'];
  final publicLink = Uri.parse(_requiredText(status, 'publicLink'));
  final groups = _requiredTextList(status, 'externalGroups');

  if (bundleId != request.bundleId ||
      marketingVersion != request.marketingVersion ||
      buildNumber != request.buildNumber) {
    throw const FormatException('TestFlight build 身份与候选不匹配');
  }
  if (processingState != 'VALID') {
    throw FormatException('TestFlight build 尚未处理完成：$processingState');
  }
  if (betaReviewState != 'APPROVED') {
    throw FormatException('TestFlight Beta App Review 尚未通过：$betaReviewState');
  }
  if (externalBuildState != 'READY_FOR_EXTERNAL_TESTING' &&
      externalBuildState != 'TESTING') {
    throw FormatException('TestFlight 外测状态不可用：$externalBuildState');
  }
  if (testing is! bool || !testing) {
    throw const FormatException('TestFlight build 尚未进入 Testing');
  }
  if (expired is! bool || expired) {
    throw const FormatException('TestFlight build 已过期或过期状态无效');
  }
  if (!groups.contains(request.externalGroup)) {
    throw const FormatException('TestFlight build 未加入固定外部测试组');
  }
  if (publicLink != request.publicLink) {
    throw const FormatException('TestFlight public link 与固定配置不匹配');
  }

  return <String, Object?>{
    'schemaVersion': 1,
    'distribution': 'testFlightExternal',
    'verificationMode': 'appStoreConnectApi',
    'releaseId': request.releaseId,
    'candidateCommitSha': request.candidateCommitSha,
    'sourceRunId': request.sourceRunId,
    'verifiedAtUtc': request.verifiedAt.toUtc().toIso8601String(),
    'bundleId': bundleId,
    'marketingVersion': marketingVersion,
    'buildNumber': buildNumber,
    'appId': appId,
    'buildId': buildId,
    'processingState': 'VALID',
    'betaReviewState': 'APPROVED',
    'externalBuildState': externalBuildState,
    'testing': true,
    'expired': false,
    'externalGroup': request.externalGroup,
    'publicLink': publicLink.toString(),
  };
}

void _validateRequest(TestFlightVerificationRequest request) {
  if (request.bundleId != 'com.meettrace.app') {
    throw const FormatException('TestFlight bundle ID 不匹配');
  }
  if (!RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$').hasMatch(request.marketingVersion)) {
    throw const FormatException('TestFlight 营销版本格式无效');
  }
  if (request.buildNumber < 2001) {
    throw const FormatException('TestFlight 构建号低于统一版本序列');
  }
  if (request.externalGroup.trim().isEmpty ||
      request.externalGroup.length > 128) {
    throw const FormatException('TestFlight 外测组名无效');
  }
  if (request.publicLink.scheme != 'https' ||
      request.publicLink.host != 'testflight.apple.com' ||
      !RegExp(r'^/join/[A-Za-z0-9]+/?$').hasMatch(request.publicLink.path)) {
    throw const FormatException('TestFlight public link 无效');
  }
  if (!RegExp(r'^v[0-9]+\.[0-9]+\.[0-9]+-alpha\.[1-9][0-9]*$')
      .hasMatch(request.releaseId)) {
    throw const FormatException('releaseId 格式无效');
  }
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(request.candidateCommitSha)) {
    throw const FormatException('候选提交必须是小写 40 位 SHA');
  }
  if (request.sourceRunId <= 0 || !request.verifiedAt.isUtc) {
    throw const FormatException('TestFlight 回执来源或时间无效');
  }
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map) {
    throw FormatException('$name 必须是 JSON object');
  }
  return value.map((key, value) {
    if (key is! String) {
      throw FormatException('$name 的 key 必须是字符串');
    }
    return MapEntry(key, value);
  });
}

String _requiredText(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串');
  }
  return value;
}

String _safeIdentifier(Map<String, Object?> json, String key) {
  final value = _requiredText(json, key);
  if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(value)) {
    throw FormatException('$key 格式无效');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is String && RegExp(r'^[1-9][0-9]*$').hasMatch(value)) {
    return int.parse(value);
  }
  throw FormatException('$key 必须是正整数');
}

List<String> _requiredTextList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key 必须是非空字符串列表');
  }
  return value
      .map((item) {
        if (item is! String || item.trim().isEmpty) {
          throw FormatException('$key 包含无效值');
        }
        return item;
      })
      .toList(growable: false);
}
