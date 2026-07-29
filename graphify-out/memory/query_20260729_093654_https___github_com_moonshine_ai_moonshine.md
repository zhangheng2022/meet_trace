---
type: "query"
date: "2026-07-29T09:36:54.837558+00:00"
question: "https://github.com/moonshine-ai/moonshine"
contributor: "graphify"
outcome: "useful"
source_nodes: ["AsrModelRegistry", "AsrPreviewCoordinator", "supportedLanguages", "Qwen Memory and Latency Risk", "SherpaOnnxAsrEngine"]
---

# Q: https://github.com/moonshine-ai/moonshine

## Answer

Expanded from original query via graph vocab: [asr, model, offline, capabilities, preview, latency, memory, rtf, languages, registry]. Moonshine v2 中文 Base 仅支持中文，sherpa-onnx 量化包约 135 MB，官方示例 RTF 约 0.146 且无时间戳；上游公开指标为普通话 CER 25.76%。当前 sherpa_onnx 1.13.4 已有 OfflineMoonshineModelConfig v2 encoder 与 mergedDecoder 支持，但项目 adapter 只允许 paraformer 与 qwen3Asr。更重要的是非英语模型由上游声明为 Moonshine Community License 非商业许可。结论是不替换 Paraformer 或 Qwen，不进入生产；最多在许可确认后作为内部同语料 Spike 候选。

## Outcome

- Signal: useful

## Source Nodes

- AsrModelRegistry
- AsrPreviewCoordinator
- supportedLanguages
- Qwen Memory and Latency Risk
- SherpaOnnxAsrEngine