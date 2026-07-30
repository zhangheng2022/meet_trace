---
type: "architecture"
date: "2026-07-29T09:58:53.576890+00:00"
question: "评估 whisper_ggml 是否适合作为会迹当前本地 ASR 模型或运行时"
contributor: "graphify"
outcome: "useful"
source_nodes: ["sherpa_onnx_adapter.dart", "Qwen Memory and Latency Risk", "memoryPressure", "AsrPreviewCoordinator", "AsrModelRegistry", "SherpaOnnxWorker", "SherpaOnnxFactory"]
---

# Q: 评估 whisper_ggml 是否适合作为会迹当前本地 ASR 模型或运行时

## Answer

扩展词：adapter engine model offline preview final latency memory package ffi native flutter。结论：不建议引入。whisper_ggml 虽提供 Flutter API、Android/iOS 和 Whisper 时间戳，但仍通过 FFI 编译并捆绑 whisper.cpp，形成 sherpa-onnx 之外的第二套 C++ 原生运行时；其 live isolate 明示当解码低于实时速度时消息、原生窗口与延迟会持续增长，不符合项目有界预览队列和可丢预览任务的约束。包内下载还会将完整模型读入内存后落盘，未体现项目要求的哈希校验、原子切换与恢复策略。若必须评估 Whisper，应优先用现有官方 sherpa_onnx 包的 OfflineWhisperModelConfig，保持单一运行时。

## Outcome

- Signal: useful

## Source Nodes

- sherpa_onnx_adapter.dart
- Qwen Memory and Latency Risk
- memoryPressure
- AsrPreviewCoordinator
- AsrModelRegistry
- SherpaOnnxWorker
- SherpaOnnxFactory