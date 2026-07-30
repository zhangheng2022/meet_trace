---
type: "query"
date: "2026-07-29T11:59:32.411367+00:00"
question: "正式替换 sherpa-onnx 后，MeetTrace 的 whisper.cpp 双模型 ASR 架构、实时预览、最终转录、模型生命周期与录音隔离如何连接？"
contributor: "graphify"
outcome: "useful"
source_nodes: ["MeetTraceDependencies", "WhisperAsrEngineFactory", "StreamingWindowSegmenter", "AsrPreviewCoordinator", "WhisperAsrEngine", "WhisperAdapter", "WhisperNativeContext", "FinalTranscriptionService"]
---

# Q: 正式替换 sherpa-onnx 后，MeetTrace 的 whisper.cpp 双模型 ASR 架构、实时预览、最终转录、模型生命周期与录音隔离如何连接？

## Answer

Expanded from original query via graph vocab: [whisper, adapter, engine, factory, native, streaming, window, preview, recording, transcription, finalization, model]. 更新后的图谱没有指向已删除文件的陈旧节点。MeetTraceDependencies 组装 WhisperAsrEngineFactory 与 StreamingWindowSegmenter；Factory 只按会议锁定的模型 ID/版本创建 Base 或 Small Engine。AsrPreviewCoordinator 接收可靠录音链持久化后投递的副本，以 2 秒窗口和 0.5 秒重叠驱动统一 Engine；积压只能降级预览，不影响事实录音。WhisperAsrEngine 经 WhisperAdapter 在专用 isolate 调用 WhisperNativeContext 和固定 whisper.cpp C ABI，取消由原子 abort callback 传播。最终转录从完整 PCM 重新分窗，保留 whisper.cpp 分段时间戳并由 FinalTranscriptionService 原子激活快照。Base 随包校验，Small 下载校验并受活动版本、租约与设备风险门禁约束；不自动回退或混合模型。

## Outcome

- Signal: useful

## Source Nodes

- MeetTraceDependencies
- WhisperAsrEngineFactory
- StreamingWindowSegmenter
- AsrPreviewCoordinator
- WhisperAsrEngine
- WhisperAdapter
- WhisperNativeContext
- FinalTranscriptionService