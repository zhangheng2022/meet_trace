---
type: "query"
date: "2026-07-30T10:27:00.878847+00:00"
question: "clang: warning: -Wl,-z,max-page-size=16384: linker input unused 是否影响 Android 16KB page-size 兼容性"
contributor: "graphify"
outcome: "useful"
source_nodes: ["builder", "build", "package:native_toolchain_c/native_toolchain_c.dart", "packages/meettrace_whisper_native/lib/src/c_library.dart", "packages/meettrace_whisper_native/src/meettrace_whisper.cpp", "tool/benchmarks/inspect_debug_apk.ps1"]
---

# Q: clang: warning: -Wl,-z,max-page-size=16384: linker input unused 是否影响 Android 16KB page-size 兼容性

## Answer

不影响当前产物。native_toolchain_c 0.19.2 在 Android CBuilder 的静态库 -c 编译命令和最终共享库链接命令中都注入 -Wl,-z,max-page-size=16384；前者没有链接阶段，因此每个 C 源文件产生 unused 告警，后者会正确消费该参数。Fresh flutter build apk --debug 以退出码 0 完成；APK 内 arm64-v8a、armeabi-v7a、x86_64 的 libmeettrace_whisper.so 各有 4 个 LOAD 段，p_align 均为 0x4000。不要删除该链接参数；若要消除日志，应由 native_toolchain_c 仅在动态库链接阶段添加。OCR 另发现 inspect_debug_apk.ps1 尚未自动验证 ELF 16KB 对齐，属于 Medium 发布门禁缺口。

## Outcome

- Signal: useful

## Source Nodes

- builder
- build
- package:native_toolchain_c/native_toolchain_c.dart
- packages/meettrace_whisper_native/lib/src/c_library.dart
- packages/meettrace_whisper_native/src/meettrace_whisper.cpp
- tool/benchmarks/inspect_debug_apk.ps1