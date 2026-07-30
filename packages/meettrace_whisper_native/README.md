# meettrace_whisper_native

会迹自有的 `whisper.cpp` Native Assets 薄封装。

- 上游：`ggml-org/whisper.cpp`
- 固定版本：`v1.9.1`
- 固定提交：`f049fff95a089aa9969deb009cdd4892b3e74916`
- Dart 绑定：由 `dart run tool/ffigen.dart` 生成；未在 PATH 安装 LLVM 时，
  通过 `LIBCLANG_PATH` 指向 `libclang` 动态库
- 原生构建：由 `hook/build.dart` 和 `package:native_toolchain_c` 完成

应用层只调用本包稳定的 Dart API；`whisper.h` 和 `whisper_full_params`
不会穿透到主应用。
