import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/recording_checkpoint_store.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';

void main() {
  late Directory root;
  late AppFileLayout layout;
  late JsonRecordingCheckpointStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-checkpoint-');
    layout = AppFileLayout(rootPath: root.path);
    store = JsonRecordingCheckpointStore(layout);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('checkpoint 可无损往返并优先恢复完整的新一代文件', () async {
    final old = RecordingCheckpoint(
      meetingId: 'meeting-1',
      state: RecordingCheckpointState.recording,
      persistedBytes: 3200,
      updatedAt: DateTime.utc(2026, 7, 24, 8),
    );
    final latest = RecordingCheckpoint(
      meetingId: 'meeting-1',
      state: RecordingCheckpointState.paused,
      persistedBytes: 6400,
      updatedAt: DateTime.utc(2026, 7, 24, 8, 1),
    );
    await store.save(old);
    await store.save(latest);

    expect(await store.load('meeting-1'), latest);

    final finalFile = File(layout.meetingAudioCheckpointPath('meeting-1'));
    final previousFile = File(
      layout.meetingAudioCheckpointPreviousPath('meeting-1'),
    );
    await finalFile.rename(previousFile.path);

    expect(await store.load('meeting-1'), latest);
  });

  test('拒绝与 PCM16 样本边界不对齐的 checkpoint', () {
    expect(
      () => RecordingCheckpoint(
        meetingId: 'meeting-1',
        state: RecordingCheckpointState.recording,
        persistedBytes: 3,
        updatedAt: DateTime.utc(2026, 7, 24),
      ),
      throwsArgumentError,
    );
  });
}
