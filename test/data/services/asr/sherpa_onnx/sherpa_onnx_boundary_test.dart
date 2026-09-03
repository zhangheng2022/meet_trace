import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('官方包版本固定且运行资源门执行 bindings 初始化', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final runtimeGate = await File(
      'lib/data/services/models/local_runtime_asset_preparation_service.dart',
    ).readAsString();

    expect(pubspec, contains('sherpa_onnx: 1.13.7'));
    expect(runtimeGate, contains('initializeBindings()'));
  });

  test('仓库不包含自建 sherpa 原生桥接或手工 jniLibs', () async {
    final forbiddenFiles = <String>[];
    final forbiddenContents = <String>[];
    final roots = [Directory('lib'), Directory('android/app/src')];

    for (final root in roots) {
      await for (final entity in root.list(recursive: true)) {
        if (entity is Directory &&
            entity.path.replaceAll(r'\', '/').contains('/jniLibs')) {
          forbiddenFiles.add(entity.path);
        }
        if (entity is! File) {
          continue;
        }
        final normalized = entity.path.replaceAll(r'\', '/');
        if (RegExp(r'\.(c|cc|cpp|h|hpp)$').hasMatch(normalized)) {
          forbiddenFiles.add(entity.path);
        }
        if (!RegExp(r'\.(dart|java|kt|gradle|kts)$').hasMatch(normalized)) {
          continue;
        }
        final contents = await entity.readAsString();
        if (contents.contains('DynamicLibrary.open') ||
            contents.contains('JNIEXPORT') ||
            contents.contains('package:ffigen')) {
          forbiddenContents.add(entity.path);
        }
      }
    }

    expect(forbiddenFiles, isEmpty);
    expect(forbiddenContents, isEmpty);
  });
}
