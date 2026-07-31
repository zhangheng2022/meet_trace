---
type: "query"
date: "2026-07-30T12:10:01.024340+00:00"
question: "https://codeberg.org/tazz4843/whisper-rs/src/branch/master/src  https://pub.dev/packages/flutter_rust_bridge  用rust是不是更好"
contributor: "graphify"
outcome: "useful"
source_nodes: ["whisper.cpp", "whisper_adapter.dart", "whisper_asr_engine.dart", "whisper_vad_context"]
---

# Q: https://codeberg.org/tazz4843/whisper-rs/src/branch/master/src  https://pub.dev/packages/flutter_rust_bridge  用rust是不是更好

## Answer

Expanded from original query via vocab: [whisper, ffi, native, bridge, engine, context, vad, stream, audio, model]. 结论：Rust 不会改变 whisper.cpp 推理核心、准确率或天然解决 VAD；whisper-rs 提供更安全的状态/VAD封装，flutter_rust_bridge 提供异步和 Stream，但当前项目的窄 C ABI 已较简单。为修复当前转录质量不建议立刻迁移 Rust；先在现有封装启用官方 VAD 并修正分窗/上下文。若长期要把持久 VAD、环形缓冲、背压和事件流统一下沉原生层，可做隔离 Rust 原型，并以 Android/iOS 构建、16KB ELF、RTF、内存和录音连续性作为迁移门槛。

## Outcome

- Signal: useful

## Source Nodes

- whisper.cpp
- whisper_adapter.dart
- whisper_asr_engine.dart
- whisper_vad_context