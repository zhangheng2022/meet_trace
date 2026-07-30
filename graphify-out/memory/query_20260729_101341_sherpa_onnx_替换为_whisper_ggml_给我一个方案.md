---
type: "architecture"
date: "2026-07-29T10:13:41.266989+00:00"
question: "sherpa_onnx 替换为 whisper_ggml，给我一个方案"
contributor: "graphify"
outcome: "useful"
source_nodes: ["AsrEngine", "AsrEngineFactory", "AsrModelRegistry", "AsrPreviewCoordinator", "SherpaOnnxAsrEngineFactory", "SherpaOnnxAsrEngine", "SherpaOnnxAdapter", "SileroVadSegmenter", "FinalTranscriptionService", "MeetTraceDependencies"]
---

# Q: sherpa_onnx 替换为 whisper_ggml，给我一个方案

## Answer

扩展词：sherpa engine factory registry model preview queue recording final snapshot download worker。方案：保持 Domain AsrEngine、会议模型锁定、可靠录音、有界预览队列、最终快照与仓库/UI不变；data/service 替换为 WhisperGgmlAdapter、WhisperGgmlAsrEngine、WhisperGgmlAsrEngineFactory。推荐 multilingual base 作为内置标准、small 作为按需高级。不能直接使用 transcribeLive，因为 feed 无完成确认且原生邮箱可能无界积压；功能等价交付需上游或受控 fork 提供持久模型上下文、可等待 decodeWindow、时间戳、取消、释放和积压指标。完整移除 sherpa_onnx 还必须替换依赖 VoiceActivityDetector 的 SileroVadSegmenter。模型下载继续使用现有 Manifest、哈希、断点续传和原子激活，禁止包内下载器。iOS 目标需从 13 提升到至少 15.6。采用并行验证、默认切换、旧会议过渡、最终删除 sherpa 的四阶段迁移；不改写历史模型身份。

## Outcome

- Signal: useful

## Source Nodes

- AsrEngine
- AsrEngineFactory
- AsrModelRegistry
- AsrPreviewCoordinator
- SherpaOnnxAsrEngineFactory
- SherpaOnnxAsrEngine
- SherpaOnnxAdapter
- SileroVadSegmenter
- FinalTranscriptionService
- MeetTraceDependencies