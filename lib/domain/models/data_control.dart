import 'dart:convert';

final class LocalStorageUsage {
  const LocalStorageUsage({
    required this.totalBytes,
    required this.meetingBytes,
    required this.modelBytes,
    required this.databaseBytes,
    required this.freeBytes,
  });

  final int totalBytes;
  final int meetingBytes;
  final int modelBytes;
  final int databaseBytes;
  final int freeBytes;
}

final class DiagnosticReport {
  DiagnosticReport(Map<String, Object?> fields)
    : fields = Map.unmodifiable(fields);

  final Map<String, Object?> fields;

  String toJsonText() => const JsonEncoder.withIndent('  ').convert(fields);
}
