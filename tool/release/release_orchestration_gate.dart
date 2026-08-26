import 'dart:convert';

const releaseOrchestrationGateMaximumBytes = 1024 * 1024;

final class ReleaseOrchestrationGateRequest {
  const ReleaseOrchestrationGateRequest({
    required this.releaseId,
    required this.candidateCommitSha,
    required this.sourceRunId,
    required this.orchestrationRunId,
    required this.buildNumber,
    required this.marketingVersion,
    required this.testFlightExternalGroup,
    required this.windowsArtifactName,
    required this.windowsPackageVersion,
    required this.windowsFlightId,
    required this.testFlightPublicLink,
  });

  final String releaseId;
  final String candidateCommitSha;
  final int sourceRunId;
  final int orchestrationRunId;
  final int buildNumber;
  final String marketingVersion;
  final String testFlightExternalGroup;
  final String windowsArtifactName;
  final String windowsPackageVersion;
  final String windowsFlightId;
  final Uri testFlightPublicLink;
}

Map<String, Object?> verifyReleaseOrchestrationGate(
  String source,
  ReleaseOrchestrationGateRequest request,
) {
  _validateRequest(request);
  if (utf8.encode(source).length > releaseOrchestrationGateMaximumBytes) {
    throw const FormatException('发布协调门禁超过 1 MiB 上限');
  }
  final gate = _object(jsonDecode(source), 'gate');
  _require(gate, 'schemaVersion', 1);
  _require(gate, 'releaseId', request.releaseId);
  _require(gate, 'candidateCommitSha', request.candidateCommitSha);
  _requirePositiveInt(gate, 'sourceRunId', request.sourceRunId);
  _requirePositiveInt(gate, 'orchestrationRunId', request.orchestrationRunId);
  _requirePositiveInt(gate, 'buildNumber', request.buildNumber);

  final testFlight = _object(gate['testFlight'], 'testFlight');
  _require(testFlight, 'schemaVersion', 1);
  _require(testFlight, 'distribution', 'testFlightExternal');
  _require(testFlight, 'verificationMode', 'appStoreConnectApi');
  _require(testFlight, 'releaseId', request.releaseId);
  _require(testFlight, 'candidateCommitSha', request.candidateCommitSha);
  _requirePositiveInt(testFlight, 'sourceRunId', request.sourceRunId);
  _requirePositiveInt(testFlight, 'buildNumber', request.buildNumber);
  _require(testFlight, 'bundleId', 'com.meettrace.app');
  _require(testFlight, 'marketingVersion', request.marketingVersion);
  _require(testFlight, 'processingState', 'VALID');
  _require(testFlight, 'betaReviewState', 'APPROVED');
  if (testFlight['externalBuildState'] != 'IN_BETA_TESTING') {
    throw const FormatException('TestFlight 外测状态未通过门禁');
  }
  _require(testFlight, 'testing', true);
  _require(testFlight, 'expired', false);
  _require(testFlight, 'externalGroup', request.testFlightExternalGroup);
  _require(testFlight, 'publicLink', request.testFlightPublicLink.toString());

  final flight = _object(gate['windowsFlight'], 'windowsFlight');
  _verifyStoreReceipt(
    flight,
    request,
    distribution: 'microsoftStoreFlight',
    requirePublic: false,
  );
  _require(flight, 'flightId', request.windowsFlightId);

  final production = _object(gate['windowsProduction'], 'windowsProduction');
  _verifyStoreReceipt(
    production,
    request,
    distribution: 'microsoftStore',
    requirePublic: true,
  );

  final validations = _object(gate['validations'], 'validations');
  final flightValidation = _object(validations['flight'], 'validations.flight');
  final productionValidation = _object(
    validations['production'],
    'validations.production',
  );
  _verifyDistributionValidation(flightValidation, request, 'flight');
  _verifyDistributionValidation(productionValidation, request, 'production');
  final flightRunId = _positiveInt(flightValidation, 'validationRunId');
  final productionRunId = _positiveInt(productionValidation, 'validationRunId');
  if (flightRunId == productionRunId) {
    throw const FormatException('Flight 与 production 必须由不同验证运行证明');
  }

  return <String, Object?>{
    'schemaVersion': 1,
    'releaseId': request.releaseId,
    'candidateCommitSha': request.candidateCommitSha,
    'sourceRunId': request.sourceRunId,
    'orchestrationRunId': request.orchestrationRunId,
    'buildNumber': request.buildNumber,
    'testFlightBuildId': _safeIdentifier(testFlight, 'buildId'),
    'windowsFlightSubmissionId': _safeIdentifier(flight, 'submissionId'),
    'windowsProductionSubmissionId': _safeIdentifier(
      production,
      'submissionId',
    ),
    'flightValidationRunId': flightRunId,
    'productionValidationRunId': productionRunId,
    'verifiedAtUtc': DateTime.now().toUtc().toIso8601String(),
  };
}

