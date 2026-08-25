import 'dart:convert';

const microsoftStoreSubmissionMaximumResponseBytes = 2 * 1024 * 1024;

final class MicrosoftStoreSubmissionVerificationRequest {
  const MicrosoftStoreSubmissionVerificationRequest({
    required this.productId,
    required this.expectedPackageVersion,
    required this.expectedArtifactName,
    required this.releaseId,
    required this.candidateCommitSha,
    required this.sourceRunId,
    required this.verifiedAt,
  });

  final String productId;
  final String expectedPackageVersion;
  final String expectedArtifactName;
  final String releaseId;
  final String candidateCommitSha;
  final int sourceRunId;
  final DateTime verifiedAt;
}

final class MicrosoftStoreFlightVerificationRequest {
  const MicrosoftStoreFlightVerificationRequest({
    required this.productId,
    required this.flightId,
    required this.expectedPackageVersion,
    required this.expectedArtifactName,
    required this.releaseId,
    required this.candidateCommitSha,
    required this.sourceRunId,
    required this.verifiedAt,
  });

  final String productId;
  final String flightId;
  final String expectedPackageVersion;
  final String expectedArtifactName;
  final String releaseId;
  final String candidateCommitSha;
  final int sourceRunId;
  final DateTime verifiedAt;
}

Map<String, Object?> verifyMicrosoftStoreSubmission(
  String source,
  MicrosoftStoreSubmissionVerificationRequest request,
) {
  _validateRequest(request);
  if (utf8.encode(source).length >
      microsoftStoreSubmissionMaximumResponseBytes) {
    throw const FormatException('Microsoft Store submission 响应超过 2 MiB 上限');
  }
  final submission = _object(jsonDecode(source), 'submission');
  final submissionId = _requiredText(submission, 'Id');
  if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(submissionId)) {
    throw const FormatException('Microsoft Store submission ID 格式无效');
  }
  final status = _requiredText(submission, 'Status');
  if (status.toLowerCase() != 'published') {
    throw FormatException('Microsoft Store submission 尚未公开：$status');
  }
  final visibility = _requiredText(submission, 'Visibility');
  if (visibility.toLowerCase() != 'public') {
    throw FormatException('Microsoft Store submission 不是 Public：$visibility');
  }
  final packagesValue = _field(submission, 'ApplicationPackages');
  if (packagesValue is! List<Object?> || packagesValue.length != 1) {
    throw const FormatException('Microsoft Store submission 必须恰好包含一个 x64 包');
  }
  final package = _object(packagesValue.single, 'ApplicationPackages[0]');
  final fileName = _requiredText(package, 'FileName');
  final version = _requiredText(package, 'Version');
  final architecture = _requiredText(package, 'Architecture');
  final fileStatus = _requiredText(package, 'FileStatus');
  if (fileName != request.expectedArtifactName) {
    throw FormatException('Microsoft Store 包文件名不匹配：$fileName');
  }
  if (version != request.expectedPackageVersion) {
    throw FormatException('Microsoft Store 包版本不匹配：$version');
  }
  if (architecture.toLowerCase() != 'x64') {
    throw FormatException('Microsoft Store 包架构不是 x64：$architecture');
  }
  if (fileStatus.toLowerCase() != 'uploaded') {
    throw FormatException('Microsoft Store 包未完成上传：$fileStatus');
  }

  return <String, Object?>{
    'schemaVersion': 1,
    'distribution': 'microsoftStore',
    'verificationMode': 'partnerCenterApi',
    'productId': request.productId,
    'submissionId': submissionId,
    'status': 'Published',
    'visibility': 'Public',
    'releaseId': request.releaseId,
    'candidateCommitSha': request.candidateCommitSha,
    'sourceRunId': request.sourceRunId,
    'verifiedAtUtc': request.verifiedAt.toUtc().toIso8601String(),
    'package': <String, Object?>{
      'fileName': fileName,
      'version': version,
      'architecture': 'x64',
      'fileStatus': 'Uploaded',
    },
  };
}

