---
type: "query"
date: "2026-07-29T10:35:51.587594+00:00"
question: "读取 whisper_ggml 文档并为 MeetTrace 制定替换 sherpa_onnx 的完整实施方案"
contributor: "graphify"
outcome: "useful"
source_nodes: ["AsrEngine", "AsrPreviewCoordinator", "ReliableRecordingService", "RecordingPreviewDispatcher", "FinalTranscriptionService", "AsrModelRegistry", "MeetTraceDependencies", "SileroVadSegmenter"]
---

# Q: 读取 whisper_ggml 文档并为 MeetTrace 制定替换 sherpa_onnx 的完整实施方案

## Answer

保留 AsrEngine、会议模型锁定、可靠事实录音、模型安装校验和最终快照事务；在 data/service 新增 whisper_ggml 适配层。候选为 tiny 多语言内置和 small 多语言下载。实时 transcribeLive 只作可降级全量草稿，最终从事实 PCM 分块重转录。上线前必须解决自定义 modelPath、无背压和取消、重复 FFmpeg 转换、长音频内存、iOS 15.6、NDK/AGP 兼容及 FFmpeg 2.x 安全依赖，并完成双平台真机门禁；否则保留 sherpa 回滚路径，不完成替换。

## Outcome

- Signal: useful

## Source Nodes

- AsrEngine
- AsrPreviewCoordinator
- ReliableRecordingService
- RecordingPreviewDispatcher
- FinalTranscriptionService
- AsrModelRegistry
- MeetTraceDependencies
- SileroVadSegmenter