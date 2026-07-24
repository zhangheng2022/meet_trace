import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/storage/app_file_layout.dart';
import 'package:meetily_ai/data/services/storage/durable_file_committer.dart';

void main() {
  late Directory root;
  late AppFileLayout layout;
  late DurableFileCommitter committer;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meetily-storage-');
    layout = AppFileLayout(rootPath: root.path);
    committer = const DurableFileCommitter();
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('提交顺序保证数据库回调只看到已存在的最终文件', () async {
    final tempPath = layout.meetingAudioTempPath('meeting-1');
    final finalPath = layout.meetingAudioPath('meeting-1');
    await File(tempPath).parent.create(recursive: true);
    await File(tempPath).writeAsBytes([1, 2, 3], flush: true);
    var referencedPath = '';

    await committer.commit(
      tempPath: tempPath,
      finalPath: finalPath,
      persistReference: (path) async {
        expect(await File(path).exists(), true);
        referencedPath = path;
      },
    );

    expect(referencedPath, finalPath);
    expect(await File(finalPath).readAsBytes(), [1, 2, 3]);
    expect(await File(tempPath).exists(), false);
  });

  test('临时文件缺失时不会执行数据库引用回调', () async {
    var callbackCalled = false;

    await expectLater(
      committer.commit(
        tempPath: layout.meetingAudioTempPath('meeting-1'),
        finalPath: layout.meetingAudioPath('meeting-1'),
        persistReference: (_) async {
          callbackCalled = true;
        },
      ),
      throwsA(isA<DurableFileCommitException>()),
    );

    expect(callbackCalled, false);
  });

  test('数据库回调失败时最终文件保留为可恢复孤儿且不会伪造引用', () async {
    final tempPath = layout.meetingAudioTempPath('meeting-1');
    final finalPath = layout.meetingAudioPath('meeting-1');
    await File(tempPath).parent.create(recursive: true);
    await File(tempPath).writeAsBytes([1], flush: true);
    var referencePersisted = false;

    await expectLater(
      committer.commit(
        tempPath: tempPath,
        finalPath: finalPath,
        persistReference: (_) async {
          throw StateError('database failed');
        },
      ),
      throwsStateError,
    );

    expect(referencePersisted, false);
    expect(await File(finalPath).exists(), true);
  });

  test('文件布局拒绝路径穿越 ID', () {
    expect(() => layout.meetingDirectory('../other'), throwsArgumentError);
  });
}
