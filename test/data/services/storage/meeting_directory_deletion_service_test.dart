import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/storage/app_file_layout.dart';
import 'package:meetily_ai/data/services/storage/meeting_directory_deletion_service.dart';

void main() {
  late Directory temporary;
  late AppFileLayout layout;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('meetily-delete-');
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
}
