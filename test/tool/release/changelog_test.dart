import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File changelog;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('meettrace-changelog-');
    changelog = File('${directory.path}/CHANGELOG.md');
  });

  tearDown(() => directory.delete(recursive: true));

  Future<ProcessResult> run([List<String> arguments = const []]) => Process.run(
    Platform.isWindows ? 'python' : 'python3',
    ['tool/release/changelog.py', '--changelog', changelog.path, ...arguments],
    environment: const {'PYTHONUTF8': '1'},
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  test('按 release ID 提取对应版本并兼容 CRLF', () async {
    await changelog.writeAsString(
      '# 更新日志\r\n\r\n'
      '## [Unreleased]\r\n\r\n'
      '- 新增：待发布。\r\n\r\n'
      '## [1.0.0-alpha.13] - 2026-09-02\r\n\r\n'
      '- 新增：提供更新日志。\r\n'
      '- 修复：恢复发布时保留说明。\r\n\r\n'
      '## [1.0.0-alpha.12] - 2026-09-01\r\n\r\n'
      '- 变更：更新诊断配置。\r\n',
    );

    final result = await run(['--release-id', 'v1.0.0-alpha.13']);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      result.stdout.toString().replaceAll('\r\n', '\n').trim(),
      '- 新增：提供更新日志。\n- 修复：恢复发布时保留说明。',
    );
  });

  test('拒绝缺失、重复、空内容和无效 release ID', () async {
    Future<void> expectFailure(
      String contents,
      List<String> arguments,
      String stderr,
    ) async {
      await changelog.writeAsString(contents);
      final result = await run(arguments);
      expect(result.exitCode, 1);
      expect(result.stderr, contains(stderr));
    }

    const validEntry = '## [1.0.0-alpha.13] - 2026-09-02\n\n- 新增：内容。\n';
    await expectFailure(
      '# 更新日志\n\n$validEntry',
      const [],
      '必须包含一个 ## [Unreleased]',
    );
    await expectFailure(
      '# 更新日志\n\n## [Unreleased]\n\n$validEntry\n$validEntry',
      const [],
      '版本 1.0.0-alpha.13 重复',
    );
    await expectFailure(
      '# 更新日志\n\n## [Unreleased]\n\n'
          '## [1.0.0-alpha.13] - 2026-09-02\n\n内部调整。\n',
      const [],
      '没有有效的用户可见条目',
    );
    await expectFailure(
      '# 更新日志\n\n## [Unreleased]\n\n'
          '## [1.0.0-alpha.13] - 2026-02-30\n\n- 新增：内容。\n',
      const [],
      '日期无效',
    );
    await changelog.writeAsString('# 更新日志\n\n## [Unreleased]\n\n$validEntry');
    for (final releaseId in ['1.0', '1.0.0-alpha.13']) {
      final result = await run(['--release-id', releaseId]);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('release ID 必须形如'));
    }
    final missing = await run(['--release-id', 'v1.0.0-alpha.14']);
    expect(missing.exitCode, 1);
    expect(missing.stderr, contains('缺少版本 1.0.0-alpha.14'));

    final draftWithoutRelease = await run(['--draft-body', changelog.path]);
    expect(draftWithoutRelease.exitCode, 1);
    expect(draftWithoutRelease.stderr, contains('--draft-body 必须与'));
    final outputWithoutRelease = await run(['--output', changelog.path]);
    expect(outputWithoutRelease.exitCode, 1);
    expect(outputWithoutRelease.stderr, contains('--output 必须与'));
  });

  test('拒绝不可读取路径和所有无效结构边界', () async {
    Future<void> expectFailure(String contents, String stderr) async {
      await changelog.writeAsString(contents);
      final result = await run();
      expect(result.exitCode, 1);
      expect(result.stderr, contains(stderr));
    }

    await expectFailure(
      '# 更新日志\n\n'
          '## [1.0.0-alpha.13] - 2026-09-02\n\n- 新增：内容。\n\n'
          '## [Unreleased]\n',
      '## [Unreleased] 必须是第一个二级标题',
    );
    await expectFailure(
      '# 更新日志\n\n## [Unreleased]\n\n'
          '## [1.0.0-beta.1] - 2026-09-02\n\n- 新增：内容。\n',
      '版本标题无效',
    );
    await expectFailure(
      '# 更新日志\n\n## [Unreleased]\n\n## [Unreleased]\n',
      '必须包含一个 ## [Unreleased]',
    );
    await expectFailure(
      '# 更新日志\n\n## [Unreleased]\n\n'
          '<!-- meettrace-public-notes:start -->\n',
      '包含保留的发布说明标记',
    );

    final missing = await run(['--changelog', '${directory.path}/missing.md']);
    expect(missing.exitCode, 1);
    expect(missing.stderr, contains('更新日志校验失败'));
  });

  test('将版本正文写入指定文件', () async {
    final output = File('${directory.path}/notes.md');
    await changelog.writeAsString(
      '# 更新日志\n\n## [Unreleased]\n\n'
      '## [1.0.0-alpha.13] - 2026-09-02\n\n'
      '- 安全：更新发布说明。\n',
    );

    final result = await run([
      '--release-id',
      'v1.0.0-alpha.13',
      '--output',
      output.path,
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(await output.readAsString(), '- 安全：更新发布说明。\n');

    final invalidOutput = await run([
      '--release-id',
      'v1.0.0-alpha.13',
      '--output',
      '${directory.path}/missing/notes.md',
    ]);
    expect(invalidOutput.exitCode, 1);
    expect(invalidOutput.stderr, contains('更新日志校验失败'));
  });

  test('恢复发布只接受与候选日志匹配的 Draft 说明', () async {
    final draft = File('${directory.path}/draft.md');
    final output = File('${directory.path}/notes.md');
    await changelog.writeAsString(
      '# 更新日志\n\n## [Unreleased]\n\n'
      '## [1.0.0-alpha.13] - 2026-09-02\n\n'
      '- 新增：提供更新日志。\n',
    );
    await draft.writeAsString(
      '候选说明\n\n<!-- meettrace-public-notes:start -->\n'
      '## 本版变化\n\n- 新增：提供更新日志。\n\n'
      '## 补充说明\n\n请优先验证录音。\n'
      '<!-- meettrace-public-notes:end -->\n',
    );

    final result = await run([
      '--release-id',
      'v1.0.0-alpha.13',
      '--draft-body',
      draft.path,
      '--output',
      output.path,
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      await output.readAsString(),
      '## 本版变化\n\n- 新增：提供更新日志。\n\n'
      '## 补充说明\n\n请优先验证录音。\n',
    );

    await draft.writeAsString(
      '<!-- meettrace-public-notes:start -->\r\n'
      '## 本版变化\r\n\r\n- 新增：提供更新日志。\r\n'
      '<!-- meettrace-public-notes:end -->\r\n',
    );
    final exact = await run([
      '--release-id',
      'v1.0.0-alpha.13',
      '--draft-body',
      draft.path,
    ]);
    expect(exact.exitCode, 0);
    expect(
      exact.stdout.toString().replaceAll('\r\n', '\n').trim(),
      '## 本版变化\n\n- 新增：提供更新日志。',
    );

    await draft.writeAsString(
      '<!-- meettrace-public-notes:start -->\n'
      '## 本版变化\n\n- 新增：被篡改。\n'
      '<!-- meettrace-public-notes:end -->\n',
    );
    final tampered = await run([
      '--release-id',
      'v1.0.0-alpha.13',
      '--draft-body',
      draft.path,
    ]);
    expect(tampered.exitCode, 1);
    expect(tampered.stderr, contains('Draft release notes differ'));

    await draft.writeAsString(
      '<!-- meettrace-public-notes:end -->\n'
      '<!-- meettrace-public-notes:start -->\n',
    );
    final reversed = await run([
      '--release-id',
      'v1.0.0-alpha.13',
      '--draft-body',
      draft.path,
    ]);
    expect(reversed.exitCode, 1);
    expect(reversed.stderr, contains('out of order'));
  });
}
