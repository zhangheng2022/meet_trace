---
type: "query"
date: "2026-08-06T03:47:43.974876+00:00"
question: "修复 iOS 最终处理时说话人分离 SIGABRT"
contributor: "graphify"
outcome: "useful"
source_nodes: ["SherpaOnnxSpeakerDiarizationWorker", "OfflineSpeakerDiarization"]
---

# Q: 修复 iOS 最终处理时说话人分离 SIGABRT

## Answer

将 sherpa_onnx_speaker_diarization_worker.dart 中无用途的 OfflineSpeakerDiarization.processWithCallback 调用替换为官方 process(samples: samples)，移除 NativeCallable.isolateLocal 回调桥；未修改官方包的 calloc 内存泄漏。新增源码契约回归测试，相关测试、完整 flutter test 432 项、flutter analyze 与 OCR 审查均通过。

## Outcome

- Signal: useful

## Source Nodes

- SherpaOnnxSpeakerDiarizationWorker
- OfflineSpeakerDiarization