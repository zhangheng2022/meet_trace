import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class AppFileLayout {
  AppFileLayout({required String rootPath})
    : rootPath = p.normalize(p.absolute(rootPath));

  final String rootPath;

  static Future<AppFileLayout> forApplication() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return AppFileLayout(rootPath: p.join(supportDirectory.path, 'meetily'));
  }

  String get databaseDirectory => p.join(rootPath, 'database');
  String get databasePath => p.join(databaseDirectory, 'meetily.db');
  String get meetingsRoot => p.join(rootPath, 'meetings');
  String get modelsRoot => p.join(rootPath, 'models');
  String get modelTempRoot => p.join(modelsRoot, '.tmp');

  String meetingDirectory(String meetingId) {
    return p.join(meetingsRoot, _safeSegment(meetingId, 'meetingId'));
  }

  String meetingAudioDirectory(String meetingId) {
    return p.join(meetingDirectory(meetingId), 'audio');
  }

  String meetingAudioTempPath(String meetingId) {
    return p.join(meetingAudioDirectory(meetingId), 'recording.pcm.tmp');
  }

  String meetingAudioPath(String meetingId) {
    return p.join(meetingAudioDirectory(meetingId), 'fact.pcm');
  }

  String modelTempDirectory(String modelId, String version) {
    return p.join(
      modelTempRoot,
      _safeSegment(modelId, 'modelId'),
      _safeSegment(version, 'version'),
    );
  }

  String modelVersionDirectory(String modelId, String version) {
    return p.join(
      modelsRoot,
      _safeSegment(modelId, 'modelId'),
      _safeSegment(version, 'version'),
    );
  }

  Future<void> createBaseDirectories() async {
    for (final path in [
      databaseDirectory,
      meetingsRoot,
      modelsRoot,
      modelTempRoot,
    ]) {
      await Directory(path).create(recursive: true);
    }
  }
}

String _safeSegment(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed == '.' ||
      trimmed == '..' ||
      trimmed.contains('/') ||
      trimmed.contains(r'\') ||
      trimmed.contains('\u0000')) {
    throw ArgumentError.value(value, name, '不是安全的路径片段');
  }
  return trimmed;
}
