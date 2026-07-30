import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('domain 不反向导入 data 层', () {
    final violations = _importsUnder('lib/domain').where(
      (entry) =>
          entry.uri.startsWith('package:meettrace/data/') ||
          entry.uri.contains('/data/') ||
          entry.uri.startsWith('../data/') ||
          entry.uri.startsWith('../../data/'),
    );

    expect(
      violations,
      isEmpty,
      reason:
          '领域模型、端口和用例只能依赖 domain 内部抽象：'
          '\n${violations.join('\n')}',
    );
  });

  test('ui 不直接导入 data Repository 或 Service', () {
    final violations = _importsUnder('lib/ui').where(
      (entry) =>
          entry.uri.contains('data/repositories/') ||
          entry.uri.contains('data/services/'),
    );

    expect(
      violations,
      isEmpty,
      reason:
          'View 与 ViewModel 应依赖 domain port/use case：'
          '\n${violations.join('\n')}',
    );
  });

  test('具体 ASR Engine 不泄漏到 ui', () {
    const concreteTypes = [
      'WhisperBaseStandardAsrEngine',
      'WhisperSmallAdvancedAsrEngine',
      'WhisperAsrEngine',
    ];
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/ui')) {
      final content = file.readAsStringSync();
      for (final type in concreteTypes) {
        if (content.contains(type)) {
          violations.add('${file.path}: $type');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'UI 只能依赖统一 AsrEngine 端口：\n${violations.join('\n')}',
    );
  });
}

Iterable<_ImportEntry> _importsUnder(String path) sync* {
  final pattern = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true);
  for (final file in _dartFilesUnder(path)) {
    final content = file.readAsStringSync();
    for (final match in pattern.allMatches(content)) {
      yield _ImportEntry(file.path, match.group(1)!);
    }
  }
}

Iterable<File> _dartFilesUnder(String path) {
  return Directory(path)
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

final class _ImportEntry {
  const _ImportEntry(this.file, this.uri);

  final String file;
  final String uri;

  @override
  String toString() => '$file: $uri';
}