void _verifyStoreReceipt(
  Map<String, Object?> receipt,
  ReleaseOrchestrationGateRequest request, {
  required String distribution,
  required bool requirePublic,
}) {
  _require(receipt, 'schemaVersion', 1);
  _require(receipt, 'distribution', distribution);
  _require(receipt, 'verificationMode', 'partnerCenterApi');
  _require(receipt, 'productId', '9PHHSJMWK06G');
  _require(receipt, 'status', 'Published');
  if (requirePublic) {
    _require(receipt, 'visibility', 'Public');
  }
  _require(receipt, 'releaseId', request.releaseId);
  _require(receipt, 'candidateCommitSha', request.candidateCommitSha);
  _requirePositiveInt(receipt, 'sourceRunId', request.sourceRunId);
  final package = _object(receipt['package'], '$distribution.package');
  _require(package, 'fileName', request.windowsArtifactName);
  _require(package, 'version', request.windowsPackageVersion);
  _require(package, 'architecture', 'x64');
  _require(package, 'fileStatus', 'Uploaded');
}

void _verifyDistributionValidation(
  Map<String, Object?> receipt,
  ReleaseOrchestrationGateRequest request,
  String stage,
) {
  _require(receipt, 'schemaVersion', 1);
  _require(receipt, 'validation', 'candidateDistribution');
  _require(receipt, 'stage', stage);
  _require(receipt, 'releaseId', request.releaseId);
  _require(receipt, 'candidateCommitSha', request.candidateCommitSha);
  _requirePositiveInt(receipt, 'sourceRunId', request.sourceRunId);
  _positiveInt(receipt, 'reconcileRunId');
  _positiveInt(receipt, 'validationRunId');
  _require(receipt, 'androidFirebaseArm', 'passed');
  _require(receipt, 'windowsStoreLifecycle', 'passed');
}

void _validateRequest(ReleaseOrchestrationGateRequest request) {
  if (!RegExp(r'^v[0-9]+\.[0-9]+\.[0-9]+-alpha\.[1-9][0-9]*$')
      .hasMatch(request.releaseId)) {
    throw const FormatException('releaseId 格式无效');
  }
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(request.candidateCommitSha)) {
    throw const FormatException('候选提交必须是小写 40 位 SHA');
  }
  if (request.sourceRunId <= 0 ||
      request.orchestrationRunId <= 0 ||
      request.buildNumber < 2001) {
    throw const FormatException('发布运行或统一构建号无效');
  }
  if (request.windowsPackageVersion != '1.0.${request.buildNumber}.0' ||
      request.windowsArtifactName !=
          'meettrace-${request.releaseId}-windows-store-x64.msix') {
    throw const FormatException('Windows 候选身份与统一构建号不匹配');
  }
  if (!RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$').hasMatch(request.marketingVersion) ||
      request.testFlightExternalGroup.trim().isEmpty ||
      request.testFlightExternalGroup.length > 128 ||
      !RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(request.windowsFlightId)) {
    throw const FormatException('固定 TestFlight 或 Store Flight 配置无效');
  }
  if (request.testFlightPublicLink.scheme != 'https' ||
      request.testFlightPublicLink.host != 'testflight.apple.com' ||
      !RegExp(r'^/join/[A-Za-z0-9]+/?$')
          .hasMatch(request.testFlightPublicLink.path)) {
    throw const FormatException('TestFlight public link 无效');
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

void _require(Map<String, Object?> json, String key, Object expected) {
  if (json[key] != expected) {
    throw FormatException('$key 与发布门禁不匹配');
  }
}

int _positiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  final parsed = switch (value) {
    int() => value,
    String() when RegExp(r'^[1-9][0-9]*$').hasMatch(value) => int.parse(value),
    _ => 0,
  };
  if (parsed <= 0) {
    throw FormatException('$key 必须是正整数');
  }
  return parsed;
}

void _requirePositiveInt(Map<String, Object?> json, String key, int expected) {
  if (_positiveInt(json, key) != expected) {
    throw FormatException('$key 与发布门禁不匹配');
  }
}

String _safeIdentifier(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || !RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(value)) {
    throw FormatException('$key 格式无效');
  }
  return value;
}
