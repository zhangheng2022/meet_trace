import 'dart:convert';

import 'microsoft_store_submission.dart';

Map<String, Object?> classifyMicrosoftStoreSubmission(
  String source, {
  required String expectedArtifactName,
  required String expectedPackageVersion,
  required bool production,
}) {
  if (utf8.encode(source).length >
      microsoftStoreSubmissionMaximumResponseBytes) {
    throw const FormatException('Microsoft Store submission 响应超过 2 MiB 上限');
  }
  final submission = _object(jsonDecode(source), 'submission');
  final status = _requiredText(submission, 'Status');
  if (!RegExp(r'^[A-Za-z0-9_. -]{1,128}$').hasMatch(status)) {
    throw const FormatException('Store Status 包含不安全字符');
  }
  final packagesValue = _field(submission, 'ApplicationPackages');
  if (packagesValue is! List<Object?>) {
    throw const FormatException('ApplicationPackages 必须是数组');
  }
  final matches = packagesValue.where((value) {
    final package = _object(value, 'ApplicationPackages[]');
    return _requiredText(package, 'FileName') == expectedArtifactName &&
        _requiredText(package, 'Version') == expectedPackageVersion;
  }).length;
  final exactPackageSeen = matches > 0;
  var present = matches == 1 && packagesValue.length == 1;
  final normalizedStatus = status.toLowerCase();
  var ready = present && normalizedStatus == 'published';
  if (production && ready) {
    ready = _requiredText(submission, 'Visibility').toLowerCase() == 'public';
  }

  const pendingStatuses = <String>{
    'pendingcommit',
    'commitstarted',
    'pendingpublication',
    'publishing',
    'preprocessing',
    'certification',
    'release',
  };
  final blocked = switch ((ready, present, packagesValue.isNotEmpty)) {
    (true, _, _) => false,
    (false, _, false) when production && normalizedStatus == 'notsubmitted' =>
      false,
    (false, true, _) => !pendingStatuses.contains(normalizedStatus),
    (false, false, true) =>
      !(production && normalizedStatus == 'published' && !exactPackageSeen),
    (false, false, false) when pendingStatuses.contains(normalizedStatus) =>
      false,
    _ => true,
  };
  if (production && pendingStatuses.contains(normalizedStatus)) {
    present = true;
  }

  return <String, Object?>{
    'ready': ready,
    'present': present,
    'blocked': blocked,
    'status': status,
  };
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
