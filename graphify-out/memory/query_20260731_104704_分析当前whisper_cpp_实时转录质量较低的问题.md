---
type: "diagnosis"
date: "2026-07-31T10:47:04.218675+00:00"
question: "分析当前whisper.cpp 实时转录质量较低的问题"
contributor: "graphify"
outcome: "useful"
source_nodes: ["AsrPreviewCoordinator", "WhisperVadSegmenter", "WhisperRecognizerConfig", "WhisperAdapter", "StreamingWindowSegmenter"]
---

# Q: 分析当前whisper.cpp 实时转录质量较低的问题

## Answer

结论：已观测到的实时低质量主因是短窗低信噪比解码产生重复幻觉，并被滚动窗口追加策略放大，不是录音中断、模型加载失败或单纯 VAD 漏检。旧/中间 APK 使用 Preview Greedy best-of 1、无 temperature fallback、短 audio_ctx 与约 3 秒输入；当前源码已恢复 temperatureIncrement=0.2、audio_ctx=0，并加入最多 10 秒滚动上下文。当前仍有高概率复发点：每窗 language=auto 且 noContext=true；滚动窗口反复识别旧音频；去重只接受严格字符后缀/前缀重叠，标点或局部改写会把整窗当新文本，而 ViewModel 按新 groupId 保留旧段；预览 VAD 0.35 提高召回也会放入更多低信噪比音频；采集关闭 AGC/降噪，历史小米 PCM 约 -42 dBFS。当前修正后 APK 于 18:38 构建，晚于 18:13 的故障实测，设备未连接且无本地 PCM，效果应保持 not_tested。相关 29 个单元测试通过，但质量基准直接调用 WhisperAdapter/VAD，不覆盖 AsrPreviewCoordinator 的滚动去重与 UI 累积。下一步应使用同一小米事实 PCM 对旧/新 APK逐窗 A/B，记录 raw recognition、published novel text、VAD coverage、RMS、重复率和关键事实召回。
Expanded from original query via graph vocab: [whisper, asr, preview, streaming, segmenter, decode, quality, language, prompt, vad, chunk, silence].

## Outcome

- Signal: useful

## Source Nodes

- AsrPreviewCoordinator
- WhisperVadSegmenter
- WhisperRecognizerConfig
- WhisperAdapter
- StreamingWindowSegmenter