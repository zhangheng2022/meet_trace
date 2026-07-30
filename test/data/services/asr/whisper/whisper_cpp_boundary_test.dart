import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('本地包固定官方 whisper.cpp 源码版本并通过 Native Assets 接入', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final packageReadme = await File(
      'packages/meettrace_whisper_native/README.md',
    ).readAsString();
    final buildHook = await File(
      'packages/meettrace_whisper_native/hook/build.dart',
    ).readAsString();

    expect(pubspec, contains('meettrace_whisper_native:'));
    expect(packageReadme, contains('f049fff95a089aa9969deb009cdd4892b3e74916'));
    expect(buildHook, contains('buildWhisperLibrary'));
    expect(
      await File(
        'packages/meettrace_whisper_native/lib/src/c_library.dart',
      ).readAsString(),
      contains('CBuilder.library'),
    );
  });

  test('应用层不包含手工 JNI 或散落的动态库加载', () async {
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
            contents.contains('JNIEXPORT')) {
          forbiddenContents.add(entity.path);
        }
      }
    }

    expect(forbiddenFiles, isEmpty);
    expect(forbiddenContents, isEmpty);
  });

  test('Android Whisper 动态库显式链接系统数学库', () async {
    final nativeBuild = await File(
      'packages/meettrace_whisper_native/lib/src/c_library.dart',
    ).readAsString();

    expect(
      nativeBuild,
      contains("if (targetOS == OS.android) 'm'"),
      reason: 'ggml 使用 exp 等数学函数，Android 动态加载时必须能解析 libm',
    );
  });

  test('C ABI 由 ffigen 生成，原生源码仅存在于隔离 package', () async {
    expect(
      await File(
        'packages/meettrace_whisper_native/'
        'lib/src/third_party/meettrace_whisper.g.dart',
      ).exists(),
      true,
    );
    expect(
      await File(
        'packages/meettrace_whisper_native/src/meettrace_whisper.cpp',
      ).exists(),
      true,
    );
  });
}
