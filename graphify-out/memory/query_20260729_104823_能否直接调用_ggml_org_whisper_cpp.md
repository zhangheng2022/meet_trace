---
type: "query"
date: "2026-07-29T10:48:23.175712+00:00"
question: "能否直接调用 ggml-org/whisper.cpp"
contributor: "graphify"
outcome: "useful"
source_nodes: ["AsrEngine", "AsrEngineFactory", "ReliableRecordingService", "RecordingPreviewDispatcher", "AsrPreviewCoordinator", "FinalTranscriptionService", "AsrModelRegistry", "MeetTraceDependencies"]
---

# Q: 能否直接调用 ggml-org/whisper.cpp

## Answer

Expanded from original query via graph vocab: [asr, engine, factory, ffi, native, runtime, model, stream, audio, recording, preview, final]. 技术上可以，但 Dart 不能直接调用 C++ 源码；应创建独立 Native Assets package，固定 whisper.cpp commit，用薄 C ABI wrapper 隐藏 whisper_full_params 和指针生命周期，再由 ffigen 生成绑定。保留 AsrEngine、ReliableRecordingService、RecordingPreviewDispatcher 和 FinalTranscriptionService：实时预览从已持久化 PCM 的可丢弃副本运行，最终转录从事实 PCM 顺序分窗并复用同一 whisper_context。直连可获得自定义模型路径、上下文复用、时间戳、原生取消和无 FFmpeg 依赖，但项目必须承担 Android/iOS 原生构建、ABI、内存、线程、16KB 页、Apple 加速和上游升级维护。若确定长期采用 Whisper，直连官方 runtime 比依赖当前第三方 whisper_ggml 更可控；仍需先修改 PRD 并做双平台 Spike。

## Outcome

- Signal: useful

## Source Nodes

- AsrEngine
- AsrEngineFactory
- ReliableRecordingService
- RecordingPreviewDispatcher
- AsrPreviewCoordinator
- FinalTranscriptionService
- AsrModelRegistry
- MeetTraceDependencies