Map<String, Object?> verifyMicrosoftStoreFlightSubmission(
  String source,
  MicrosoftStoreFlightVerificationRequest request,
) {
  _validateRequest(
    MicrosoftStoreSubmissionVerificationRequest(
      productId: request.productId,
      expectedPackageVersion: request.expectedPackageVersion,
      expectedArtifactName: request.expectedArtifactName,
      releaseId: request.releaseId,
      candidateCommitSha: request.candidateCommitSha,
      sourceRunId: request.sourceRunId,
      verifiedAt: request.verifiedAt,
    ),
  );
  if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(request.flightId)) {
    throw const FormatException('Microsoft Store Flight ID 格式无效');
  }
  if (utf8.encode(source).length >
      microsoftStoreSubmissionMaximumResponseBytes) {
    throw const FormatException('Microsoft Store submission 响应超过 2 MiB 上限');
  }
  final submission = _object(jsonDecode(source), 'submission');
  final submissionId = _requiredText(submission, 'Id');
  if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(submissionId)) {
    throw const FormatException('Microsoft Store Flight submission ID 格式无效');
  }
  final status = _requiredText(submission, 'Status');
  if (status.toLowerCase() != 'published') {
    throw FormatException('Microsoft Store Flight 尚未发布：$status');
  }
  final packagesValue = _field(submission, 'ApplicationPackages');
  if (packagesValue is! List<Object?> || packagesValue.length != 1) {
    throw const FormatException('Microsoft Store Flight 必须恰好包含一个 x64 包');
  }
  final package = _object(packagesValue.single, 'ApplicationPackages[0]');
  final fileName = _requiredText(package, 'FileName');
  final version = _requiredText(package, 'Version');
  final architecture = _requiredText(package, 'Architecture');
  final fileStatus = _requiredText(package, 'FileStatus');
  if (fileName != request.expectedArtifactName ||
      version != request.expectedPackageVersion) {
    throw const FormatException('Microsoft Store Flight 包与候选不匹配');
  }
  if (architecture.toLowerCase() != 'x64' ||
      fileStatus.toLowerCase() != 'uploaded') {
    throw const FormatException('Microsoft Store Flight 包架构或上传状态无效');
  }

  return <String, Object?>{
    'schemaVersion': 1,
    'distribution': 'microsoftStoreFlight',
    'verificationMode': 'partnerCenterApi',
    'productId': request.productId,
    'flightId': request.flightId,
    'submissionId': submissionId,
    'status': 'Published',
    'releaseId': request.releaseId,
    'candidateCommitSha': request.candidateCommitSha,
    'sourceRunId': request.sourceRunId,
    'verifiedAtUtc': request.verifiedAt.toUtc().toIso8601String(),
    'package': <String, Object?>{
      'fileName': fileName,
      'version': version,
      'architecture': 'x64',
      'fileStatus': 'Uploaded',
    },
  };
}

void _validateRequest(MicrosoftStoreSubmissionVerificationRequest request) {
  if (request.productId != '9PHHSJMWK06G') {
    throw const FormatException('Microsoft Store product ID 不匹配');
  }
  if (!RegExp(r'^1\.0\.[1-9][0-9]*\.0$')
      .hasMatch(request.expectedPackageVersion)) {
    throw const FormatException('Microsoft Store 包版本格式无效');
  }
  final storeBuildNumber = int.parse(
    request.expectedPackageVersion.split('.')[2],
  );
  if (storeBuildNumber > 65535) {
    throw const FormatException('Microsoft Store 包构建号超过 65535');
  }
  if (!RegExp(
    r'^meettrace-v[0-9]+\.[0-9]+\.[0-9]+-alpha\.[1-9][0-9]*-windows-store-x64\.msix$',
  ).hasMatch(request.expectedArtifactName)) {
    throw const FormatException('Microsoft Store 候选文件名格式无效');
  }
  if (!RegExp(r'^v[0-9]+\.[0-9]+\.[0-9]+-alpha\.[1-9][0-9]*$')
      .hasMatch(request.releaseId)) {
    throw const FormatException('releaseId 格式无效');
  }
  final artifactRelease = request.expectedArtifactName.substring(
    'meettrace-'.length,
    request.expectedArtifactName.length - '-windows-store-x64.msix'.length,
  );
  if (artifactRelease != request.releaseId) {
    throw const FormatException('Microsoft Store 候选文件名与 releaseId 不匹配');
  }
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(request.candidateCommitSha)) {
    throw const FormatException('候选提交必须是小写 40 位 SHA');
  }
  if (request.sourceRunId <= 0) {
    throw const FormatException('来源运行 ID 必须是正整数');
  }
  if (!request.verifiedAt.isUtc) {
    throw const FormatException('Store 验证时间必须是 UTC');
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

Object? _field(Map<String, Object?> json, String key) {
  final matches = json.entries
      .where((entry) => entry.key.toLowerCase() == key.toLowerCase())
      .toList(growable: false);
  if (matches.length > 1) {
    throw FormatException('$key 存在大小写重复字段');
  }
  return matches.isEmpty ? null : matches.single.value;
}

String _requiredText(Map<String, Object?> json, String key) {
  final value = _field(json, key);
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串');
  }
  return value;
}
