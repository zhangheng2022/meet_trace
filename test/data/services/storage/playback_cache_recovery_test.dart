import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_meeting_repository.dart';
import 'package:meettrace/data/services/audio/pcm_audio_playback_service.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/storage/startup_recovery_service.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('未 dispose 的播放缓存与旧版完整 WAV 在重启恢复时清除且事实 PCM 不变', () async {
    final root = await Directory.systemTemp.createTemp(
      'meettrace-playback-recovery-',
    );
    addTearDown(() => root.delete(recursive: true));
    final layout = AppFileLayout(rootPath: root.path);
    final database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: layout.databasePath,
    );
    addTearDown(database.close);
    final now = DateTime.utc(2026, 9, 30);
    const meetingId = 'meeting-1';
    final pcm = Uint8List.fromList(
      List<int>.generate(32000, (index) => index % 251),
    );
    final fact = File(layout.meetingAudioPath(meetingId));
    await fact.parent.create(recursive: true);
    await fact.writeAsBytes(pcm, flush: true);
    await SqfliteMeetingRepository(database).save(
      Meeting(
        id: meetingId,
        title: '会议',
        createdAt: now,
        status: MeetingState.completed,
        audioPath: fact.path,
        audioDurationMs: 1000,
        recordingModelId: 'sensevoice',
        recordingModelVersion: '1',
      ),
    );
    final output = _PlaybackOutput();
    final playback = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: meetingId,
    );
    addTearDown(playback.dispose);
    await playback.play(audioPath: fact.path, startMs: 0, endMs: 1000);
    final preview = File(output.playedPath!);
    expect((await preview.readAsBytes()).sublist(44), pcm);
    final legacyPreview = await preview.copy(
      '${layout.rootPath}${Platform.pathSeparator}meettrace-audio-preview.wav',
    );

    // 模拟进程终止：不调用 stop/dispose，重建持久化入口执行启动恢复。
    // 此回归验证文件生命周期，不替代真机进程终止与原生播放器测试。
    await database.close();
    final restartedLayout = AppFileLayout(rootPath: root.path);
    final restartedDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: restartedLayout.databasePath,
    );
    addTearDown(restartedDatabase.close);
    final errors = <String>[];
    final recovery = StartupRecoveryService(
      database: restartedDatabase,
      layout: restartedLayout,
      reportError: (step, _, _) => errors.add(step),
    );

    final report = await recovery.recover(now: now);

    expect(errors, isEmpty);
    expect(report.removedPlaybackTempDirectories, 2);
    expect(await preview.exists(), isFalse);
    expect(await legacyPreview.exists(), isFalse);
    expect(
      await Directory(restartedLayout.meetingPlaybackTempDirectory(meetingId))
          .exists(),
      isFalse,
    );
    expect(await fact.readAsBytes(), pcm);
    final retained = await SqfliteMeetingRepository(restartedDatabase)
        .getById(meetingId);
    expect(retained?.audioPath, fact.path);
    expect(retained?.status, MeetingState.completed);
    expect((await recovery.recover(now: now)).totalChanges, 0);
  });
}

final class _PlaybackOutput implements DeviceAudioOutput {
  String? playedPath;

  @override
  Stream<String> get onCompleted => const Stream.empty();

  @override
  Future<void> playDeviceFile(String path) async {
    playedPath = path;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
