---
type: "query"
date: "2026-07-29T09:51:12.065070+00:00"
question: "ggml-org/whisper.cpp"
contributor: "graphify"
outcome: "useful"
source_nodes: ["sherpa_onnx_adapter.dart", "package:sherpa_onnx/sherpa_onnx.dart", "AsrModelRegistry", "Qwen Memory and Latency Risk", "supportedLanguages"]
---

# Q: ggml-org/whisper.cpp

## Answer

Expanded from original query via vocab: [adapter, engine, model, offline, preview, final, languages, latency, memory, package]. whisper.cpp 是 C/C++ Whisper 推理运行时，不是单一模型。虽然支持 Android/iOS、量化和时间戳，但接入会新增 C/C++ 构建链与原生绑定，直接违反项目只允许官方 sherpa_onnx Flutter/Dart 包、禁止自建 JNI/FFI 的边界，因此不应引入。若仍需评估 Whisper 模型，应使用 sherpa_onnx 1.13.4 已有 OfflineWhisperModelConfig，通过当前统一 AsrEngine 适配并先更新 PRD；现有 adapter 仍只有 Paraformer/Qwen 两分支。

## Outcome

- Signal: useful

## Source Nodes

- sherpa_onnx_adapter.dart
- package:sherpa_onnx/sherpa_onnx.dart
- AsrModelRegistry
- Qwen Memory and Latency Risk
- supportedLanguages