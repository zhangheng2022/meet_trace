---
type: "query"
date: "2026-07-29T09:47:01.204909+00:00"
question: "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09"
contributor: "graphify"
outcome: "useful"
source_nodes: ["AsrModelRegistry", "Qwen Memory and Latency Risk", "Step 01 Preliminary Conditional Go", "supportedLanguages", "paraformer", "qwen"]
---

# Q: sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09

## Answer

Expanded from original query via vocab: [asr, model, offline, preview, final, languages, latency, memory, paraformer, qwen]. 图谱显示当前 Alpha Registry 仅包含标准 Paraformer 和高级 Qwen；会议模型锁定并同时承担会中预览与最终转录。该粤语 SenseVoice 应作为待测的可下载高级候选，而不是替换内置标准模型：约 226 MiB 超过 100 MB 标准门槛，且缺少本项目同设备 RTF、延迟、内存和准确率证据。官方 sherpa_onnx Dart 包已有 OfflineSenseVoiceModelConfig，但项目适配器尚未实现该分支。

## Outcome

- Signal: useful

## Source Nodes

- AsrModelRegistry
- Qwen Memory and Latency Risk
- Step 01 Preliminary Conditional Go
- supportedLanguages
- paraformer
- qwen