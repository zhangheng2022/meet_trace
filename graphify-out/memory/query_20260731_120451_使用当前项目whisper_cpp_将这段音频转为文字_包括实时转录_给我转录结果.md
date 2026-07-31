---
type: "query"
date: "2026-07-31T12:04:51.946364+00:00"
question: "使用当前项目whisper.cpp 将这段音频转为文字，包括实时转录，给我转录结果"
contributor: "graphify"
outcome: "useful"
source_nodes: ["AsrPreviewCoordinator", "WhisperBaseStandardAsrEngine", "WhisperAdapter", "WhisperNativeContext", "WhisperVadSegmenter"]
---

# Q: 使用当前项目whisper.cpp 将这段音频转为文字，包括实时转录，给我转录结果

## Answer

Expanded from original query via vocab: [whisper, transcribe, transcription, preview, audio, recording, engine, native, streaming, segment, final, model]. 项目实时路径为 AsrPreviewCoordinator → WhisperBaseStandardAsrEngine → WhisperAdapter → WhisperNativeContext → mt_whisper_transcribe；最终路径使用 final-beam-quality-v1 与 WhisperVadSegmenter。已用仓库固定 whisper.cpp v1.9.1、Base q5_1 模型完成 37:57 音频的实时和最终转录，并生成带时间戳结果。

## Outcome

- Signal: useful

## Source Nodes

- AsrPreviewCoordinator
- WhisperBaseStandardAsrEngine
- WhisperAdapter
- WhisperNativeContext
- WhisperVadSegmenter