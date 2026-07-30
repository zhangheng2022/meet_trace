---
type: "architecture"
date: "2026-07-29T10:20:19.923025+00:00"
question: "whisper_ggml transcribeLive 实时（流媒体）转录如何接入当前项目"
contributor: "graphify"
outcome: "useful"
source_nodes: ["ReliableRecordingService", "RecordingPreviewDispatcher", "AsrPreviewCoordinator", "AsrEngine", "FinalTranscriptionService", "TranscriptSnapshot"]
---

# Q: whisper_ggml transcribeLive 实时（流媒体）转录如何接入当前项目

## Answer

扩展词：stream recording persisted preview queue engine session events final transcript snapshot audio。结论：transcribeLive 可用于会中临时预览，但应接在 ReliableRecordingService 已写入、flush、checkpoint 后的 RecordingPreviewDispatcher 派生支路；不能成为事实录音唯一消费者。partials 是全量文本，应替换显示而非追加。中文用 lang zh 或 auto。停止顺序为停止采集、等待事实音频封存、关闭预览输入、限时 stop 会话；session.stop 返回文本只作临时预览，权威最终转录仍从已封存完整音频重新执行 withSegments 并原子写入 TranscriptSnapshot。现有 feed 无完成确认且原生 mailbox 可能积压，因此有界 Dart 队列不能证明原生背压；真机门槛不通过时需停用实时预览或扩展插件。

## Outcome

- Signal: useful

## Source Nodes

- ReliableRecordingService
- RecordingPreviewDispatcher
- AsrPreviewCoordinator
- AsrEngine
- FinalTranscriptionService
- TranscriptSnapshot