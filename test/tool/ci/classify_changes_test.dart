import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<Map<String, Object?>> _classify(List<String> paths) async {
  final executable = Platform.isWindows ? 'python' : 'python3';
  final result = await Process.run(executable, [
    'tool/ci/classify_changes.py',
    for (final path in paths) ...['--path', path],
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return (jsonDecode(result.stdout.toString()) as Map).cast<String, Object?>();
}

void main() {
  test('文档与 Graphify 输出只运行稳定 Gate', () async {
    expect(
      await _classify(['docs/quality/README.md', 'graphify-out/graph.json']),
      {'core': false, 'android': false, 'ios': false},
    );
  });

  test('Android 与 iOS 原生变更只触发对应平台', () async {
    expect(await _classify(['android/settings.gradle.kts']), {
      'core': true,
      'android': true,
      'ios': false,
    });
    expect(await _classify(['ios/Runner.xcodeproj/project.pbxproj']), {
      'core': true,
      'android': false,
      'ios': true,
    });
  });

  test('跨平台源码、依赖和工作流变更执行完整 CI', () async {
    for (final path in [
      'lib/app/application.dart',
      'pubspec.lock',
      '.github/workflows/quality.yml',
    ]) {
      expect(await _classify([path]), {
        'core': true,
        'android': true,
        'ios': true,
      }, reason: path);
    }
  });

  test('单元测试只执行 Core，未知路径保守执行完整 CI', () async {
    expect(await _classify(['test/domain/models/meeting_test.dart']), {
      'core': true,
      'android': false,
      'ios': false,
    });
    expect(await _classify(['new_platform/source.custom']), {
      'core': true,
      'android': true,
      'ios': true,
    });
  });

  test('Graphify 执行代码与版本标记必须运行 Core', () async {
    final executable = await _classify([
      '.agents/skills/graphify/ingest.py',
      '.claude/skills/graphify/.graphify_version',
    ]);
    final references = await _classify([
      '.agents/skills/graphify/references/query.md',
      '.claude/skills/graphify/skill.md',
    ]);

    expect(executable, {'core': true, 'android': false, 'ios': false});
    expect(references, {'core': false, 'android': false, 'ios': false});
  });
}
