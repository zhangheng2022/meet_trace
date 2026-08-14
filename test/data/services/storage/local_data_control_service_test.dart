import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/storage/device_free_space_service.dart';
import 'package:meettrace/data/services/storage/local_data_control_service.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/workflow_states.dart';

void main() {
  late Directory temporary;
  late AppFileLayout layout;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('meettrace-diagnostics-');
    layout = AppFileLayout(rootPath: temporary.path);
    await layout.createBaseDirectories();
    await File(layout.meetingAudioPath('secret-id')).parent
        .create(recursive: true);
    await File(layout.meetingAudioPath('secret-id'))
        .writeAsBytes(List.filled(32, 1));
    await File(layout.databasePath).writeAsBytes(List.filled(8, 2));
  });

  tearDown(() async {
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test('诊断白名单不泄露会议标题、音频路径或内容', () async {
    final meeting = Meeting(
      id: 'secret-id',
      title: '绝密董事会',
      createdAt: DateTime.utc(2026),
      status: MeetingState.failed,
      audioPath: layout.meetingAudioPath('secret-id'),
      audioDurationMs: 1000,
      recordingModelId: 'standard',
      recordingModelVersion: 'v1',
      lastErrorCode: 'asr.failed',
    );
    final service = LocalDataControlService(
      layout: layout,
      meetings: _Meetings([meeting]),
      installations: _Installations([
        ModelInstallation(
          modelId: 'advanced',
          version: 'v2',
          installationType: AsrInstallationType.downloadable,
          state: ModelInstallationState.failed,
          bytes: 12,
          lastErrorCode: 'model.hash',
        ),
      ]),
      freeSpace: DeviceFreeSpaceService(reader: () async => 10),
      now: () => DateTime.utc(2026, 1, 2),
    );

    final text = (await service.buildDiagnostics()).toJsonText();

    expect(text, contains('"asr.failed"'));
    expect(text, contains('"model.hash"'));
    expect(text, contains('"meetingBytes": 32'));
    expect(text, isNot(contains('绝密董事会')));
    expect(text, isNot(contains('secret-id')));
    expect(text, isNot(contains('fact.pcm')));
    expect(text, isNot(contains(layout.rootPath)));
  });
}

final class _Meetings implements MeetingRepository {
  _Meetings(this.values);

  final List<Meeting> values;

  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<Meeting?> getById(String meetingId) async => null;

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Future<Meeting> updateTitle({
    required String meetingId,
    required String title,
  }) async =>
      values.singleWhere((meeting) => meeting.id == meetingId).rename(title);

  @override
  Stream<List<Meeting>> watchAll() => Stream.value(values);
}

final class _Installations implements ModelInstallationRepository {
  _Installations(this.values);

  final List<ModelInstallation> values;

  @override
  Future<ModelInstallation?> get({
    required String modelId,
    required String version,
  }) async => null;

  @override
  Future<void> save(ModelInstallation installation) async {}

  @override
  Stream<List<ModelInstallation>> watchAll() => Stream.value(values);
}
