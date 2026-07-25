import 'dart:io';

import '../../../domain/models/data_control.dart';
import '../../repositories/repository_contracts.dart';
import 'app_file_layout.dart';
import 'device_free_space_service.dart';

final class LocalDataControlService {
  const LocalDataControlService({
    required this.layout,
    required this.meetings,
    required this.installations,
    this.freeSpace = const DeviceFreeSpaceService(),
    this.now = DateTime.now,
  });

  final AppFileLayout layout;
  final MeetingRepository meetings;
  final ModelInstallationRepository installations;
  final DeviceFreeSpaceService freeSpace;
  final DateTime Function() now;

  Future<LocalStorageUsage> measure() async {
    final meetingBytes = await _sizeOf(Directory(layout.meetingsRoot));
    final modelBytes = await _sizeOf(Directory(layout.modelsRoot));
    final databaseBytes = await _sizeOf(File(layout.databasePath));
    final totalBytes = await _sizeOf(Directory(layout.rootPath));
    return LocalStorageUsage(
      totalBytes: totalBytes,
      meetingBytes: meetingBytes,
      modelBytes: modelBytes,
      databaseBytes: databaseBytes,
      freeBytes: await freeSpace.getFreeBytes(),
    );
  }

  Future<DiagnosticReport> buildDiagnostics() async {
    final usage = await measure();
    final meetingRecords = await meetings.watchAll().first;
    final modelRecords = await installations.watchAll().first;
    final meetingStates = <String, int>{};
    final meetingErrors = <String, int>{};
    for (final meeting in meetingRecords) {
      meetingStates.update(
        meeting.status.name,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      final code = meeting.lastErrorCode;
      if (code != null) {
        meetingErrors.update(code, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return DiagnosticReport({
      'schemaVersion': 1,
      'generatedAt': now().toUtc().toIso8601String(),
      'storage': {
        'totalBytes': usage.totalBytes,
        'meetingBytes': usage.meetingBytes,
        'modelBytes': usage.modelBytes,
        'databaseBytes': usage.databaseBytes,
        'freeBytes': usage.freeBytes,
      },
      'meetings': {
        'count': meetingRecords.length,
        'states': meetingStates,
        'errorCodes': meetingErrors,
      },
      'models': [
        for (final model in modelRecords)
          {
            'modelId': model.modelId,
            'version': model.version,
            'state': model.state.name,
            'bytes': model.bytes,
            'errorCode': model.lastErrorCode,
          },
      ],
      'privacy': {
        'containsTranscript': false,
        'containsAudio': false,
        'containsMeetingTitle': false,
        'containsLocalPath': false,
      },
    });
  }
}

Future<int> _sizeOf(FileSystemEntity entity) async {
  if (entity is File) {
    return await entity.exists() ? await entity.length() : 0;
  }
  if (entity is! Directory || !await entity.exists()) {
    return 0;
  }
  var total = 0;
  await for (final child in entity.list(recursive: true, followLinks: false)) {
    if (child is File) {
      total += await child.length();
    }
  }
  return total;
}
