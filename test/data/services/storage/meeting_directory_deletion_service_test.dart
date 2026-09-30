import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/pcm_audio_playback_service.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/storage/meeting_directory_deletion_service.dart';

void main() {
  late Directory temporary;
  late AppFileLayout layout;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('meettrace-delete-');
    layout = AppFileLayout(rootPath: temporary.path);
    await layout.createBaseDirectories();
  });

  tearDown(() async {
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test('暂存后回滚会完整恢复会议目录', () async {
    final fact = File(layout.meetingAudioPath('meeting-1'));
    await fact.parent.create(recursive: true);
    await fact.writeAsBytes([1, 2, 3]);
    final service = MeetingDirectoryDeletionService(
      layout: layout,
      now: () => DateTime.utc(2026),
    );

    final staged = await service.stage('meeting-1');
    expect(await fact.exists(), isFalse);

    await staged.rollback();

    expect(await fact.readAsBytes(), [1, 2, 3]);
  });

  test('提交后清除会议目录且不影响其他会议', () async {
    final target = File(layout.meetingAudioPath('meeting-1'));
    final retained = File(layout.meetingAudioPath('meeting-2'));
    await target.parent.create(recursive: true);
    await retained.parent.create(recursive: true);
    await target.writeAsBytes([1]);
    await retained.writeAsBytes([2]);
    final service = MeetingDirectoryDeletionService(layout: layout);

    final staged = await service.stage('meeting-1');
    await staged.commit();

    expect(
      await Directory(layout.meetingDirectory('meeting-1')).exists(),
      isFalse,
    );
    expect(await retained.readAsBytes(), [2]);
  });

  test('播放后进程终止且未 dispose，重新启动后直接删除仍清除缓存', () async {
    final fact = File(layout.meetingAudioPath('meeting-1'));
    await fact.parent.create(recursive: true);
    await fact.writeAsBytes(Uint8List(32000));
    final retained = File(layout.meetingAudioPath('meeting-2'));
    await retained.parent.create(recursive: true);
    await retained.writeAsBytes([1, 2]);
    final output = _PlaybackOutput();
    final playback = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: 'meeting-1',
    );
    addTearDown(playback.dispose);
    await playback.play(audioPath: fact.path, startMs: 0, endMs: 1000);
    final preview = File(output.playedPath!);
    expect(await preview.exists(), isTrue);

    // No stop/dispose is called before deletion, as when the process is killed.
    final restartedLayout = AppFileLayout(rootPath: temporary.path);
    final deletion = MeetingDirectoryDeletionService(layout: restartedLayout);
    final staged = await deletion.stage('meeting-1');
    await staged.commit();

    expect(await preview.exists(), isFalse);
    expect(
      await Directory(restartedLayout.meetingDirectory('meeting-1')).exists(),
      isFalse,
    );
    expect(await retained.readAsBytes(), [1, 2]);
    expect(
      await Directory(restartedLayout.meetingsRoot)
          .list(recursive: true)
          .where((entry) => entry.path.endsWith('.wav'))
          .toList(),
      isEmpty,
    );
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
