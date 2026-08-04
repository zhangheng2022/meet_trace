import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 单模型基线已收敛：会议只保存本场锁定模型，不再保留"请求模型"与
/// "回退原因"两个遗留概念。该守卫阻止遗留列名以任何形式（DDL、mapper、
/// 原始 SQL）回到 lib/。
void main() {
  const legacyColumns = ['requested_model_id', 'model_fallback_reason'];

  test('lib 源码不得重新引入遗留模型选择列', () {
    final violations = _legacyColumnViolations('lib', legacyColumns);

    expect(
      violations,
      isEmpty,
      reason:
          '单模型基线已删除遗留列，旧数据由数据代门全清：'
          '\n${violations.join('\n')}',
    );
  });

  test('lib 源码不得重新引入 AI 总结能力或存储结构', () {
    final violations = _legacyColumnViolations('lib', const ['summary']);

    expect(
      violations,
      isEmpty,
      reason:
          'Alpha 已完整移除 AI 总结；Port、Use Case、任务、UI 和表结构都不得恢复：'
          '\n${violations.join('\n')}',
    );
  });

  test('meetings 建表语句不包含遗留列', () {
    final schema = File(
      'lib/data/services/storage/app_database.dart',
    ).readAsStringSync();
    final meetingsDdl = RegExp(
      r"""CREATE TABLE meetings \(([\s\S]*?)\)\s*'''""",
    ).firstMatch(schema);

    expect(meetingsDdl, isNotNull, reason: '未找到 meetings 建表语句');
    for (final column in legacyColumns) {
      expect(
        meetingsDdl!.group(1),
        isNot(contains(column)),
        reason: 'meetings 表不得包含遗留列 $column',
      );
    }
  });

  test('遗留列守卫能捕获违规文件', () async {
    final root = await Directory.systemTemp.createTemp(
      'meettrace-legacy-column-',
    );
    addTearDown(() => root.delete(recursive: true));
    File(
      p.join(root.path, 'bad.dart'),
    ).writeAsStringSync("'requested_model_id': meeting.requestedModelId,\n");
    File(
      p.join(root.path, 'clean.dart'),
    ).writeAsStringSync("'recording_model_id': meeting.recordingModelId,\n");

    final violations = _legacyColumnViolations(root.path, legacyColumns);

    expect(violations, hasLength(1));
    expect(violations.single, contains('bad.dart'));
  });
}

List<String> _legacyColumnViolations(
  String rootPath,
  List<String> legacyColumns,
) {
  final violations = <String>[];
  final files = Directory(rootPath)
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  for (final file in files) {
    final content = file.readAsStringSync().toLowerCase();
    for (final column in legacyColumns) {
      if (content.contains(column.toLowerCase())) {
        violations.add('${file.path}: $column');
      }
    }
  }
  return violations;
}
