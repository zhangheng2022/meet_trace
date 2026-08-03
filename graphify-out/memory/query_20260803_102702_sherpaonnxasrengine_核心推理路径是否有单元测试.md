---
type: "query"
date: "2026-08-03T10:27:02.402453+00:00"
question: "SherpaOnnxAsrEngine 核心推理路径是否有单元测试"
contributor: "graphify"
outcome: "useful"
source_nodes: ["SherpaOnnxAsrEngine", "SherpaOnnxAdapter", "SherpaOnnxAsrEngineFactory"]
---

# Q: SherpaOnnxAsrEngine 核心推理路径是否有单元测试

## Answer

Expanded from graph vocab: [sherpa, onnx, asr, engine, transcribe, transcription, segment, stream, audio, waveform, result, dispose]. 复核确认 Adapter 有 4 项测试、Factory 有 3 项测试，但 676 行 SherpaOnnxAsrEngine 原先为零直接测试。现新增 8 项 fake worker 单元测试，覆盖预览时间轴、空结果、无效窗口、错误诊断、PCM16 解码与 15 秒分窗、风险阻断、取消和幂等释放；全量 337 项通过。

## Outcome

- Signal: useful

## Source Nodes

- SherpaOnnxAsrEngine
- SherpaOnnxAdapter
- SherpaOnnxAsrEngineFactory