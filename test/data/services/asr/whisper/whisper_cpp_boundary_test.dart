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

  test('原生推理失败保留 whisper.cpp 返回码用于私有诊断', () async {
    final nativeSource = await File(
      'packages/meettrace_whisper_native/src/meettrace_whisper.cpp',
    ).readAsString();

    expect(
      nativeSource,
      contains('"whisper_full_failed:" + std::to_string(result)'),
    );
  });

  test('C ABI 暴露版本化配置、稳定状态码和结构大小校验', () async {
    final header = await File(
      'packages/meettrace_whisper_native/src/meettrace_whisper.h',
    ).readAsString();
    final context = await File(
      'packages/meettrace_whisper_native/lib/src/whisper_native_context.dart',
    ).readAsString();

    expect(header, contains('MT_WHISPER_ABI_VERSION'));
    expect(header, contains('mt_whisper_status'));
    expect(header, contains('mt_whisper_decoding_strategy'));
    expect(header, contains('mt_whisper_config_v1'));
    expect(header, contains('struct_size'));
    expect(header, contains('abi_version'));
    expect(header, contains('mt_whisper_abi_version'));
    expect(header, contains('mt_whisper_config_v1_init'));
    expect(header, contains('mt_whisper_validate_config_v1'));
    expect(header, contains('mt_whisper_create_v1'));
    expect(header, contains('mt_whisper_status_message'));
    expect(context, contains('native.abi_version_mismatch'));
    expect(context, contains('mt_whisper_create_v1'));
  });

  test('官方 VAD 使用独立版本化 context 且完整生命周期由 ffigen 生成', () async {
    final header = await File(
      'packages/meettrace_whisper_native/src/meettrace_whisper.h',
    ).readAsString();
    final bindings = await File(
      'packages/meettrace_whisper_native/'
      'lib/src/third_party/meettrace_whisper.g.dart',
    ).readAsString();

    for (final symbol in [
      'mt_whisper_vad_config_v1',
      'mt_whisper_vad_create_v1',
      'mt_whisper_vad_segment_samples',
      'mt_whisper_vad_segment_start_sample',
      'mt_whisper_vad_segment_end_sample',
      'mt_whisper_vad_reset',
      'mt_whisper_vad_cancel',
      'mt_whisper_vad_destroy',
    ]) {
      expect(header, contains(symbol));
      expect(bindings, contains(symbol));
    }
  });
}
