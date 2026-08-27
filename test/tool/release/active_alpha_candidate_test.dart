import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File releases;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'meettrace-active-alpha-',
    );
    releases = File('${directory.path}/releases.json');
  });

  tearDown(() => directory.delete(recursive: true));

  Future<ProcessResult> run(List<String> arguments) =>
      Process.run(Platform.isWindows ? 'python' : 'python3', [
        'tool/release/active_alpha_candidate.py',
        '--releases',
        releases.path,
        ...arguments,
      ]);

  test('选择最新公开版本之后创建的唯一最新 Draft', () async {
    await releases.writeAsString(
      jsonEncode([
        [
          _release(
            id: 5,
            tag: 'v1.0.0-alpha.5',
            createdAt: '2026-08-20T11:16:06Z',
            publishedAt: '2026-08-21T06:18:23Z',
          ),
          _release(
            id: 9,
            tag: 'v1.0.0-alpha.9',
            createdAt: '2026-08-25T09:48:39Z',
            draft: true,
          ),
          _release(
            id: 10,
            tag: 'v1.0.0-alpha.10',
            createdAt: '2026-08-26T07:22:06Z',
            draft: true,
          ),
        ],
      ]),
    );

    final result = await run(['--select']);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString().trim(), 'v1.0.0-alpha.10');
    expect((await run(['--require-selected', 'v1.0.0-alpha.10'])).exitCode, 0);
    expect((await run(['--require-selected', 'v1.0.0-alpha.9'])).exitCode, 1);
    expect((await run(['--ensure-empty'])).exitCode, 1);
  });

  test('最新 Draft 公开后忽略更早的遗留 Draft', () async {
    await releases.writeAsString(
      jsonEncode([
        _release(
          id: 9,
          tag: 'v1.0.0-alpha.9',
          createdAt: '2026-08-25T09:48:39Z',
          draft: true,
        ),
        _release(
          id: 10,
          tag: 'v1.0.0-alpha.10',
          createdAt: '2026-08-26T07:22:06Z',
          publishedAt: '2026-08-27T08:00:00Z',
        ),
      ]),
    );

    final result = await run(['--select']);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString().trim(), isEmpty);
    expect((await run(['--ensure-empty'])).exitCode, 0);
  });

  test('匹配的 Alpha 缺少时间戳时失败关闭', () async {
    await releases.writeAsString(
      jsonEncode([
        _release(id: 11, tag: 'v1.0.0-alpha.11', createdAt: null, draft: true),
      ]),
    );

    final result = await run(['--ensure-empty']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('timestamp is missing'));
  });
}

Map<String, Object?> _release({
  required int id,
  required String tag,
  required String? createdAt,
  bool draft = false,
  String? publishedAt,
}) => {
  'id': id,
  'tag_name': tag,
  'draft': draft,
  'prerelease': true,
  'created_at': createdAt,
  'published_at': publishedAt,
};
