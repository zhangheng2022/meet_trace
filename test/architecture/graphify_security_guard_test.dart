import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, File> _pythonFiles(String rootPath) {
  final root = Directory(rootPath);
  return {
    for (final file
        in root
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.py')))
      file.path
              .substring(root.path.length + 1)
              .replaceAll(Platform.pathSeparator, '/'):
          file,
  };
}

void main() {
  group('Graphify 安全守卫', () {
    test('Agents 与 Claude Python 镜像逐字节一致', () async {
      final agents = _pythonFiles('.agents/skills/graphify');
      final claude = _pythonFiles('.claude/skills/graphify');

      expect(agents.keys, unorderedEquals(claude.keys));
      for (final path in agents.keys) {
        expect(
          await agents[path]!.readAsBytes(),
          await claude[path]!.readAsBytes(),
          reason: 'Graphify 镜像不一致：$path',
        );
      }
    });

    test('Graphify 技能版本和安全修复保持同步', () async {
      expect(
        await File('.agents/skills/graphify/.graphify_version').readAsString(),
        '0.9.41',
      );
      expect(
        await File('.claude/skills/graphify/.graphify_version').readAsString(),
        '0.9.41',
      );

      final ingest = await File('.agents/skills/graphify/ingest.py')
          .readAsString();
      final dartExtractor = await File(
        '.agents/skills/graphify/extractors/dart.py',
      ).readAsString();
      final extraction = await File('.agents/skills/graphify/extract.py')
          .readAsString();
      final resolution = await File(
        '.agents/skills/graphify/extractors/resolution.py',
      ).readAsString();

      expect(ingest, contains('parsed.hostname'));
      expect(ingest, contains('hostname.endswith(f".{domain}")'));
      expect(ingest, isNot(contains('"github.com" in lower')));
      expect(dartExtractor, contains(r'(?:\\[\s\S]|[^\\])*?'));
      expect(dartExtractor, isNot(contains(r'(?:\\.|[\s\S])*?')));
      expect(extraction, contains(r'</script\b[^>]*>'));
      expect(resolution, contains(r'</script\b[^>]*>'));
    });
  });
}
