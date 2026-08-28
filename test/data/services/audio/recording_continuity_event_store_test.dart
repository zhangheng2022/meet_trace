import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/recording_continuity_event_store.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/domain/models/recording_continuity_event.dart';

void main() {
  late Directory root;
  late AppFileLayout layout;
  late JsonRecordingContinuityEventStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-continuity-');
    layout = AppFileLayout(rootPath: root.path);
    store = JsonRecordingContinuityEventStore(layout);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('追加并恢复同一设备中断区间的开始与结果', () async {
    final started = RecordingContinuityEvent(
      meetingId: 'meeting-1',
      incidentId: 'incident-1',
      kind: RecordingContinuityEventKind.interruptionStarted,
      at: DateTime.utc(2026, 8, 14, 8),
      persistedBytes: 32000,
      inputLabel: 'USB 麦克风',
    );
    final recovered = RecordingContinuityEvent(
      meetingId: 'meeting-1',
      incidentId: 'incident-1',
      kind: RecordingContinuityEventKind.switchedToSystemDefault,
      at: DateTime.utc(2026, 8, 14, 8, 0, 1),
      persistedBytes: 32000,
      inputLabel: '系统默认麦克风',
    );

    await store.append(started);
    await store.append(recovered);
    await store.append(recovered);

    expect(await store.read('meeting-1'), [started, recovered]);
    expect(
      await File(layout.meetingContinuityPath('meeting-1')).exists(),
      true,
    );
  });

  test('当前文件损坏时从上一代完整文件恢复', () async {
    final started = RecordingContinuityEvent(
      meetingId: 'meeting-2',
      incidentId: 'incident-2',
      kind: RecordingContinuityEventKind.interruptionStarted,
      at: DateTime.utc(2026, 8, 14, 9),
      persistedBytes: 0,
      inputLabel: '系统默认麦克风',
    );
    await store.append(started);
    await File(layout.meetingContinuityPath('meeting-2'))
        .rename(layout.meetingContinuityPreviousPath('meeting-2'));
    await File(layout.meetingContinuityPath('meeting-2'))
        .writeAsString('{broken');

    expect(await store.read('meeting-2'), [started]);
  });

  test('文件系统读取失败向上传播而不伪装成空事件', () async {
    final path = layout.meetingContinuityPath('meeting-3');
    await File(path).parent.create(recursive: true);
    await File(path).writeAsString('{}');
    final failingStore = JsonRecordingContinuityEventStore(
      layout,
      readFile: (_) => Future.error(const FileSystemException('read failed')),
    );

    await expectLater(
      failingStore.read('meeting-3'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
