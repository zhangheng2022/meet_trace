import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

  test('data 不反向导入 app 或 ui', () {
    final violations = _importsUnder('lib/data').where(
      (entry) =>
          entry.uri.startsWith('package:meettrace/app/') ||
          entry.uri.startsWith('package:meettrace/ui/') ||
          entry.uri.contains('/app/') ||
          entry.uri.contains('/ui/'),
    );

    expect(
      violations,
      isEmpty,
      reason: 'Data 实现不得依赖组合根或展示层：\n${violations.join('\n')}',
    );
  });

  test('domain 保持纯 Dart 且不依赖 Flutter 或 Forui', () {
    final violations = _importsUnder('lib/domain').where(
      (entry) =>
          entry.uri == 'package:flutter/foundation.dart' ||
          entry.uri.startsWith('package:flutter/') ||
          entry.uri.startsWith('package:forui/'),
    );

    expect(
      violations,
      isEmpty,
      reason: 'Domain 必须可在纯 Dart 环境运行：\n${violations.join('\n')}',
    );
  });

  test('旧 data facade 已删除且不得重新导入', () {
    const legacyPaths = [
      'lib/data/repositories/repository_contracts.dart',
      'lib/data/services/asr/asr_engine.dart',
      'lib/data/services/asr/asr_preview_session.dart',
      'lib/data/services/audio/evidence_playback_service.dart',
      'lib/data/services/audio/pcm_evidence_playback_service.dart',
      'lib/domain/ports/evidence_playback.dart',
      'lib/data/services/audio/recording_session_service.dart',
      'lib/data/services/asr/final_transcription_service.dart',
      'lib/data/services/diarization/speaker_diarization_coordinator.dart',
    ];
    final existing = legacyPaths.where((path) => File(path).existsSync());
    final violations = _importsUnder('lib').where(
      (entry) => legacyPaths.any(
        (path) => entry.uri.endsWith(path.substring('lib/'.length)),
      ),
    );

    expect(existing, isEmpty, reason: '旧 facade 文件不应恢复');
    expect(
      violations,
      isEmpty,
      reason: '内部代码应直接依赖 domain port/use case：\n${violations.join('\n')}',
    );
  });

  test('具体 ASR Engine 不泄漏到 ui', () {
    const concreteTypes = ['SherpaOnnxAsrEngine'];
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

  test('lib 本地 import 图不存在循环依赖', () {
    final cycles = _findImportCycles('lib');

    expect(
      cycles,
      isEmpty,
      reason:
          '业务代码不得形成 import 环：\n'
          '${cycles.map((cycle) => cycle.join(' -> ')).join('\n')}',
    );
  });

  test('功能代码不得用 part 制造假拆分', () {
    final pattern = RegExp(r'^\s*part(?:\s+of)?\s+', multiLine: true);
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/ui/features')) {
      final normalized = p.normalize(file.path);
      if (p.split(normalized).contains('previews')) {
        continue;
      }
      if (pattern.hasMatch(file.readAsStringSync())) {
        violations.add(normalized);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '功能实现应通过明确对象和 import 形成边界；part 仅允许用于预览夹具：\n'
          '${violations.join('\n')}',
    );
  });

  test('循环依赖守卫覆盖无 ./ 前缀的相对 import', () async {
    final root = await Directory.systemTemp.createTemp(
      'meettrace-import-cycle-',
    );
    addTearDown(() => root.delete(recursive: true));
    File(p.join(root.path, 'a.dart')).writeAsStringSync("import 'b.dart';\n");
    File(p.join(root.path, 'b.dart')).writeAsStringSync("import 'a.dart';\n");

    final cycles = _findImportCycles(root.path);

    expect(cycles, hasLength(1));
  });

  test('顶层组合根只编排子容器，不重新聚合 data 与 ui 依赖', () {
    final imports = _importsUnder('lib/app/meettrace_dependencies.dart')
        .map((entry) => entry.uri)
        .toList();
    final violations = imports.where(
      (uri) => uri.contains('/data/') || uri.contains('/ui/'),
    );

    expect(violations, isEmpty);
    expect(
      imports.length,
      lessThanOrEqualTo(5),
      reason: '顶层组合根应保持为 Storage、Runtime、Meeting、Update 子容器编排壳',
    );
  });
}

List<List<String>> _findImportCycles(String rootPath) {
  final projectRoot = p.normalize(p.absolute(Directory.current.path));
  final root = p.normalize(p.absolute(rootPath));
  final files = {
    for (final file in _dartFilesUnder(root))
      p.normalize(p.absolute(file.path)),
  };
  final graph = <String, Set<String>>{};
  for (final filePath in files) {
    final imports = _importsUnder(filePath)
        .map((entry) => _resolveLocalImport(projectRoot, filePath, entry.uri))
        .whereType<String>()
        .where(files.contains)
        .toSet();
    graph[filePath] = imports;
  }

  final state = <String, int>{};
  final stack = <String>[];
  final cycles = <List<String>>[];

  void visit(String node) {
    state[node] = 1;
    stack.add(node);
    for (final target in graph[node] ?? const <String>{}) {
      if (state[target] == null) {
        visit(target);
      } else if (state[target] == 1) {
        final start = stack.indexOf(target);
        cycles.add(
          [
            ...stack.sublist(start),
            target,
          ].map((path) => p.relative(path, from: projectRoot)).toList(),
        );
      }
    }
    stack.removeLast();
    state[node] = 2;
  }

  for (final file in files) {
    if (state[file] == null) {
      visit(file);
    }
  }
  return cycles;
}

String? _resolveLocalImport(String projectRoot, String sourcePath, String uri) {
  if (uri.startsWith('package:meettrace/')) {
    return p.normalize(
      p.join(projectRoot, 'lib', uri.substring('package:meettrace/'.length)),
    );
  }
  if (!uri.contains(':')) {
    return p.normalize(p.join(p.dirname(sourcePath), uri));
  }
  return null;
}

Iterable<_ImportEntry> _importsUnder(String path) sync* {
  final pattern = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true);
  final source = File(path);
  final files = source.existsSync() ? <File>[source] : _dartFilesUnder(path);
  for (final file in files) {
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
