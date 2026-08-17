enum AppUpdateCandidateStatus { publicApproved, withdrawn }

enum AppUpdateWorkload { idle, recording, finalProcessing }

enum AppUpdateDecisionKind {
  noUpdate,
  readyToInstall,
  deferred,
  dataResetWarningRequired,
  checkFailed,
  downloadFailed,
  installHandoffFailed,
  installHandedOff,
}

final class InstalledAppVersion {
  InstalledAppVersion({
    required this.versionName,
    required this.buildNumber,
    required this.dataGeneration,
  }) {
    _parseAppVersion(versionName);
    if (buildNumber <= 0 || dataGeneration <= 0) {
      throw ArgumentError('构建号和数据代必须大于 0');
    }
  }

  final String versionName;
  final int buildNumber;
  final int dataGeneration;
}

/// 已由 data adapter 完成 Manifest 签名与平台资产校验的更新候选。
final class AppUpdateCandidate {
  AppUpdateCandidate({
    required this.releaseId,
    required this.versionName,
    required this.buildNumber,
    required this.dataGeneration,
    required this.status,
    required this.sourceCommitSha,
    required this.artifactId,
    required this.approvedAt,
  }) {
    if (releaseId.trim().isEmpty ||
        versionName.trim().isEmpty ||
        artifactId.trim().isEmpty) {
      throw ArgumentError('发布标识、版本和平台资产标识不能为空');
    }
    if (buildNumber <= 0 || dataGeneration <= 0) {
      throw ArgumentError('构建号和数据代必须大于 0');
    }
    _parseAppVersion(versionName);
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sourceCommitSha)) {
      throw ArgumentError.value(
        sourceCommitSha,
        'sourceCommitSha',
        '必须是小写 40 位 Git commit SHA',
      );
    }
    if (!approvedAt.isUtc) {
      throw ArgumentError.value(approvedAt, 'approvedAt', '必须使用 UTC');
    }
  }

  final String releaseId;
  final String versionName;
  final int buildNumber;
  final int dataGeneration;
  final AppUpdateCandidateStatus status;
  final String sourceCommitSha;

  /// 平台 adapter 内部解析的不可变资产标识；Domain 不感知 URL 或安装包类型。
  final String artifactId;
  final DateTime approvedAt;

  bool isNewerThan(InstalledAppVersion installed) =>
      buildNumber > installed.buildNumber &&
      _compareAppVersions(versionName, installed.versionName) >= 0;
}

final class AppUpdateDecision {
  const AppUpdateDecision({required this.kind, this.candidate});

  final AppUpdateDecisionKind kind;
  final AppUpdateCandidate? candidate;
}

List<Object> _parseAppVersion(String value) {
  final match = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  ).firstMatch(value);
  if (match == null) {
    throw ArgumentError.value(value, 'versionName', '必须是有效 SemVer');
  }
  return <Object>[
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    if (match.group(4) case final String prerelease) prerelease.split('.'),
  ];
}

int _compareAppVersions(String left, String right) {
  final leftParts = _parseAppVersion(left);
  final rightParts = _parseAppVersion(right);
  for (var index = 0; index < 3; index++) {
    final compared = (leftParts[index] as int).compareTo(
      rightParts[index] as int,
    );
    if (compared != 0) {
      return compared;
    }
  }
  final leftPre = leftParts.length == 4 ? leftParts[3] as List<String> : null;
  final rightPre = rightParts.length == 4
      ? rightParts[3] as List<String>
      : null;
  if (leftPre == null || rightPre == null) {
    return leftPre == null ? (rightPre == null ? 0 : 1) : -1;
  }
  final sharedLength = leftPre.length < rightPre.length
      ? leftPre.length
      : rightPre.length;
  for (var index = 0; index < sharedLength; index++) {
    final leftNumber = int.tryParse(leftPre[index]);
    final rightNumber = int.tryParse(rightPre[index]);
    final compared = switch ((leftNumber, rightNumber)) {
      (final int left, final int right) => left.compareTo(right),
      (final int _, null) => -1,
      (null, final int _) => 1,
      (null, null) => leftPre[index].compareTo(rightPre[index]),
    };
    if (compared != 0) {
      return compared;
    }
  }
  return leftPre.length.compareTo(rightPre.length);
}
