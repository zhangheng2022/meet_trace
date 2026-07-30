// Copyright (c) 2026 MeetTrace contributors.
// SPDX-License-Identifier: MIT

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

const whisperAssetName = 'src/third_party/meettrace_whisper.g.dart';

const _cSources = <String>[
  'third_party/whisper.cpp/ggml/src/ggml.c',
  'third_party/whisper.cpp/ggml/src/ggml-alloc.c',
  'third_party/whisper.cpp/ggml/src/ggml-quants.c',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/ggml-cpu.c',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/quants.c',
];

const _cppSources = <String>[
  'src/meettrace_whisper.cpp',
  'third_party/whisper.cpp/src/whisper.cpp',
  'third_party/whisper.cpp/ggml/src/ggml.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-backend.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-backend-meta.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-opt.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-threading.cpp',
  'third_party/whisper.cpp/ggml/src/gguf.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-backend-dl.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-backend-reg.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/ggml-cpu.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/repack.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/hbm.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/traits.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/binary-ops.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/unary-ops.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/vec.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/ops.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/amx/amx.cpp',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/amx/mmq.cpp',
];

const _armSources = <String>[
  'third_party/whisper.cpp/ggml/src/ggml-cpu/arch/arm/quants.c',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/arch/arm/repack.cpp',
];

const _x86Sources = <String>[
  'third_party/whisper.cpp/ggml/src/ggml-cpu/arch/x86/quants.c',
  'third_party/whisper.cpp/ggml/src/ggml-cpu/arch/x86/repack.cpp',
];

Future<void> buildWhisperLibrary(
  BuildInput input,
  BuildOutputBuilder output,
) async {
  if (!input.config.buildCodeAssets) {
    return;
  }

  final targetOS = input.config.code.targetOS;
  if (targetOS != OS.android && targetOS != OS.iOS) {
    // MeetTrace Alpha only ships Android and iOS. Keeping host analysis free
    // from an unrelated desktop toolchain also lets ffigen run on Windows.
    return;
  }

  final architecture = input.config.code.targetArchitecture;
  final architectureSources = switch (architecture) {
    Architecture.arm || Architecture.arm64 => _armSources,
    Architecture.ia32 || Architecture.x64 => _x86Sources,
    _ => const <String>[],
  };
  final genericCpu = architectureSources.isEmpty;

  final defines = {
    'GGML_USE_CPU': null,
    'GGML_SCHED_MAX_COPIES': '4',
    'WHISPER_VERSION': '"1.9.1"',
    'GGML_VERSION': '"1.9.1"',
    'GGML_COMMIT': '"f049fff95a089aa9969deb009cdd4892b3e74916"',
    if (genericCpu) 'GGML_CPU_GENERIC': null,
    if (targetOS == OS.android) '_GNU_SOURCE': null,
    if (targetOS == OS.iOS) '_DARWIN_C_SOURCE': null,
  };
  const includes = [
    'src',
    'third_party/whisper.cpp/include',
    'third_party/whisper.cpp/src',
    'third_party/whisper.cpp/ggml/include',
    'third_party/whisper.cpp/ggml/src',
    'third_party/whisper.cpp/ggml/src/ggml-cpu',
  ];

  final cBuilder = CBuilder.library(
    name: 'meettrace_ggml_c',
    sources: [
      ..._cSources,
      ...architectureSources.where((path) => path.endsWith('.c')),
    ],
    includes: includes,
    language: Language.c,
    std: 'c11',
    defines: defines,
    flags: const ['-fvisibility=hidden', '-Wno-deprecated-declarations'],
    linkModePreference: LinkModePreference.static,
  );
  await cBuilder.run(input: input, output: output);

  final builder = CBuilder.library(
    name: 'meettrace_whisper',
    assetName: whisperAssetName,
    sources: [
      ..._cppSources,
      ...architectureSources.where((path) => path.endsWith('.cpp')),
    ],
    includes: includes,
    libraries: const ['meettrace_ggml_c'],
    language: Language.cpp,
    std: 'c++17',
    cppLinkStdLib: targetOS == OS.android ? 'c++_static' : null,
    defines: defines,
    flags: ['-fvisibility=hidden', '-Wno-deprecated-declarations'],
  );
  await builder.run(input: input, output: output);
}
